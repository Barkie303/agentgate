// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MockAgentID — test stand-in for the SPACE ID Agent ID registry.
/// @notice Mirrors the only registry surface AgentGate relies on: balanceOf.
/// Also used by the BSC testnet deploy script, where no official Agent ID
/// registry is published.
contract MockAgentID {
    mapping(address => uint256) private balances;

    function setBalance(address account, uint256 amount) external {
        balances[account] = amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}
