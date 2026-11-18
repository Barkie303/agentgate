// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AgentGate.sol";

/// @notice BSC mainnet (chain 56) deployment.
/// @dev Points AgentGate at the official SPACE ID Agent ID registry.
/// Run (key supplied via env at deploy time, never stored in this repo):
///   forge script script/DeployMainnet.s.sol --rpc-url bsc --broadcast --verify
/// Verify on BscScan afterwards (see README.md).
contract DeployMainnet is Script {
    address public constant AGENT_ID_REGISTRY = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        AgentGate gate = new AgentGate(AGENT_ID_REGISTRY);

        vm.stopBroadcast();

        console.log("AgentGate deployed at:", address(gate));
        console.log("Agent ID registry:    ", AGENT_ID_REGISTRY);
        console.log("Chain id:", block.chainid);
    }
}
