// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AgentPact.sol";

contract AgentPactTest is Test {
    AgentPact public pact;

    address proposer    = makeAddr("proposer");
    address counterparty = makeAddr("counterparty");
    address arbiter     = makeAddr("arbiter");
    address outsider    = makeAddr("outsider");

    uint256 constant ESCROW   = 1 ether;
    bytes32 constant TERMS    = keccak256("deliver widget by friday");
    bytes32 constant EVIDENCE = keccak256("proof-of-delivery");
    uint256 deadline;

    function setUp() public {
        pact = new AgentPact();
        deadline = block.timestamp + 7 days;
        vm.deal(proposer, 10 ether);
        vm.deal(counterparty, 10 ether);
        vm.deal(outsider, 10 ether);
    }

    // ═══════════════════════════════════════════════
    //  Happy path: full lifecycle
    // ═══════════════════════════════════════════════

    function test_fullLifecycle() public {
        // 1. Create
        vm.prank(proposer);
        uint256 id = pact.createPact{value: ESCROW}(counterparty, TERMS, deadline, arbiter);
        assertEq(id, 0);

        AgentPact.Pact memory p = pact.getPact(id);
        assertEq(p.proposer, proposer);
        assertEq(p.counterparty, counterparty);
        assertEq(p.escrowAmount, ESCROW);
        assertEq(uint8(p.status), uint8(AgentPact.Status.Proposed));

        // 2. Accept
        vm.prank(counterparty);
        pact.acceptPact{value: ESCROW}(id);
        assertEq(uint8(pact.getPact(id).status), uint8(AgentPact.Status.Active));

        // 3. Submit evidence
        vm.prank(proposer);
        pact.submitEvidence(id, EVIDENCE);
        assertEq(pact.getEvidenceCount(id), 1);
        assertEq(pact.getEvidence(id, 0), EVIDENCE);

        // 4. Confirm completion — both escrows go to proposer
        uint256 balBefore = proposer.balance;
        vm.prank(counterparty);
        pact.confirmCompletion(id);
        assertEq(uint8(pact.getPact(id).status), uint8(AgentPact.Status.Completed));
        assertEq(proposer.balance, balBefore + ESCROW * 2);
    }

    // ═══════════════════════════════════════════════
    //  Dispute flow
    // ═══════════════════════════════════════════════

    function test_disputeAndResolve_proposerWins() public {
        uint256 id = _createAndAccept();

        // Counterparty disputes
        vm.prank(counterparty);
        pact.disputePact(id, "work not delivered");
        assertEq(uint8(pact.getPact(id).status), uint8(AgentPact.Status.Disputed));

        // Arbiter resolves in favour of proposer
        uint256 balBefore = proposer.balance;
        vm.prank(arbiter);
        pact.resolveDispute(id, proposer);
        assertEq(uint8(pact.getPact(id).status), uint8(AgentPact.Status.Resolved));
        assertEq(proposer.balance, balBefore + ESCROW * 2);
    }

    function test_disputeAndResolve_counterpartyWins() public {
        uint256 id = _createAndAccept();

        vm.prank(proposer);
        pact.disputePact(id, "counterparty changed requirements");

        uint256 balBefore = counterparty.balance;
        vm.prank(arbiter);
        pact.resolveDispute(id, counterparty);
        assertEq(counterparty.balance, balBefore + ESCROW * 2);
    }

    // ═══════════════════════════════════════════════
    //  Edge cases — deadline
    // ═══════════════════════════════════════════════

    function test_revert_acceptAfterDeadline() public {
        vm.prank(proposer);
        uint256 id = pact.createPact{value: ESCROW}(counterparty, TERMS, deadline, arbiter);

        // Warp past deadline
        vm.warp(deadline + 1);
        vm.prank(counterparty);
        vm.expectRevert(AgentPact.DeadlineExpired.selector);
        pact.acceptPact{value: ESCROW}(id);
    }

    function test_revert_createWithPastDeadline() public {
        vm.prank(proposer);
        vm.expectRevert(AgentPact.DeadlineMustBeFuture.selector);
        pact.createPact{value: ESCROW}(counterparty, TERMS, block.timestamp, arbiter);
    }

    // ═══════════════════════════════════════════════
    //  Edge cases — unauthorised operations
    // ═══════════════════════════════════════════════

    function test_revert_outsiderCannotAccept() public {
        vm.prank(proposer);
        uint256 id = pact.createPact{value: ESCROW}(counterparty, TERMS, deadline, arbiter);

        vm.prank(outsider);
        vm.expectRevert(AgentPact.NotCounterparty.selector);
        pact.acceptPact{value: ESCROW}(id);
    }

    function test_revert_outsiderCannotSubmitEvidence() public {
        uint256 id = _createAndAccept();

        vm.prank(outsider);
        vm.expectRevert(AgentPact.NotParticipant.selector);
        pact.submitEvidence(id, EVIDENCE);
    }

    function test_revert_proposerCannotConfirm() public {
        uint256 id = _createAndAccept();

        vm.prank(proposer);
        vm.expectRevert(AgentPact.NotCounterparty.selector);
        pact.confirmCompletion(id);
    }

    function test_revert_outsiderCannotDispute() public {
        uint256 id = _createAndAccept();

        vm.prank(outsider);
        vm.expectRevert(AgentPact.NotParticipant.selector);
        pact.disputePact(id, "malicious");
    }

    function test_revert_nonArbiterCannotResolve() public {
        uint256 id = _createAndAccept();

        vm.prank(counterparty);
        pact.disputePact(id, "reason");

        vm.prank(outsider);
        vm.expectRevert(AgentPact.NotArbiter.selector);
        pact.resolveDispute(id, proposer);
    }

    function test_revert_resolveToOutsider() public {
        uint256 id = _createAndAccept();

        vm.prank(counterparty);
        pact.disputePact(id, "reason");

        vm.prank(arbiter);
        vm.expectRevert(AgentPact.NotParticipant.selector);
        pact.resolveDispute(id, outsider);
    }

    // ═══════════════════════════════════════════════
    //  Edge cases — duplicate / wrong-status ops
    // ═══════════════════════════════════════════════

    function test_revert_doubleAccept() public {
        vm.prank(proposer);
        uint256 id = pact.createPact{value: ESCROW}(counterparty, TERMS, deadline, arbiter);

        vm.prank(counterparty);
        pact.acceptPact{value: ESCROW}(id);

        // Second accept should revert (status is now Active, not Proposed)
        vm.prank(counterparty);
        vm.expectRevert(
            abi.encodeWithSelector(
                AgentPact.InvalidStatus.selector,
                AgentPact.Status.Active,
                AgentPact.Status.Proposed
            )
        );
        pact.acceptPact{value: ESCROW}(id);
    }

    function test_revert_confirmOnProposed() public {
        vm.prank(proposer);
        uint256 id = pact.createPact{value: ESCROW}(counterparty, TERMS, deadline, arbiter);

        vm.prank(counterparty);
        vm.expectRevert(
            abi.encodeWithSelector(
                AgentPact.InvalidStatus.selector,
                AgentPact.Status.Proposed,
                AgentPact.Status.Active
            )
        );
        pact.confirmCompletion(id);
    }

    function test_revert_doubleDispute() public {
        uint256 id = _createAndAccept();

        vm.prank(proposer);
        pact.disputePact(id, "first dispute");

        vm.prank(counterparty);
        vm.expectRevert(
            abi.encodeWithSelector(
                AgentPact.InvalidStatus.selector,
                AgentPact.Status.Disputed,
                AgentPact.Status.Active
            )
        );
        pact.disputePact(id, "second dispute");
    }

    // ═══════════════════════════════════════════════
    //  Cancellation
    // ═══════════════════════════════════════════════

    function test_cancelBeforeAcceptance() public {
        vm.prank(proposer);
        uint256 id = pact.createPact{value: ESCROW}(counterparty, TERMS, deadline, arbiter);

        uint256 balBefore = proposer.balance;
        vm.prank(proposer);
        pact.cancelPact(id);
        assertEq(uint8(pact.getPact(id).status), uint8(AgentPact.Status.Cancelled));
        assertEq(proposer.balance, balBefore + ESCROW);
    }

    function test_revert_counterpartyCannotCancel() public {
        vm.prank(proposer);
        uint256 id = pact.createPact{value: ESCROW}(counterparty, TERMS, deadline, arbiter);

        vm.prank(counterparty);
        vm.expectRevert(AgentPact.NotProposer.selector);
        pact.cancelPact(id);
    }

    function test_revert_cancelAfterAcceptance() public {
        uint256 id = _createAndAccept();

        vm.prank(proposer);
        vm.expectRevert(
            abi.encodeWithSelector(
                AgentPact.InvalidStatus.selector,
                AgentPact.Status.Active,
                AgentPact.Status.Proposed
            )
        );
        pact.cancelPact(id);
    }

    // ═══════════════════════════════════════════════
    //  Escrow validation
    // ═══════════════════════════════════════════════

    function test_revert_createWithZeroEscrow() public {
        vm.prank(proposer);
        vm.expectRevert(AgentPact.InsufficientEscrow.selector);
        pact.createPact{value: 0}(counterparty, TERMS, deadline, arbiter);
    }

    function test_revert_acceptWithWrongEscrow() public {
        vm.prank(proposer);
        uint256 id = pact.createPact{value: ESCROW}(counterparty, TERMS, deadline, arbiter);

        vm.prank(counterparty);
        vm.expectRevert(AgentPact.InsufficientEscrow.selector);
        pact.acceptPact{value: ESCROW - 1}(id);
    }

    function test_revert_createWithZeroCounterparty() public {
        vm.prank(proposer);
        vm.expectRevert(AgentPact.ZeroAddress.selector);
        pact.createPact{value: ESCROW}(address(0), TERMS, deadline, arbiter);
    }

    // ═══════════════════════════════════════════════
    //  Events
    // ═══════════════════════════════════════════════

    function test_events_creation() public {
        vm.prank(proposer);
        vm.expectEmit(true, true, true, true);
        emit AgentPact.PactCreated(0, proposer, counterparty, TERMS, ESCROW, deadline, arbiter);
        pact.createPact{value: ESCROW}(counterparty, TERMS, deadline, arbiter);
    }

    function test_events_acceptance() public {
        vm.prank(proposer);
        uint256 id = pact.createPact{value: ESCROW}(counterparty, TERMS, deadline, arbiter);

        vm.prank(counterparty);
        vm.expectEmit(true, true, false, true);
        emit AgentPact.PactAccepted(id, counterparty);
        pact.acceptPact{value: ESCROW}(id);
    }

    // ═══════════════════════════════════════════════
    //  Multiple pacts
    // ═══════════════════════════════════════════════

    function test_multiplePactsIndependent() public {
        vm.prank(proposer);
        uint256 id0 = pact.createPact{value: ESCROW}(counterparty, TERMS, deadline, arbiter);

        vm.prank(proposer);
        uint256 id1 = pact.createPact{value: ESCROW}(counterparty, keccak256("other terms"), deadline, arbiter);

        assertEq(id0, 0);
        assertEq(id1, 1);
        assertEq(pact.nextPactId(), 2);

        // Accept and complete only id0
        vm.prank(counterparty);
        pact.acceptPact{value: ESCROW}(id0);
        vm.prank(counterparty);
        pact.confirmCompletion(id0);

        // id1 should still be Proposed
        assertEq(uint8(pact.getPact(id1).status), uint8(AgentPact.Status.Proposed));
        assertEq(uint8(pact.getPact(id0).status), uint8(AgentPact.Status.Completed));
    }

    // ═══════════════════════════════════════════════
    //  Helpers
    // ═══════════════════════════════════════════════

    function _createAndAccept() internal returns (uint256 id) {
        vm.prank(proposer);
        id = pact.createPact{value: ESCROW}(counterparty, TERMS, deadline, arbiter);
        vm.prank(counterparty);
        pact.acceptPact{value: ESCROW}(id);
    }
}
