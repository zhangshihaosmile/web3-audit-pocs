# Challenge #5 - The Rewarder

## 1. Challenge Overview
- **Protocol Type:** Merkle Airdrop / Multi-Token Reward Distribution
- **Objective:** Drain all remaining undistributed DVT and WETH reward tokens from `TheRewarderDistributor` contract and transfer them to the `recovery` account.

## 2. Vulnerability Analysis
- **Vulnerability Type:** Delayed State Update / Batch Claim Replay Attack
- **Vulnerable Code Snippet:**
  ```solidity
  if (i == inputClaims.length - 1) {
      if (!_setClaimed(token, amount, wordPosition, bitsSet)) revert AlreadyClaimed();
  }
  ```
- **Root Cause & Flaw Details:**
1. **Delayed Bitmap Update:** The contract updates user claim status via _setClaimed() only when switching to a different token or processing the final claim in inputClaims.
2. **Batch Replay Exploit:** During iteration across claims for the same token, the contract fails to check or update the bitmap immediately after each valid proof verification. An attacker can supply identical claim items consecutively within a single transaction, repeatedly triggering token transfers before the claimed status is marked in storage.

## 3. Claim Execution Flow Analysis (claimRewards())
1. **Scenario Setup:** User Alice intends to claim DVT and WETH rewards in a single transaction.
2. **Input Preparation:** Pass inputClaims containing batchNumber, amount, tokenIndex, and proof. Array length is 2 (inputClaims[0] for DVT, inputClaims[1] for WETH). inputTokens holds [DVT, WETH].
3. **Loop Initialization:** Iterate through inputClaims (2 iterations total).
4. **Bitmap Position Calculation:** Calculate wordPosition and bitPosition based on inputClaim.batchNumber.
5. **Iteration 1 (DVT Claim):** token is initially empty (address(0)). The token switch condition triggers, setting token = DVT, bitsSet = 1 << 0 = 1, and amount = 2502024387994809.
6. **Token Transfer 1:** Since i != inputClaims.length - 1, _setClaimed() is skipped. The Merkle proof verifies successfully, and 2,502,024,387,994,809 DVT is transferred to Alice.
7. **Iteration 2 (WETH Claim):** token is currently DVT, but inputClaim.tokenIndex points to WETH. Token switch triggers _setClaimed(DVT, amount, wordPosition, bitsSet).
8. **Deferred State Flush (DVT):** Inside _setClaimed(), currentWord & newBits == 0. DVT bitmap updates (claims[msg.sender][word] = 1), and remaining balance decreases.
9. **WETH Setup:** token updates to WETH, bitsSet = 1, amount = 2283829881282225.
10. **Final Iteration Check:** i == inputClaims.length - 1 evaluates to true, triggering _setClaimed() for WETH.
11. **Deferred State Flush (WETH):** Inside _setClaimed(), WETH bitmap updates (claims[msg.sender][word] = 1), and remaining balance decreases.
12. **Token Transfer 2:** Merkle proof verifies successfully, and 2,283,829,881,282,225 WETH is transferred to Alice.

## 4. Attack Steps
1. Token Index Mapping: Track target tokens via IERC20[] inputTokens (0: DVT, 1: WETH).
2. Fetch Remaining Balances: Call getRemaining() on TheRewarderDistributor for both DVT and WETH.
3. Calculate Replay Multipliers: Determine the maximum number of loop iterations required based on remaining protocol balances divided by individual claim amounts.
4. Pre-calculate Merkle Proofs: Cache dvt_proof and weth_proof in local variables to prevent excessive gas consumption or out-of-gas reverts during on-chain execution.
5. Construct Payload Arrays: Utilize two loops to assemble inputClaims arrays for DVT and WETH.
6. Populate DVT Claims: First loop repeatedly appends identical DVT claim structs to inputClaims.
7. Populate WETH Claims: Second loop repeatedly appends identical WETH claim structs to inputClaims.
8. Execute Batch Claim: Invoke claimRewards(inputClaims, inputTokens).
9. Exploit Delayed State Update: The contract repeatedly verifies identical proofs and transfers tokens without marking them as claimed until token switching or function completion.
10. Transfer to Recovery: Sweep all drained DVT and WETH balances to the recovery account.

## 5. Proof of Concept (PoC)
- **Test Contract Path:** [`test/the-rewarder/TheRewarder.t.sol`](../test/the-rewarder/TheRewarder.t.sol)
- **Execution Command:**
  ```bash
  forge test --match-test test_theRewarder -vvvv
  ```

## 6. Mitigation Strategies

### Option A: Immediate Bitmap Update + Batch Transfer (Recommended)
Retain batch transfers for gas efficiency, but **enforce immediate bitmap checks and updates within every loop iteration** to prevent replaying identical claims within the same payload:
```solidity
for (uint256 i = 0; i < inputClaims.length; i++) {
    Claim memory inputClaim = inputClaims[i];
    IERC20 token = inputTokens[inputClaim.tokenIndex];

    // 1. Check: Validate Merkle Proof
    bytes32 leaf = keccak256(abi.encodePacked(msg.sender, inputClaim.amount));
    if (!MerkleProof.verify(inputClaim.proof, distributions[token].merkleRoot, leaf)) {
        revert InvalidProof();
    }

    // 2. Check & Effect: [CORE FIX] Immediately check and update bitmap
    // Reverts inside _setClaimed if already claimed in this or prior iterations
    _setClaimed(token, inputClaim.batchNumber, msg.sender, inputClaim.amount);

    // 3. Accumulate rewards for single batch transfer after loop
    subclaimerRewards += inputClaim.amount;
}

// Single transfer after loop execution
IERC20(token).transfer(msg.sender, subclaimerRewards);
```

### Option B: Per-Iteration Check-Effects-Interactions (CEI)
Perform isolated verification, state update, and token transfer on every claim iteration:
```solidity
for (uint256 i = 0; i < inputClaims.length; i++) {
    Claim memory inputClaim = inputClaims[i];
    IERC20 token = inputTokens[inputClaim.tokenIndex];

    // 1. Check: Merkle Proof
    bytes32 leaf = keccak256(abi.encodePacked(msg.sender, inputClaim.amount));
    if (!MerkleProof.verify(inputClaim.proof, distributions[token].merkleRoot, leaf)) revert InvalidProof();

    // 2. Check & Effect: Update bitmap state immediately
    _setClaimed(token, inputClaim.batchNumber, msg.sender, inputClaim.amount);

    // 3. Interaction: Transfer tokens immediately
    distributions[token].remaining -= inputClaim.amount;
    token.transfer(msg.sender, inputClaim.amount);
}
```

## 7. Auditor's Perspective & Lessons Learned
- **Gas Optimization vs. Security Order:** Never sacrifice state update execution order for gas efficiency. All state checks and bitmap writes must strictly adhere to the Check-Effects-Interactions (CEI) pattern.
- **PoC Gas Optimization:** Avoid repetitive cross-contract calls (such as merkle.getProof()) inside for loops within test scripts. Declare and pre-calculate bytes32[] proof arrays in memory beforehand, using pointer references during iteration to minimize execution gas.
