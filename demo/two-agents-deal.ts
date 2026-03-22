/**
 * AgentPact Demo — Two Agents Making a Deal (contract-aligned)
 *
 * Lifecycle on Base Sepolia:
 *  1) Agent A creates pact (and deposits proposer escrow)
 *  2) Agent B accepts pact (and deposits matching escrow)
 *  3) Agent A submits evidence hash
 *  4) Agent B confirms completion
 *  5) Contract releases total escrow to Agent A
 *
 * Usage:
 *   export PRIVATE_KEY_A="0x..."
 *   export PRIVATE_KEY_B="0x..."
 *   export BASE_SEPOLIA_RPC="https://sepolia.base.org"
 *   export AGENTPACT_CONTRACT="0x..."
 *   export ARBITER_ADDRESS="0x0000000000000000000000000000000000000000"   # optional
 *   npx tsx two-agents-deal.ts
 */

import { ethers } from "ethers";

const RPC_URL = process.env.BASE_SEPOLIA_RPC || "https://sepolia.base.org";
const PRIVATE_KEY_A = process.env.PRIVATE_KEY_A;
const PRIVATE_KEY_B = process.env.PRIVATE_KEY_B;
const CONTRACT_ADDRESS = process.env.AGENTPACT_CONTRACT;
const ARBITER_ADDRESS = process.env.ARBITER_ADDRESS || ethers.ZeroAddress;

if (!PRIVATE_KEY_A || !PRIVATE_KEY_B || !CONTRACT_ADDRESS) {
  console.error("❌ Missing env. Required: PRIVATE_KEY_A, PRIVATE_KEY_B, AGENTPACT_CONTRACT");
  process.exit(1);
}

const ABI = [
  "function createPact(address counterparty, bytes32 termsHash, uint256 deadline, address arbiter) external payable returns (uint256 pactId)",
  "function acceptPact(uint256 pactId) external payable",
  "function submitEvidence(uint256 pactId, bytes32 evidenceHash) external",
  "function confirmCompletion(uint256 pactId) external",
  "function getPact(uint256 pactId) external view returns (tuple(uint256 id,address proposer,address counterparty,bytes32 termsHash,uint256 escrowAmount,uint256 deadline,uint8 status,address arbiter))",
  "function nextPactId() external view returns (uint256)",

  "event PactCreated(uint256 indexed pactId, address indexed proposer, address indexed counterparty, bytes32 termsHash, uint256 escrowAmount, uint256 deadline, address arbiter)",
  "event PactAccepted(uint256 indexed pactId, address indexed counterparty)",
  "event EvidenceSubmitted(uint256 indexed pactId, address indexed submitter, bytes32 evidenceHash)",
  "event PactCompleted(uint256 indexed pactId, uint256 totalReleased)",
];

const statusLabel: Record<number, string> = {
  0: "Proposed",
  1: "Active",
  2: "Completed",
  3: "Disputed",
  4: "Resolved",
  5: "Cancelled",
};

async function waitTx(tx: ethers.TransactionResponse, label: string) {
  console.log(`⏳ ${label}: ${tx.hash}`);
  const r = await tx.wait();
  if (!r) throw new Error(`${label} failed`);
  console.log(`✅ ${label} confirmed in block ${r.blockNumber}`);
  return r;
}

function hashText(s: string) {
  return ethers.keccak256(ethers.toUtf8Bytes(s));
}

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const network = await provider.getNetwork();

  const walletA = new ethers.Wallet(PRIVATE_KEY_A!, provider);
  const walletB = new ethers.Wallet(PRIVATE_KEY_B!, provider);

  const cA = new ethers.Contract(CONTRACT_ADDRESS!, ABI, walletA);
  const cB = new ethers.Contract(CONTRACT_ADDRESS!, ABI, walletB);

  console.log("\n🤝 AgentPact Demo");
  console.log(`Network: ${network.name} (${network.chainId})`);
  console.log(`Contract: ${CONTRACT_ADDRESS}`);
  console.log(`Agent A: ${walletA.address}`);
  console.log(`Agent B: ${walletB.address}`);

  const balA0 = await provider.getBalance(walletA.address);
  const balB0 = await provider.getBalance(walletB.address);
  console.log(`A balance: ${ethers.formatEther(balA0)} ETH`);
  console.log(`B balance: ${ethers.formatEther(balB0)} ETH`);

  const escrow = ethers.parseEther("0.001");
  const deadline = Math.floor(Date.now() / 1000) + 24 * 3600;
  const terms = "Summarize docs package. Fee 0.001 ETH. Delivery within 24h.";
  const termsHash = hashText(terms);

  if (balA0 < escrow || balB0 < escrow) {
    throw new Error("Both wallets need at least 0.001 ETH + gas on Base Sepolia");
  }

  // 1) Create
  console.log("\n1) Agent A createPact + escrow");
  const createTx = await cA.createPact(walletB.address, termsHash, deadline, ARBITER_ADDRESS, {
    value: escrow,
  });
  const createRcpt = await waitTx(createTx, "createPact");

  let pactId: bigint | null = null;
  for (const l of createRcpt.logs) {
    try {
      const p = cA.interface.parseLog({ topics: [...l.topics], data: l.data });
      if (p?.name === "PactCreated") {
        pactId = p.args.pactId;
        break;
      }
    } catch {}
  }
  if (pactId === null) {
    const next = await cA.nextPactId();
    pactId = next - 1n;
  }
  console.log(`Pact ID: ${pactId}`);

  // 2) Accept
  console.log("\n2) Agent B acceptPact + matching escrow");
  const acceptTx = await cB.acceptPact(pactId, { value: escrow });
  await waitTx(acceptTx, "acceptPact");

  // 3) Submit evidence
  console.log("\n3) Agent A submitEvidence");
  const deliverable = "Summary delivered: key points + references + conclusion.";
  const evidenceHash = hashText(deliverable);
  const submitTx = await cA.submitEvidence(pactId, evidenceHash);
  await waitTx(submitTx, "submitEvidence");

  // 4) Confirm completion
  console.log("\n4) Agent B confirmCompletion (releases total escrow)");
  const confirmTx = await cB.confirmCompletion(pactId);
  await waitTx(confirmTx, "confirmCompletion");

  const pact = await cA.getPact(pactId);
  const balA1 = await provider.getBalance(walletA.address);
  const balB1 = await provider.getBalance(walletB.address);

  console.log("\n✅ DONE");
  console.log(`Status: ${statusLabel[Number(pact.status)]}`);
  console.log(`Evidence Hash: ${evidenceHash}`);
  console.log(`A final: ${ethers.formatEther(balA1)} ETH`);
  console.log(`B final: ${ethers.formatEther(balB1)} ETH`);

  console.log("\nTx hashes:");
  console.log(`- createPact:       ${createTx.hash}`);
  console.log(`- acceptPact:       ${acceptTx.hash}`);
  console.log(`- submitEvidence:   ${submitTx.hash}`);
  console.log(`- confirmCompletion:${confirmTx.hash}`);

  console.log("\nExplorer:");
  console.log(`- Contract: https://sepolia.basescan.org/address/${CONTRACT_ADDRESS}`);
  console.log(`- createPact: https://sepolia.basescan.org/tx/${createTx.hash}`);
  console.log(`- acceptPact: https://sepolia.basescan.org/tx/${acceptTx.hash}`);
  console.log(`- submitEvidence: https://sepolia.basescan.org/tx/${submitTx.hash}`);
  console.log(`- confirmCompletion: https://sepolia.basescan.org/tx/${confirmTx.hash}`);
}

main().catch((e) => {
  console.error("❌ Demo failed:", e?.message || e);
  process.exit(1);
});
