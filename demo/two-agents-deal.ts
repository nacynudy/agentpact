/**
 * AgentPact Demo — Two Agents Making a Deal
 *
 * Simulates the full lifecycle of an agent-to-agent pact on Base Sepolia:
 *   1. Agent A (provider) creates a pact: "Summarize docs for 0.001 ETH"
 *   2. Agent B (requester) accepts and locks escrow
 *   3. Agent A completes work, submits evidence hash
 *   4. Agent B verifies and confirms completion
 *   5. Escrow released to Agent A
 *
 * Usage:
 *   export PRIVATE_KEY_A="0x..."
 *   export PRIVATE_KEY_B="0x..."
 *   export BASE_SEPOLIA_RPC="https://sepolia.base.org"
 *   export AGENTPACT_CONTRACT="0x..."
 *   npx tsx two-agents-deal.ts
 */

import { ethers } from "ethers";

// ──────────────────────────────────────────────
// Configuration
// ──────────────────────────────────────────────

const RPC_URL = process.env.BASE_SEPOLIA_RPC || "https://sepolia.base.org";
const PRIVATE_KEY_A = process.env.PRIVATE_KEY_A;
const PRIVATE_KEY_B = process.env.PRIVATE_KEY_B;
const CONTRACT_ADDRESS = process.env.AGENTPACT_CONTRACT;

if (!PRIVATE_KEY_A || !PRIVATE_KEY_B || !CONTRACT_ADDRESS) {
  console.error("❌ Missing environment variables.");
  console.error("   Required: PRIVATE_KEY_A, PRIVATE_KEY_B, AGENTPACT_CONTRACT");
  console.error("   Optional: BASE_SEPOLIA_RPC (defaults to https://sepolia.base.org)");
  process.exit(1);
}

// ──────────────────────────────────────────────
// Contract ABI (only the functions we need)
// ──────────────────────────────────────────────

const AGENTPACT_ABI = [
  // Functions
  "function createPact(address counterparty, bytes32 termsHash, uint256 deadline, uint256 escrowAmount) external returns (uint256 pactId)",
  "function acceptPact(uint256 pactId) external payable",
  "function completePact(uint256 pactId, bytes32 evidenceHash) external",
  "function confirmCompletion(uint256 pactId) external",
  "function getPact(uint256 pactId) external view returns (tuple(uint256 id, address proposer, address counterparty, bytes32 termsHash, uint256 escrowAmount, uint256 deadline, uint8 status, bytes32 evidenceHash))",
  "function pactCount() external view returns (uint256)",

  // Events
  "event PactCreated(uint256 indexed pactId, address indexed proposer, address indexed counterparty, bytes32 termsHash, uint256 escrowAmount, uint256 deadline)",
  "event PactAccepted(uint256 indexed pactId, address indexed acceptor)",
  "event EvidenceSubmitted(uint256 indexed pactId, bytes32 evidenceHash)",
  "event PactCompleted(uint256 indexed pactId)",
];

// Pact status enum (matches contract)
const PactStatusLabels: Record<number, string> = {
  0: "Proposed",
  1: "Active",
  2: "Completed",
  3: "Disputed",
  4: "Resolved",
  5: "Cancelled",
};

// ──────────────────────────────────────────────
// Logging helpers
// ──────────────────────────────────────────────

const COLORS = {
  reset: "\x1b[0m",
  bold: "\x1b[1m",
  dim: "\x1b[2m",
  green: "\x1b[32m",
  blue: "\x1b[34m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
  magenta: "\x1b[35m",
  red: "\x1b[31m",
};

function log(agent: string, emoji: string, message: string, detail?: string) {
  const color = agent === "Agent A" ? COLORS.blue : agent === "Agent B" ? COLORS.magenta : COLORS.green;
  const timestamp = new Date().toISOString().slice(11, 19);
  console.log(
    `${COLORS.dim}[${timestamp}]${COLORS.reset} ${color}${COLORS.bold}${emoji} ${agent}${COLORS.reset} ${message}`
  );
  if (detail) {
    console.log(`${COLORS.dim}           ↳ ${detail}${COLORS.reset}`);
  }
}

function separator(title: string) {
  console.log(`\n${COLORS.yellow}${"═".repeat(60)}${COLORS.reset}`);
  console.log(`${COLORS.yellow}  ${title}${COLORS.reset}`);
  console.log(`${COLORS.yellow}${"═".repeat(60)}${COLORS.reset}\n`);
}

function printPact(pact: any) {
  console.log(`${COLORS.cyan}  ┌─────────────────────────────────────────┐${COLORS.reset}`);
  console.log(`${COLORS.cyan}  │ Pact #${pact.id}                               │${COLORS.reset}`);
  console.log(`${COLORS.cyan}  ├─────────────────────────────────────────┤${COLORS.reset}`);
  console.log(`${COLORS.cyan}  │ Status:     ${PactStatusLabels[Number(pact.status)] || "Unknown"}${" ".repeat(28 - (PactStatusLabels[Number(pact.status)]?.length || 7))}│${COLORS.reset}`);
  console.log(`${COLORS.cyan}  │ Proposer:   ${pact.proposer.slice(0, 10)}...${pact.proposer.slice(-6)}          │${COLORS.reset}`);
  console.log(`${COLORS.cyan}  │ Counter:    ${pact.counterparty.slice(0, 10)}...${pact.counterparty.slice(-6)}          │${COLORS.reset}`);
  console.log(`${COLORS.cyan}  │ Escrow:     ${ethers.formatEther(pact.escrowAmount)} ETH                   │${COLORS.reset}`);
  console.log(`${COLORS.cyan}  │ Deadline:   ${new Date(Number(pact.deadline) * 1000).toISOString().slice(0, 16)}       │${COLORS.reset}`);
  if (pact.evidenceHash !== ethers.ZeroHash) {
    console.log(`${COLORS.cyan}  │ Evidence:   ${pact.evidenceHash.slice(0, 16)}...      │${COLORS.reset}`);
  }
  console.log(`${COLORS.cyan}  └─────────────────────────────────────────┘${COLORS.reset}`);
}

// ──────────────────────────────────────────────
// Wait for transaction helper
// ──────────────────────────────────────────────

async function waitForTx(tx: ethers.TransactionResponse, label: string): Promise<ethers.TransactionReceipt> {
  log("System", "⏳", `Waiting for ${label} to be mined...`, `tx: ${tx.hash}`);
  const receipt = await tx.wait();
  if (!receipt) throw new Error(`Transaction ${label} failed — no receipt`);
  log("System", "✅", `${label} confirmed in block ${receipt.blockNumber}`, `gas used: ${receipt.gasUsed.toString()}`);
  return receipt;
}

// ──────────────────────────────────────────────
// Main Demo
// ──────────────────────────────────────────────

async function main() {
  console.log(`\n${COLORS.bold}${COLORS.green}`);
  console.log("  ╔══════════════════════════════════════════════════╗");
  console.log("  ║          🤝 AgentPact — Two Agents Deal         ║");
  console.log("  ║       Trustless Cooperation on Base Sepolia      ║");
  console.log("  ╚══════════════════════════════════════════════════╝");
  console.log(`${COLORS.reset}\n`);

  // Setup provider and wallets
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const network = await provider.getNetwork();
  log("System", "🌐", `Connected to network: ${network.name} (chainId: ${network.chainId})`);

  const walletA = new ethers.Wallet(PRIVATE_KEY_A!, provider);
  const walletB = new ethers.Wallet(PRIVATE_KEY_B!, provider);

  log("Agent A", "🤖", `Provider wallet: ${walletA.address}`);
  log("Agent B", "🤖", `Requester wallet: ${walletB.address}`);

  // Check balances
  const balanceA = await provider.getBalance(walletA.address);
  const balanceB = await provider.getBalance(walletB.address);
  log("Agent A", "💰", `Balance: ${ethers.formatEther(balanceA)} ETH`);
  log("Agent B", "💰", `Balance: ${ethers.formatEther(balanceB)} ETH`);

  if (balanceB < ethers.parseEther("0.002")) {
    console.error(`\n${COLORS.red}❌ Agent B needs at least 0.002 ETH (0.001 escrow + gas). Get testnet ETH from the Base Sepolia faucet.${COLORS.reset}`);
    process.exit(1);
  }

  // Contract instances (each agent has their own signer)
  const contractA = new ethers.Contract(CONTRACT_ADDRESS!, AGENTPACT_ABI, walletA);
  const contractB = new ethers.Contract(CONTRACT_ADDRESS!, AGENTPACT_ABI, walletB);

  // ──────────────────────────────────────────
  // Step 1: Agent A creates a pact
  // ──────────────────────────────────────────
  separator("Step 1 — Agent A Proposes a Pact");

  const terms = "I will summarize your document collection. Fee: 0.001 ETH. Delivery within 24 hours.";
  const termsHash = ethers.keccak256(ethers.toUtf8Bytes(terms));
  const escrowAmount = ethers.parseEther("0.001");
  const deadline = Math.floor(Date.now() / 1000) + 86400; // 24 hours from now

  log("Agent A", "📝", `Proposing pact to Agent B`);
  log("Agent A", "📋", `Terms: "${terms}"`);
  log("Agent A", "💎", `Escrow: ${ethers.formatEther(escrowAmount)} ETH`);
  log("Agent A", "⏰", `Deadline: ${new Date(deadline * 1000).toISOString()}`);

  const createTx = await contractA.createPact(
    walletB.address,
    termsHash,
    deadline,
    escrowAmount
  );
  const createReceipt = await waitForTx(createTx, "createPact");

  // Parse the PactCreated event to get the pactId
  const createLog = createReceipt.logs.find((l) => {
    try {
      return contractA.interface.parseLog({ topics: l.topics as string[], data: l.data })?.name === "PactCreated";
    } catch {
      return false;
    }
  });

  let pactId: bigint;
  if (createLog) {
    const parsed = contractA.interface.parseLog({ topics: createLog.topics as string[], data: createLog.data });
    pactId = parsed!.args.pactId;
  } else {
    // Fallback: read pactCount
    const count = await contractA.pactCount();
    pactId = count - 1n;
  }

  log("Agent A", "🎉", `Pact created with ID: ${pactId}`);

  // Show pact state
  const pactAfterCreate = await contractA.getPact(pactId);
  printPact(pactAfterCreate);

  // ──────────────────────────────────────────
  // Step 2: Agent B accepts and locks escrow
  // ──────────────────────────────────────────
  separator("Step 2 — Agent B Accepts & Locks Escrow");

  log("Agent B", "🔍", `Reviewing pact #${pactId}...`);
  log("Agent B", "✅", `Terms acceptable. Locking ${ethers.formatEther(escrowAmount)} ETH in escrow.`);

  const acceptTx = await contractB.acceptPact(pactId, {
    value: escrowAmount,
  });
  await waitForTx(acceptTx, "acceptPact");

  log("Agent B", "🔒", `Escrow locked! Pact is now Active.`);

  const pactAfterAccept = await contractA.getPact(pactId);
  printPact(pactAfterAccept);

  // ──────────────────────────────────────────
  // Step 3: Agent A does work & submits evidence
  // ──────────────────────────────────────────
  separator("Step 3 — Agent A Completes Work & Submits Evidence");

  log("Agent A", "⚙️", `Working on document summarization...`);

  // Simulate work being done
  await new Promise((resolve) => setTimeout(resolve, 2000));

  const deliverable = "Summary: The documents cover agent cooperation protocols, escrow mechanisms, and on-chain trust layers. Key findings include...";
  const evidenceHash = ethers.keccak256(ethers.toUtf8Bytes(deliverable));

  log("Agent A", "📄", `Work complete! Deliverable produced.`);
  log("Agent A", "🔗", `Evidence hash: ${evidenceHash}`);
  log("Agent A", "📤", `Submitting evidence on-chain...`);

  const completeTx = await contractA.completePact(pactId, evidenceHash);
  await waitForTx(completeTx, "completePact");

  log("Agent A", "✅", `Evidence submitted on-chain.`);

  const pactAfterComplete = await contractA.getPact(pactId);
  printPact(pactAfterComplete);

  // ──────────────────────────────────────────
  // Step 4: Agent B verifies & confirms
  // ──────────────────────────────────────────
  separator("Step 4 — Agent B Verifies & Confirms Completion");

  log("Agent B", "🔍", `Verifying deliverable against evidence hash...`);

  // Simulate verification
  const verificationHash = ethers.keccak256(ethers.toUtf8Bytes(deliverable));
  const verified = verificationHash === evidenceHash;

  if (verified) {
    log("Agent B", "✅", `Evidence hash matches! Work verified.`);
  } else {
    log("Agent B", "❌", `Evidence mismatch — would raise dispute.`);
    process.exit(1);
  }

  log("Agent B", "🤝", `Confirming completion — releasing escrow to Agent A...`);

  const confirmTx = await contractB.confirmCompletion(pactId);
  await waitForTx(confirmTx, "confirmCompletion");

  // ──────────────────────────────────────────
  // Step 5: Settlement
  // ──────────────────────────────────────────
  separator("Step 5 — Escrow Released!");

  const finalPact = await contractA.getPact(pactId);
  printPact(finalPact);

  // Check final balances
  const finalBalanceA = await provider.getBalance(walletA.address);
  const finalBalanceB = await provider.getBalance(walletB.address);

  log("Agent A", "💰", `Final balance: ${ethers.formatEther(finalBalanceA)} ETH`);
  log("Agent B", "💰", `Final balance: ${ethers.formatEther(finalBalanceB)} ETH`);

  const aGain = finalBalanceA - balanceA;
  const bSpent = balanceB - finalBalanceB;

  log("Agent A", "📈", `Net gain: +${ethers.formatEther(aGain)} ETH (escrow received minus gas)`);
  log("Agent B", "📉", `Net spent: -${ethers.formatEther(bSpent)} ETH (escrow + gas)`);

  // ──────────────────────────────────────────
  // Summary
  // ──────────────────────────────────────────
  console.log(`\n${COLORS.bold}${COLORS.green}`);
  console.log("  ╔══════════════════════════════════════════════════╗");
  console.log("  ║              ✅ Deal Complete!                   ║");
  console.log("  ╠══════════════════════════════════════════════════╣");
  console.log(`  ║  Pact ID:    #${pactId.toString().padEnd(35)}║`);
  console.log(`  ║  Status:     Completed${" ".repeat(27)}║`);
  console.log(`  ║  Escrow:     ${ethers.formatEther(escrowAmount)} ETH → Agent A${" ".repeat(18)}║`);
  console.log(`  ║  Evidence:   On-chain ✓${" ".repeat(26)}║`);
  console.log(`  ║  Network:    Base Sepolia${" ".repeat(24)}║`);
  console.log("  ╚══════════════════════════════════════════════════╝");
  console.log(`${COLORS.reset}`);

  console.log(`${COLORS.dim}Full transaction history:`);
  console.log(`  1. createPact:       ${createTx.hash}`);
  console.log(`  2. acceptPact:       ${acceptTx.hash}`);
  console.log(`  3. completePact:     ${completeTx.hash}`);
  console.log(`  4. confirmCompletion:${confirmTx.hash}${COLORS.reset}\n`);
}

// ──────────────────────────────────────────────
// Run
// ──────────────────────────────────────────────

main()
  .then(() => {
    console.log(`${COLORS.green}🤝 AgentPact demo finished successfully.${COLORS.reset}\n`);
    process.exit(0);
  })
  .catch((err) => {
    console.error(`\n${COLORS.red}❌ Demo failed:${COLORS.reset}`, err.message || err);
    if (err.data) {
      console.error(`${COLORS.dim}   Contract revert data: ${err.data}${COLORS.reset}`);
    }
    process.exit(1);
  });
