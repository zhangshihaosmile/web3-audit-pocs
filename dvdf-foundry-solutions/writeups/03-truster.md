# Challenge #3 - Truster

## 1. Challenge Overview
- **Protocol Type:** Flash Loan / Arbitrary Execution
- **Objective:** Drain all 1,000,000 DVT tokens from the pool contract in a single transaction and transfer them to the recovery account.

## 2. Vulnerability Analysis
- **Vulnerability Type:** Arbitrary External Call / Missing Input Validation
- **Vulnerable Code Snippet:**
  ```solidity
  target.functionCall(data);
  ```
- **Root Cause & Flaw Details:**
- **Root Cause & Flaw Details:**
  1. The flashLoan function accepts untrusted user input for target and data parameters without proper validation.
  2. During execution, the pool invokes target.functionCall(data), executing arbitrary bytecode within the context of the pool contract itself.
  3. An attacker can set target to the DVT token contract address and data to an encoded approve(spender, amount) call. This tricks the pool into granting full allowance of its DVT tokens to the attacker without violating the flash loan repayment check (since no tokens are borrowed during the flash loan call itself).
 
## 3. Attack Steps
1. **Encode Approval Payload:** Construct calldata using ABI encoding to invoke approve(attackerAddress, poolBalance) on the DVT token contract.
2. **Execute Flash Loan:** Call flashLoan(0, borrower, address(token), payload) with 0 loan amount. The pool executes token.approve() on behalf of itself during functionCall(data).
3. **Drain Funds:** Invoke transferFrom() on the DVT token contract to transfer all 1,000,000 DVT tokens from TrusterLenderPool to the recovery account.

## 4. Proof of Concept (PoC)
- **Test Contract Path:** [`test/truster/Truster.t.sol`](test/truster/Truster.t.sol)
- **Execution Command:**
  ```bash
  forge test --match-test test_truster -vvvv
  ````

## 5.Mitigation Strategies
- **Adopt ERC-3156 Standard:** Replace arbitrary external calls with a fixed callback interface (onFlashLoan), restricting execution to pre-defined receiver functions.
- **Strict Parameter Validation:** If dynamic external calls are strictly necessary, validate target against a strict whitelist and restrict allowed function selectors in data.

## 6.Auditor's Perspective
- Arbitrary External Calls: Flag any function that executes target.call(data) or target.functionCall(data) using untrusted user input as a Critical risk.
- Protocol Context Abuse: Verify if arbitrary calls allow callers to trigger sensitive state modifications (such as approve, transfer, or mint) on behalf of the protocol.