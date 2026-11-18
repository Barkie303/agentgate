// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AgentGate.sol";
import "../src/MockAgentID.sol";

/// @notice BSC testnet (chain 97) deployment.
/// @dev No official Agent ID registry is published on testnet, so this script
/// deploys a MockAgentID first and points AgentGate at it. The mock's
/// setBalance() lets anyone grant themselves a test Agent ID for demos.
/// Run (key supplied via env at deploy time, never stored in this repo):
///   forge script script/DeployTestnet.s.sol --rpc-url bsc-testnet --broadcast --verify
contract DeployTestnet is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        MockAgentID mock = new MockAgentID();
        AgentGate gate = new AgentGate(address(mock));

        vm.stopBroadcast();

        console.log("MockAgentID deployed at:", address(mock));
        console.log("AgentGate deployed at:  ", address(gate));
        console.log("Chain id:", block.chainid);
    }
}
