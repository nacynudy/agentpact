// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20 ^0.8.24;

// lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC-1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     // Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {SlotDerivation}.
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct Int256Slot {
        int256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Int256Slot` with member `value` located at `slot`.
     */
    function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns a `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol

// OpenZeppelin Contracts (last updated v5.5.0) (utils/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 *
 * IMPORTANT: Deprecated. This storage-based reentrancy guard will be removed and replaced
 * by the {ReentrancyGuardTransient} variant in v6.0.
 *
 * @custom:stateless
 */
abstract contract ReentrancyGuard {
    using StorageSlot for bytes32;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant REENTRANCY_GUARD_STORAGE =
        0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    /**
     * @dev A `view` only version of {nonReentrant}. Use to block view functions
     * from being called, preventing reading from inconsistent contract state.
     *
     * CAUTION: This is a "view" modifier and does not change the reentrancy
     * status. Use it only on view functions. For payable or non-payable functions,
     * use the standard {nonReentrant} modifier instead.
     */
    modifier nonReentrantView() {
        _nonReentrantBeforeView();
        _;
    }

    function _nonReentrantBeforeView() private view {
        if (_reentrancyGuardEntered()) {
            revert ReentrancyGuardReentrantCall();
        }
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        _nonReentrantBeforeView();

        // Any calls to nonReentrant after this point will fail
        _reentrancyGuardStorageSlot().getUint256Slot().value = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _reentrancyGuardStorageSlot().getUint256Slot().value == ENTERED;
    }

    function _reentrancyGuardStorageSlot() internal pure virtual returns (bytes32) {
        return REENTRANCY_GUARD_STORAGE;
    }
}

// src/AgentPact.sol

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

