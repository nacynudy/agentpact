/**
 * @agentpact/sdk — AgentPact Smart Contract SDK
 *
 * @example
 * ```ts
 * import { AgentPactClient, PactStatus } from "@agentpact/sdk";
 * ```
 */

export { AgentPactClient } from "./client";
export { AGENT_PACT_ABI } from "./abi";
export {
  PactStatus,
  type Pact,
  type PactEvent,
  type PactEventType,
  type PactEventCallback,
} from "./types";
