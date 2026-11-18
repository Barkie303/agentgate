# AgentGate — hackathon submission draft

Fill in the TBD fields after mainnet deployment, then paste into the
Binance Agent ID Hackathon project submission form. Submissions close
9 Dec 2026 08:00 UTC.

## Project name

AgentGate

## One-paragraph description

AgentGate is an on-chain allowlist registry that makes free mints and
claims fair for Agent ID holders. Projects create allowlist campaigns
with a slot limit and a deadline; only wallets holding an Agent ID can
register, one slot each. Because every user can hold exactly one
non-transferable Agent ID, the allowlist is sybil-resistant by
construction — no forms, no spreadsheets, no wallet spam. Projects
export their registrant list straight from the chain.

## Agent ID usage description

AgentGate integrates Agent ID at the smart-contract level, not just in
the UI. The `AgentGate` contract holds an immutable reference to the
official SPACE ID Agent ID registry
(`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`, ERC-721) and its
`register()` function requires `balanceOf(msg.sender) > 0` — the
on-chain check Binance documents for Agent ID ownership. A registration
is one slot per address per campaign, and since an Agent ID is
non-transferable and limited to one per user, one slot per address
means one slot per real Agent ID holder. The frontend also reads the
registry to tell the connected wallet whether it holds an Agent ID
before it attempts to register. Agent ID is used purely as an
access-control gate; the contract never looks up or exposes other
people's wallets.

## Contract addresses

- AgentGate (BNB Chain mainnet): **TBD — fill after deployment**
- Agent ID registry (read by the contract): `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`
- Source verified on BscScan: **TBD — verify after deployment** (see README)

## Website

**TBD — host `frontend/` on a static host after deployment and put the URL here**

## Repository

**TBD — push this repo to GitHub and put the URL here**

## Reward receiving address

**TBD — the address provided at submission time**

## Checklist before submitting

- [ ] Deploy AgentGate to BSC mainnet (needs BNB for gas + deployer approval)
- [ ] Verify source on BscScan
- [ ] Set `contractAddress` in `frontend/config.js`
- [ ] Host the frontend, confirm campaigns load + register works on mainnet
- [ ] Push repo to GitHub (public)
- [ ] Fill in the TBD fields above
- [ ] Submit the form; drive Agent ID holders to interact (30+ interacting
      Agent ID addresses required for the Innovation Award)
