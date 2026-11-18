# AgentGate — Agent ID-gated allowlists for free mints

Built for the **Binance Agent ID Hackathon** (submissions close 9 Dec 2026 08:00 UTC).

## The problem

Dozens of agent-focused projects run free mints and claims for Agent ID
holders — but today there is no on-chain way to restrict an allowlist to
real Agent ID holders. Projects collect allowlists in forms and
spreadsheets, which anyone can spam with fresh wallets.

## The idea

AgentGate is an on-chain allowlist registry. Projects create allowlist
campaigns; only addresses holding an Agent ID can register, one slot per
address. Because each user can hold exactly **one non-transferable**
Agent ID, one registration per address means one slot per real holder —
sybil-resistant by construction, with no off-chain verification.

## How Agent ID is used

The `AgentGate` contract reads the official SPACE ID Agent ID registry
(`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`, ERC-721) **on-chain**:
`register()` requires `balanceOf(msg.sender) > 0` — the exact check
Binance documents for "does this address hold an Agent ID". The gate is
enforced by the contract itself, not by the frontend, so it cannot be
bypassed. The frontend also reads the registry to show the connected
wallet whether it holds an Agent ID before it tries to register.

## What it does

- `createCampaign(name, maxSlots, deadline, metadataURI)` — anyone can
  create an allowlist campaign (max 100,000 slots, deadline must be in
  the future).
- `register(campaignId)` — Agent ID holders claim one slot. Reverts if
  the caller holds no Agent ID, already registered, or the campaign is
  full, expired, or closed.
- `closeCampaign(campaignId)` — the campaign creator can close their own
  campaign early. Existing registrations stay recorded.
- Views: `getCampaign`, `getRegistrantCount`, `isRegistered`,
  `getRegistrants(campaignId, offset, limit)` (paginated, so projects
  can export their allowlist on-chain).
- Events: `CampaignCreated`, `Registered`, `CampaignClosed`.

## Owner permissions (disclosure)

- The contract has **no admin role, no owner, and no pause function**.
- The only privileged action is `closeCampaign`, callable **only by that
  campaign's own creator**, and it affects only that campaign.
- Nobody — not the deployer, not the project team — can register users,
  remove registrations, change a campaign's slots or deadline, or close
  someone else's campaign.
- The contract **never holds or moves user funds**: there is no payable
  function and no token handling at all. Users only pay their own gas.

## Repo layout

```
src/AgentGate.sol        The registry contract
src/MockAgentID.sol      Test stand-in for the Agent ID registry
test/AgentGate.t.sol     Foundry tests (14 tests)
script/DeployMainnet.s.sol   BSC mainnet deploy (real registry)
script/DeployTestnet.s.sol   BSC testnet deploy (deploys MockAgentID too)
frontend/                Static site (no build step): index.html, app.js,
                         config.js, style.css — plain JS + ethers.js (CDN)
SUBMISSION.md            Draft text for the hackathon submission form
```

## Setup

Requires [Foundry](https://book.getfoundry.sh/) (`forge`, `cast`, `anvil`).

```sh
git clone <this repo>
cd agentgate
forge build
forge test
```

## Tests

```sh
forge test
```

14 tests, all passing. They cover: happy-path registration, registration
without an Agent ID (reverts), double registration (reverts), full
campaign (reverts), expired campaign (reverts), closing by a non-creator
(reverts), closing by the creator (works, registrations preserved),
invalid slots/deadline, unknown campaign, registrant pagination, and the
same address registering for two different campaigns.

## Deploy

No deployment has been executed from this repo yet. Deploying needs a
funded deployer wallet (BNB for gas) — the key is supplied via env at
deploy time only and is never stored in the repo.

```sh
# BSC testnet (chain 97) — deploys MockAgentID + AgentGate
PRIVATE_KEY=0x... forge script script/DeployTestnet.s.sol \
  --rpc-url bsc-testnet --broadcast --verify

# BSC mainnet (chain 56) — AgentGate against the real Agent ID registry
PRIVATE_KEY=0x... forge script script/DeployMainnet.s.sol \
  --rpc-url bsc --broadcast --verify
```

Verify on BscScan (also done by `--verify` above):

```sh
forge verify-contract --chain 56 <DEPLOYED_ADDRESS> src/AgentGate.sol:AgentGate \
  --constructor-args $(cast abi-encode "constructor(address)" 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F)
```

After deploying, set `contractAddress` in `frontend/config.js` and serve
the `frontend/` directory as a static site (any static host works — there
is no backend).

## Measured gas (local Anvil, optimizer on, 200 runs)

| Action | Gas |
|---|---|
| Deploy AgentGate | 862,878 |
| Deploy MockAgentID (testnet only) | 116,823 |
| createCampaign | ~165,000 |
| register | ~126,200 |

At BSC gas prices (~0.1–1 gwei), deployment costs a fraction of a cent
to a few cents in BNB.

## Hackathon compliance notes

- No QR-code / pairing login anywhere: the frontend connects a wallet
  only via the standard `window.ethereum` extension flow, and every
  transaction is confirmed by the user in their own wallet.
- No credentials of any kind are collected (no seed phrases, private
  keys, API secrets, or pairing codes).
- No promised returns and no "passive income" language anywhere.
- No Binance/BNB brand impersonation: the project is named AgentGate.
- Agent ID is used as an access-control gate, not as a tool to look up
  other people's wallets.
- The contract is fully open-source (this repo) with owner permissions
  disclosed above.
