/**
 * AgentPact SDK — Client
 */

import {
  Contract,
  Signer,
  Provider,
  keccak256,
  toUtf8Bytes,
  ContractTransactionResponse,
} from "ethers";

import { AGENT_PACT_ABI } from "./abi";
import {
  Pact,
  PactStatus,
  PactEvent,
  PactEventCallback,
} from "./types";

/**
 * High-level client for the AgentPact smart contract.
 *
 * @example
 * ```ts
 * const client = new AgentPactClient(provider, signer, "0x...");
 * const pactId = await client.createPact(
 *   "0xCounterparty",
 *   "Build feature X by March",
 *   Math.floor(Date.now() / 1000) + 86400 * 7,
 *   ethers.parseEther("0.1"),
 * );
 * ```
 */
export class AgentPactClient {
  private contract: Contract;
  private readContract: Contract;

  constructor(
    private readonly provider: Provider,
    private readonly signer: Signer,
    private readonly contractAddress: string,
  ) {
    this.contract = new Contract(contractAddress, AGENT_PACT_ABI, signer);
    this.readContract = new Contract(contractAddress, AGENT_PACT_ABI, provider);
  }

  // ─── Write Operations ──────────────────────────────────────────

  /**
   * Create a new pact proposal and deposit escrow.
   * @returns The new pact's ID.
   */
  async createPact(
    counterparty: string,
    terms: string,
    deadline: number,
    escrowAmount: bigint,
  ): Promise<number> {
    const termsHash = AgentPactClient.hashTerms(terms);
    const tx: ContractTransactionResponse = await this.contract.createPact(
      counterparty,
      termsHash,
      deadline,
      { value: escrowAmount },
    );
    const receipt = await tx.wait();
    if (!receipt) throw new Error("Transaction receipt is null");

    // Parse PactCreated event to extract pactId
    const log = receipt.logs.find((l) => {
      try {
        const parsed = this.contract.interface.parseLog({
          topics: [...l.topics],
          data: l.data,
        });
        return parsed?.name === "PactCreated";
      } catch {
        return false;
      }
    });

    if (!log) throw new Error("PactCreated event not found in receipt");

    const parsed = this.contract.interface.parseLog({
      topics: [...log.topics],
      data: log.data,
    });
    return Number(parsed!.args[0]);
  }

  /**
   * Accept a proposed pact (counterparty must match).
   */
  async acceptPact(pactId: number): Promise<void> {
    const tx: ContractTransactionResponse =
      await this.contract.acceptPact(pactId);
    await tx.wait();
  }

  /**
   * Submit evidence hash for a pact.
   */
  async submitEvidence(pactId: number, evidence: string): Promise<void> {
    const evidenceHash = AgentPactClient.hashEvidence(evidence);
    const tx: ContractTransactionResponse =
      await this.contract.submitEvidence(pactId, evidenceHash);
    await tx.wait();
  }

  /**
   * Confirm completion of a pact (releases escrow).
   */
  async confirmCompletion(pactId: number): Promise<void> {
    const tx: ContractTransactionResponse =
      await this.contract.confirmCompletion(pactId);
    await tx.wait();
  }

  /**
   * Dispute a pact with a reason string.
   */
  async disputePact(pactId: number, reason: string): Promise<void> {
    const tx: ContractTransactionResponse =
      await this.contract.disputePact(pactId, reason);
    await tx.wait();
  }

  // ─── Read Operations ───────────────────────────────────────────

  /**
   * Fetch a single pact by ID.
   */
  async getPact(pactId: number): Promise<Pact> {
    const result = await this.readContract.getPact(pactId);
    return this.decodePact(result);
  }

  /**
   * Get all pacts where the current signer is proposer or counterparty.
   */
  async getMyPacts(): Promise<Pact[]> {
    const address = await this.signer.getAddress();
    const ids: bigint[] = await this.readContract.getPactsByAddress(address);
    const pacts = await Promise.all(
      ids.map(async (id) => {
        const raw = await this.readContract.getPact(id);
        return this.decodePact(raw);
      }),
    );
    return pacts;
  }

  // ─── Event Listeners ──────────────────────────────────────────

  /**
   * Listen for PactCreated events.
   */
  onPactCreated(callback: PactEventCallback): void {
    this.contract.on(
      "PactCreated",
      (
        pactId: bigint,
        proposer: string,
        counterparty: string,
        termsHash: string,
        escrowAmount: bigint,
        deadline: bigint,
      ) => {
        callback({
          type: "PactCreated",
          pactId: Number(pactId),
          timestamp: Date.now(),
          data: { proposer, counterparty, termsHash, escrowAmount, deadline: Number(deadline) },
        });
      },
    );
  }

  /**
   * Listen for PactAccepted events.
   */
  onPactAccepted(callback: PactEventCallback): void {
    this.contract.on(
      "PactAccepted",
      (pactId: bigint, counterparty: string) => {
        callback({
          type: "PactAccepted",
          pactId: Number(pactId),
          timestamp: Date.now(),
          data: { counterparty },
        });
      },
    );
  }

  /**
   * Listen for PactCompleted events.
   */
  onPactCompleted(callback: PactEventCallback): void {
    this.contract.on("PactCompleted", (pactId: bigint) => {
      callback({
        type: "PactCompleted",
        pactId: Number(pactId),
        timestamp: Date.now(),
        data: {},
      });
    });
  }

  // ─── Utility Methods ──────────────────────────────────────────

  /**
   * Hash terms string to bytes32 using keccak256.
   */
  static hashTerms(terms: string): string {
    return keccak256(toUtf8Bytes(terms));
  }

  /**
   * Hash evidence string to bytes32 using keccak256.
   */
  static hashEvidence(evidence: string): string {
    return keccak256(toUtf8Bytes(evidence));
  }

  // ─── Internal Helpers ─────────────────────────────────────────

  private decodePact(raw: unknown[]): Pact {
    // Matches: (uint256 id, address proposer, address counterparty,
    //           bytes32 termsHash, uint256 escrowAmount, uint256 deadline,
    //           uint8 status, bytes32 evidenceHash)
    return {
      id: Number(raw[0]),
      proposer: raw[1] as string,
      counterparty: raw[2] as string,
      termsHash: raw[3] as string,
      escrowAmount: BigInt(raw[4] as bigint),
      deadline: Number(raw[5]),
      status: Number(raw[6]) as PactStatus,
      evidenceHash: raw[7] as string,
    };
  }
}
