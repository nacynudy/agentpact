/**
 * AgentPact SDK — Type Definitions
 */

/** Status of a Pact */
export enum PactStatus {
  Proposed = 0,
  Active = 1,
  Completed = 2,
  Disputed = 3,
  Resolved = 4,
  Cancelled = 5,
}

/** On-chain Pact data */
export interface Pact {
  id: number;
  proposer: string;
  counterparty: string;
  termsHash: string;
  escrowAmount: bigint;
  deadline: number;
  status: PactStatus;
  evidenceHash: string;
}

/** Event types emitted by the contract */
export type PactEventType =
  | "PactCreated"
  | "PactAccepted"
  | "PactCompleted"
  | "PactDisputed"
  | "PactResolved"
  | "PactCancelled"
  | "EvidenceSubmitted";

/** Decoded contract event */
export interface PactEvent {
  type: PactEventType;
  pactId: number;
  timestamp: number;
  data: Record<string, unknown>;
}

/** Callback signature for event listeners */
export type PactEventCallback = (event: PactEvent) => void;
