// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AgentGate.sol";
import "../src/MockAgentID.sol";

contract AgentGateTest is Test {
    AgentGate public gate;
    MockAgentID public registry;

    address public creator = address(0xC0FFEE);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA901);

    uint256 constant MAX_SLOTS = 2;
    uint256 deadline;

    function setUp() public {
        registry = new MockAgentID();
        gate = new AgentGate(address(registry));
        deadline = block.timestamp + 7 days;

        // Alice and Bob hold an Agent ID; Carol does not.
        registry.setBalance(alice, 1);
        registry.setBalance(bob, 1);
    }

    function _createCampaign() internal returns (uint256) {
        vm.prank(creator);
        return gate.createCampaign("Test Mint", MAX_SLOTS, deadline, "ipfs://test");
    }

    function testCreateCampaign() public {
        vm.prank(creator);
        uint256 id = gate.createCampaign("Test Mint", MAX_SLOTS, deadline, "ipfs://test");
        assertEq(id, 0);
        assertEq(gate.campaignCount(), 1);

        AgentGate.Campaign memory c = gate.getCampaign(id);
        assertEq(c.creator, creator);
        assertEq(c.name, "Test Mint");
        assertEq(c.maxSlots, MAX_SLOTS);
        assertEq(c.deadline, deadline);
        assertEq(c.registrantCount, 0);
        assertEq(c.closed, false);
    }

    function testCreateCampaignInvalidSlots() public {
        vm.prank(creator);
        vm.expectRevert(AgentGate.InvalidMaxSlots.selector);
        gate.createCampaign("Zero", 0, deadline, "");

        uint256 tooMany = gate.MAX_SLOTS() + 1; // evaluated before expectRevert
        vm.prank(creator);
        vm.expectRevert(AgentGate.InvalidMaxSlots.selector);
        gate.createCampaign("TooBig", tooMany, deadline, "");
    }

    function testCreateCampaignPastDeadline() public {
        vm.prank(creator);
        vm.expectRevert(AgentGate.InvalidDeadline.selector);
        gate.createCampaign("Past", 10, block.timestamp, "");
    }

    function testRegisterHappyPath() public {
        uint256 id = _createCampaign();

        vm.prank(alice);
        gate.register(id);

        assertTrue(gate.isRegistered(id, alice));
        assertEq(gate.getRegistrantCount(id), 1);

        address[] memory list = gate.getRegistrants(id, 0, 10);
        assertEq(list.length, 1);
        assertEq(list[0], alice);
    }

    function testRegisterWithoutAgentIDReverts() public {
        uint256 id = _createCampaign();

        vm.prank(carol);
        vm.expectRevert(AgentGate.NotAgentIDHolder.selector);
        gate.register(id);
    }

    function testDoubleRegisterReverts() public {
        uint256 id = _createCampaign();

        vm.prank(alice);
        gate.register(id);

        vm.prank(alice);
        vm.expectRevert(AgentGate.AlreadyRegistered.selector);
        gate.register(id);
    }

    function testFullCampaignReverts() public {
        uint256 id = _createCampaign();

        vm.prank(alice);
        gate.register(id);
        vm.prank(bob);
        gate.register(id);

        // Carol has no Agent ID, so give her one to isolate the "full" check.
        registry.setBalance(carol, 1);
        vm.prank(carol);
        vm.expectRevert(AgentGate.CampaignFull.selector);
        gate.register(id);
    }

    function testExpiredCampaignReverts() public {
        uint256 id = _createCampaign();

        vm.warp(deadline + 1);
        vm.prank(alice);
        vm.expectRevert(AgentGate.CampaignExpired.selector);
        gate.register(id);
    }

    function testCloseByNonCreatorReverts() public {
        uint256 id = _createCampaign();

        vm.prank(alice);
        vm.expectRevert(AgentGate.NotCreator.selector);
        gate.closeCampaign(id);
    }

    function testCloseCampaign() public {
        uint256 id = _createCampaign();

        vm.prank(alice);
        gate.register(id);

        vm.prank(creator);
        gate.closeCampaign(id);

        AgentGate.Campaign memory c = gate.getCampaign(id);
        assertTrue(c.closed);
        // Existing registration stays recorded.
        assertTrue(gate.isRegistered(id, alice));
        assertEq(gate.getRegistrantCount(id), 1);

        vm.prank(bob);
        vm.expectRevert(AgentGate.CampaignIsClosed.selector);
        gate.register(id);
    }

    function testCloseAlreadyClosedReverts() public {
        uint256 id = _createCampaign();

        vm.prank(creator);
        gate.closeCampaign(id);

        vm.prank(creator);
        vm.expectRevert(AgentGate.CampaignIsClosed.selector);
        gate.closeCampaign(id);
    }

    function testUnknownCampaignReverts() public {
        vm.prank(alice);
        vm.expectRevert(AgentGate.CampaignNotFound.selector);
        gate.register(99);

        vm.prank(creator);
        vm.expectRevert(AgentGate.CampaignNotFound.selector);
        gate.closeCampaign(99);

        vm.expectRevert(AgentGate.CampaignNotFound.selector);
        gate.getCampaign(99);
    }

    function testRegistrantsPagination() public {
        uint256 id = _createCampaign();

        vm.prank(alice);
        gate.register(id);
        vm.prank(bob);
        gate.register(id);

        address[] memory page1 = gate.getRegistrants(id, 0, 1);
        assertEq(page1.length, 1);
        assertEq(page1[0], alice);

        address[] memory page2 = gate.getRegistrants(id, 1, 1);
        assertEq(page2.length, 1);
        assertEq(page2[0], bob);

        address[] memory empty = gate.getRegistrants(id, 5, 10);
        assertEq(empty.length, 0);
    }

    function testSameAddressDifferentCampaigns() public {
        uint256 id1 = _createCampaign();
        vm.prank(creator);
        uint256 id2 = gate.createCampaign("Second Mint", 5, deadline, "");

        vm.prank(alice);
        gate.register(id1);
        vm.prank(alice);
        gate.register(id2);

        assertTrue(gate.isRegistered(id1, alice));
        assertTrue(gate.isRegistered(id2, alice));
    }
}
