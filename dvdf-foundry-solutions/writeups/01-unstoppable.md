# Challenge #1 - Unstoppable

## 1. Challenge Overview
- **Protocol Type:** Yield Vault / Token Pool
- **Objective:** Cause a Denial of Service (DoS) on the vault, rendering its core functionality broken.

## 2. Vulnerability Analysis
- **Vulnerability Type:** Denial of Service (DoS) via State Invariant Manipulation
- **Flaw Details:** 
  Under normal operation, users deposit tokens via deposit(), which mints shares to the user while keeping totalSupply and totalAssets() synchronized.
  If an attacker bypasses the deposit() function and directly transfers tokens to the contract (via token.transfer), balanceBefore increases while totalSupply remains unchanged. This causes the internal check convertToShares(totalSupply) != balanceBefore to permanently fail, breaking contract execution.

## 3.Attack Steps
Transfer a small amount of tokens directly to the vault to violate the asset-share balance invariant:
```solidity
token.transfer(vault, 1);
```

## Proof of Concept (PoC)
- **Test Contract Path:** [`test/unstoppable/Unstoppable.t.sol`](../test/unstoppable/Unstoppable.t.sol)
- **Execution Command:**
  ```bash
  forge test --match-test test_unstoppable -vvvv
  ```
 
 ## Mitigation Strategies
1. **Approach A (Remove Strict Equality):**  
  - emove the strict equality check between shares and total assets.
﻿
  - Do not rely on totalSupply == totalAssets().
﻿
  - Use balanceBefore strictly for informational balance tracking, or ensure post-loan balance verification simply checks if the borrowed amount has been repaid.
  
 2. **Approach B (Internal Accounting):**
  - Stop using external balance queries like totalAssets() or balanceOf(address(this)) for critical checks.
  - Switch to dedicated internal accounting state variables.
  - Ensure state variables can only be modified via controlled entry points like deposit() so that direct external transfers cannot impact business logic.
 
 ## Auditor's Perspective
 1. **External Balance Dependency Risk:** Whenever a contract uses totalAssets() or balanceOf(address(this)) for critical business logic or conditional checks, exercise high caution. Anyone can alter this value simply by performing an unrequested transfer().
 2. **DoS Vulnerability:** Assertions tied directly to raw token balances are extremely fragile and susceptible to manipulation-based DoS attacks.
 3. **Internal Accounting vs. External Balance:** Routinely flag any contract logic that relies on "external balances" instead of secure "internal accounting" trackers.
