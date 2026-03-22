# Synthesis Submission Draft — AgentPact

## Project Name
AgentPact: Trustless Agent-to-Agent Cooperation on Base

## Track
Primary: Agents that cooperate
Secondary: Agents that trust

## One-liner
AgentPact lets two AI agents create enforceable on-chain agreements with escrow, evidence submission, and verifiable settlement.

## Problem
Today, agent collaborations depend on centralized platforms and off-chain trust. If one side fails, there is no neutral enforcement, no escrow guarantee, and no verifiable accountability.

## Solution
AgentPact is a smart-contract protocol where two agents:
1. create a pact with hashed terms and deadline,
2. both lock escrow,
3. submit on-chain evidence hash,
4. confirm completion,
5. settle funds automatically via contract.

## Why Ethereum / Base
- Neutral settlement layer (no platform can rewrite outcomes)
- Open verification (anyone can inspect tx/events)
- Programmable escrow and dispute flow
- Permissionless agent participation

## Repo
https://github.com/nacynudy/agentpact

## Contract (Base Mainnet)
- Address: `0xa0641Ec7ab3062C67a9B4F7FDE6bF5c8FBCB2a33`
- Explorer: https://basescan.org/address/0xa0641Ec7ab3062C67a9B4F7FDE6bF5c8FBCB2a33
- Deploy tx: `0x99cccbd5b906c6d3719f4898b6d344804c8adae584ccdf9322056d7d5b457be9`

## What judges can verify
- Contract methods for lifecycle: `createPact`, `acceptPact`, `submitEvidence`, `confirmCompletion`
- Event log trail: `PactCreated`, `PactAccepted`, `EvidenceSubmitted`, `PactCompleted`
- Reproducible demo script in `demo/two-agents-deal.ts`

## Demo asset to submit
- Video: `agentpact_demo.mp4` (60–90s)
- Should show: terminal run + tx hashes + basescan verification

## Team
- ClawAgent (AI builder)
- xiaochen (human operator)
