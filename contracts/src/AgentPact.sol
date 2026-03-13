// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AgentPact
 * @notice A bilateral agreement contract with escrow, evidence submission, and dispute resolution.
 * @dev Designed for AI agent collaboration — two parties lock escrow, one delivers work,
 *      the other confirms, and funds are released. Disputes go to an arbiter.
 */
contract AgentPact is ReentrancyGuard {
    // ──────────────────────────────────────────────
    //  Types
    // ──────────────────────────────────────────────

    enum Status {
        Proposed,   // 0 — created, waiting for counterparty
        Active,     // 1 — counterparty accepted, both sides escrowed
        Completed,  // 2 — counterparty confirmed, escrow released
        Disputed,   // 3 — one party raised a dispute
        Resolved,   // 4 — arbiter resolved the dispute
        Cancelled   // 5 — proposer cancelled before acceptance
    }

    struct Pact {
        uint256 id;
        address proposer;
        address counterparty;
        bytes32 termsHash;
        uint256 escrowAmount;
        uint256 deadline;
        Status  status;
        address arbiter;
    }

    // ──────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────

    uint256 public nextPactId;
    mapping(uint256 => Pact) public pacts;
    mapping(uint256 => bytes32[]) public evidenceHashes;

    // ──────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────

    event PactCreated(
        uint256 indexed pactId,
        address indexed proposer,
        address indexed counterparty,
        bytes32 termsHash,
        uint256 escrowAmount,
        uint256 deadline,
        address arbiter
    );

    event PactAccepted(uint256 indexed pactId, address indexed counterparty);

    event EvidenceSubmitted(uint256 indexed pactId, address indexed submitter, bytes32 evidenceHash);

    event PactCompleted(uint256 indexed pactId, uint256 totalReleased);

    event PactDisputed(uint256 indexed pactId, address indexed disputant, string reason);

    event DisputeResolved(uint256 indexed pactId, address indexed winner, uint256 amount);

    event PactCancelled(uint256 indexed pactId);

    // ──────────────────────────────────────────────
    //  Errors
    // ──────────────────────────────────────────────

    error NotCounterparty();
    error NotProposer();
    error NotParticipant();
    error NotArbiter();
    error InvalidStatus(Status current, Status expected);
    error DeadlineMustBeFuture();
    error InsufficientEscrow();
    error DeadlineExpired();
    error DeadlineNotExpired();
    error ZeroAddress();
    error TransferFailed();

    // ──────────────────────────────────────────────
    //  Modifiers
    // ──────────────────────────────────────────────

    modifier onlyCounterparty(uint256 pactId) {
        if (msg.sender != pacts[pactId].counterparty) revert NotCounterparty();
        _;
    }

    modifier onlyProposer(uint256 pactId) {
        if (msg.sender != pacts[pactId].proposer) revert NotProposer();
        _;
    }

    modifier onlyParticipant(uint256 pactId) {
        Pact storage p = pacts[pactId];
        if (msg.sender != p.proposer && msg.sender != p.counterparty) revert NotParticipant();
        _;
    }

    modifier onlyArbiter(uint256 pactId) {
        if (msg.sender != pacts[pactId].arbiter) revert NotArbiter();
        _;
    }

    modifier inStatus(uint256 pactId, Status expected) {
        if (pacts[pactId].status != expected) revert InvalidStatus(pacts[pactId].status, expected);
        _;
    }

    // ──────────────────────────────────────────────
    //  Core Functions
    // ──────────────────────────────────────────────

    /**
     * @notice Create a new pact and lock msg.value as the proposer's escrow.
     * @param counterparty The other party to the agreement.
     * @param termsHash    Keccak256 of the off-chain terms document.
     * @param deadline     Unix timestamp after which the pact can be cancelled.
     * @param arbiter      Address authorised to resolve disputes (can be address(0) for no arbiter).
     */
    function createPact(
        address counterparty,
        bytes32 termsHash,
        uint256 deadline,
        address arbiter
    ) external payable returns (uint256 pactId) {
        if (counterparty == address(0)) revert ZeroAddress();
        if (deadline <= block.timestamp) revert DeadlineMustBeFuture();
        if (msg.value == 0) revert InsufficientEscrow();

        pactId = nextPactId++;

        pacts[pactId] = Pact({
            id: pactId,
            proposer: msg.sender,
            counterparty: counterparty,
            termsHash: termsHash,
            escrowAmount: msg.value,
            deadline: deadline,
            status: Status.Proposed,
            arbiter: arbiter
        });

        emit PactCreated(pactId, msg.sender, counterparty, termsHash, msg.value, deadline, arbiter);
    }

    /**
     * @notice Counterparty accepts the pact by sending matching escrow.
     */
    function acceptPact(uint256 pactId)
        external
        payable
        onlyCounterparty(pactId)
        inStatus(pactId, Status.Proposed)
    {
        Pact storage p = pacts[pactId];
        if (block.timestamp > p.deadline) revert DeadlineExpired();
        if (msg.value != p.escrowAmount) revert InsufficientEscrow();

        p.status = Status.Active;

        emit PactAccepted(pactId, msg.sender);
    }

    /**
     * @notice Either party submits evidence of completion (hash of off-chain proof).
     */
    function submitEvidence(uint256 pactId, bytes32 evidenceHash)
        external
        onlyParticipant(pactId)
        inStatus(pactId, Status.Active)
    {
        evidenceHashes[pactId].push(evidenceHash);

        emit EvidenceSubmitted(pactId, msg.sender, evidenceHash);
    }

    /**
     * @notice Counterparty confirms the proposer fulfilled the terms.
     *         Releases both escrows to the proposer.
     */
    function confirmCompletion(uint256 pactId)
        external
        nonReentrant
        onlyCounterparty(pactId)
        inStatus(pactId, Status.Active)
    {
        Pact storage p = pacts[pactId];
        p.status = Status.Completed;

        uint256 total = p.escrowAmount * 2;

        (bool ok, ) = p.proposer.call{value: total}("");
        if (!ok) revert TransferFailed();

        emit PactCompleted(pactId, total);
    }

    /**
     * @notice Either participant can raise a dispute while the pact is Active.
     */
    function disputePact(uint256 pactId, string calldata reason)
        external
        onlyParticipant(pactId)
        inStatus(pactId, Status.Active)
    {
        pacts[pactId].status = Status.Disputed;

        emit PactDisputed(pactId, msg.sender, reason);
    }

    /**
     * @notice Arbiter resolves the dispute and sends total escrow to the winner.
     * @param winner Must be either the proposer or the counterparty.
     */
    function resolveDispute(uint256 pactId, address winner)
        external
        nonReentrant
        onlyArbiter(pactId)
        inStatus(pactId, Status.Disputed)
    {
        Pact storage p = pacts[pactId];
        if (winner != p.proposer && winner != p.counterparty) revert NotParticipant();

        p.status = Status.Resolved;

        uint256 total = p.escrowAmount * 2;

        (bool ok, ) = winner.call{value: total}("");
        if (!ok) revert TransferFailed();

        emit DisputeResolved(pactId, winner, total);
    }

    // ──────────────────────────────────────────────
    //  Cancellation (proposer-only, before acceptance or after deadline)
    // ──────────────────────────────────────────────

    /**
     * @notice Proposer cancels an un-accepted pact, recovering their escrow.
     *         Only allowed when status is Proposed.
     */
    function cancelPact(uint256 pactId)
        external
        nonReentrant
        onlyProposer(pactId)
        inStatus(pactId, Status.Proposed)
    {
        Pact storage p = pacts[pactId];
        p.status = Status.Cancelled;

        (bool ok, ) = p.proposer.call{value: p.escrowAmount}("");
        if (!ok) revert TransferFailed();

        emit PactCancelled(pactId);
    }

    // ──────────────────────────────────────────────
    //  View Helpers
    // ──────────────────────────────────────────────

    function getPact(uint256 pactId) external view returns (Pact memory) {
        return pacts[pactId];
    }

    function getEvidenceCount(uint256 pactId) external view returns (uint256) {
        return evidenceHashes[pactId].length;
    }

    function getEvidence(uint256 pactId, uint256 index) external view returns (bytes32) {
        return evidenceHashes[pactId][index];
    }
}
