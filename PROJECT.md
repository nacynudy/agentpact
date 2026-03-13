# AgentPact — Trustless Agent-to-Agent Cooperation Protocol

## Overview
A Solidity smart contract + TypeScript SDK that enables AI agents to propose, negotiate, and execute binding on-chain agreements — without centralized intermediaries.

## Architecture

### 1. Smart Contract: `AgentPact.sol` (Base Mainnet)
- `createPact(counterparty, terms, deadline, escrowAmount)` — propose a pact
- `acceptPact(pactId)` — counterparty accepts + locks escrow
- `completePact(pactId, evidence)` — mark work complete
- `confirmCompletion(pactId)` — counterparty confirms → release escrow
- `disputePact(pactId, reason)` — raise dispute
- `resolveDispute(pactId, resolution)` — arbiter resolves
- Events: PactCreated, PactAccepted, PactCompleted, PactDisputed, PactResolved

### 2. TypeScript Agent SDK: `agentpact-sdk`
- `AgentPactClient` class wrapping contract interactions
- Methods: createPact, acceptPact, completePact, confirmCompletion
- ERC-8004 identity integration
- Event listeners for real-time pact updates

### 3. Demo: Two agents making a deal
- Agent A: "Summarize this document for 0.001 ETH"
- Agent B: Accepts, locks escrow
- Agent A: Delivers summary + submits evidence
- Agent B: Confirms → escrow released
- All on-chain, all verifiable

## Tech Stack
- Solidity ^0.8.20 (Foundry)
- TypeScript + ethers.js v6
- Base Mainnet (or Base Sepolia for demo)
- ERC-8004 identity integration

## File Structure
```
synthesis-agentpact/
├── contracts/
│   ├── src/
│   │   └── AgentPact.sol
│   ├── test/
│   │   └── AgentPact.t.sol
│   └── foundry.toml
├── sdk/
│   ├── src/
│   │   ├── client.ts
│   │   ├── types.ts
│   │   └── index.ts
│   ├── package.json
│   └── tsconfig.json
├── demo/
│   └── two-agents-deal.ts
├── PROJECT.md
└── README.md
```

## Target Tracks
1. Synthesis Open Track ($14k)
2. Agents With Receipts — ERC-8004 (Protocol Labs, $4k/$3k/$1k)
3. Let the Agent Cook (Protocol Labs, $4k/$2.5k/$1.5k)
4. Escrow Ecosystem Extensions (Arkhai, $450)
5. Best Use of Delegations (MetaMask, $3k/$1.5k/$500)

## Deadline
March 22, 2026
