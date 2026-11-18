// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title AgentGate — Agent ID-gated allowlist registry for free mints and claims
/// @notice Projects create allowlist campaigns; only addresses holding an Agent ID
/// (SPACE ID Agent ID, ERC-721, non-transferable — one per user) can register,
/// one slot per address per campaign. This makes allowlists sybil-resistant:
/// a user cannot mint many slots because they can only ever hold one Agent ID.
/// @dev The contract never holds or moves user funds. It has no admin role:
/// the only privileged action is closeCampaign, callable only by that
/// campaign's own creator, and it affects only that campaign.
interface IAgentIDRegistry {
    function balanceOf(address owner) external view returns (uint256);
}

contract AgentGate {
    /// @notice The Agent ID registry this contract trusts (BNB Chain mainnet:
    /// 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F).
    IAgentIDRegistry public immutable agentIDRegistry;

    /// @notice Upper bound on slots per campaign, to keep registrant lists bounded.
    uint256 public constant MAX_SLOTS = 100_000;

    struct Campaign {
        address creator;
        string name;
        uint256 maxSlots;
        uint256 deadline;
        string metadataURI;
        uint256 registrantCount;
        bool closed;
    }

    uint256 public campaignCount;
    mapping(uint256 => Campaign) private campaigns;
    mapping(uint256 => mapping(address => bool)) private registered;
    mapping(uint256 => address[]) private registrants;

    event CampaignCreated(
        uint256 indexed campaignId, address indexed creator, string name, uint256 maxSlots, uint256 deadline
    );
    event Registered(uint256 indexed campaignId, address indexed registrant);
    event CampaignClosed(uint256 indexed campaignId);

    error NotAgentIDHolder();
    error AlreadyRegistered();
    error CampaignFull();
    error CampaignIsClosed();
    error CampaignExpired();
    error NotCreator();
    error InvalidMaxSlots();
    error InvalidDeadline();
    error CampaignNotFound();

    constructor(address _agentIDRegistry) {
        agentIDRegistry = IAgentIDRegistry(_agentIDRegistry);
    }

    /// @notice Create a new allowlist campaign. Anyone may create one.
    /// @param name Human-readable campaign name (e.g. "404 Strays Genesis").
    /// @param maxSlots Maximum number of allowlist slots (1..MAX_SLOTS).
    /// @param deadline Unix timestamp after which registration closes.
    /// @param metadataURI Off-chain metadata (project site, rules, etc.).
    /// @return campaignId The id of the created campaign.
    function createCampaign(string calldata name, uint256 maxSlots, uint256 deadline, string calldata metadataURI)
        external
        returns (uint256 campaignId)
    {
        if (maxSlots == 0 || maxSlots > MAX_SLOTS) revert InvalidMaxSlots();
        if (deadline <= block.timestamp) revert InvalidDeadline();

        campaignId = campaignCount++;
        campaigns[campaignId] = Campaign({
            creator: msg.sender,
            name: name,
            maxSlots: maxSlots,
            deadline: deadline,
            metadataURI: metadataURI,
            registrantCount: 0,
            closed: false
        });

        emit CampaignCreated(campaignId, msg.sender, name, maxSlots, deadline);
    }

    /// @notice Register the caller for a campaign's allowlist.
    /// @dev The Agent ID gate: the caller must hold at least one Agent ID
    /// (balanceOf > 0 on the registry). Because each user can hold exactly one
    /// non-transferable Agent ID, one registration per address = one slot per
    /// real Agent ID holder. No funds are involved.
    function register(uint256 campaignId) external {
        Campaign storage c = campaigns[campaignId];
        if (campaignId >= campaignCount) revert CampaignNotFound();
        if (c.closed) revert CampaignIsClosed();
        if (block.timestamp >= c.deadline) revert CampaignExpired();
        if (c.registrantCount >= c.maxSlots) revert CampaignFull();
        if (registered[campaignId][msg.sender]) revert AlreadyRegistered();
        if (agentIDRegistry.balanceOf(msg.sender) == 0) revert NotAgentIDHolder();

        registered[campaignId][msg.sender] = true;
        registrants[campaignId].push(msg.sender);
        c.registrantCount++;

        emit Registered(campaignId, msg.sender);
    }

    /// @notice Close a campaign early. Only the campaign's creator may do so.
    /// Closing stops new registrations; existing registrations stay recorded.
    function closeCampaign(uint256 campaignId) external {
        if (campaignId >= campaignCount) revert CampaignNotFound();
        Campaign storage c = campaigns[campaignId];
        if (msg.sender != c.creator) revert NotCreator();
        if (c.closed) revert CampaignIsClosed();
        c.closed = true;
        emit CampaignClosed(campaignId);
    }

    // ---- Views ----

    function getCampaign(uint256 campaignId) external view returns (Campaign memory) {
        if (campaignId >= campaignCount) revert CampaignNotFound();
        return campaigns[campaignId];
    }

    function getRegistrantCount(uint256 campaignId) external view returns (uint256) {
        if (campaignId >= campaignCount) revert CampaignNotFound();
        return campaigns[campaignId].registrantCount;
    }

    function isRegistered(uint256 campaignId, address account) external view returns (bool) {
        if (campaignId >= campaignCount) revert CampaignNotFound();
        return registered[campaignId][account];
    }

    /// @notice Paginated registrant list, so projects can export their allowlist.
    function getRegistrants(uint256 campaignId, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory)
    {
        if (campaignId >= campaignCount) revert CampaignNotFound();
        address[] storage list = registrants[campaignId];
        if (offset >= list.length) return new address[](0);
        uint256 end = offset + limit;
        if (end > list.length) end = list.length;
        address[] memory page = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            page[i - offset] = list[i];
        }
        return page;
    }
}
