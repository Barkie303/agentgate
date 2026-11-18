// AgentGate configuration — edit CONTRACT_ADDRESS after deployment.
const CONFIG = {
  // BNB Chain mainnet (56). For the testnet build, use chain 97 and the
  // testnet RPC + testnet contract address.
  chainId: 56,
  chainName: "BNB Smart Chain",
  rpcUrl: "https://bsc-dataseed1.bnbchain.org",
  blockExplorer: "https://bscscan.com",

  // AgentGate contract address (set after deployment; null = not deployed yet).
  contractAddress: null,

  // Official SPACE ID Agent ID registry (ERC-721, non-transferable).
  agentIdRegistry: "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F",
};

// Minimal ABI — only the functions the UI needs.
const GATE_ABI = [
  "function campaignCount() view returns (uint256)",
  "function createCampaign(string name, uint256 maxSlots, uint256 deadline, string metadataURI) returns (uint256)",
  "function register(uint256 campaignId)",
  "function closeCampaign(uint256 campaignId)",
  "function getCampaign(uint256 campaignId) view returns (tuple(address creator, string name, uint256 maxSlots, uint256 deadline, string metadataURI, uint256 registrantCount, bool closed))",
  "function getRegistrantCount(uint256 campaignId) view returns (uint256)",
  "function isRegistered(uint256 campaignId, address account) view returns (bool)",
  "function getRegistrants(uint256 campaignId, uint256 offset, uint256 limit) view returns (address[])",
  "function agentIDRegistry() view returns (address)",
  "event CampaignCreated(uint256 indexed campaignId, address indexed creator, string name, uint256 maxSlots, uint256 deadline)",
  "event Registered(uint256 indexed campaignId, address indexed registrant)",
  "event CampaignClosed(uint256 indexed campaignId)",
];

const REGISTRY_ABI = [
  "function balanceOf(address owner) view returns (uint256)",
];
