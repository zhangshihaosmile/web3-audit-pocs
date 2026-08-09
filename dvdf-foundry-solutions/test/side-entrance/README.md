# Challenge #4 - Side Entrance

## 1. Challenge Overview
- **Protocol Type:** Flash Loan / Lending Pool
- **Objective:** Drain all ETH (1,000 ETH) from the pool contract and transfer it to the recovery address.

## 2. Vulnerability Analysis
- **Root Cause:** Insecure repayment verification relying solely on raw ETH balance (`address(this).balance`).
- **Flaw Details:** 
  The pool verifies flash loan repayment using `if (address(this).balance < balanceBefore) revert RepayFailed()`. 
  Because the contract treats any external balance increase as repayment, an attacker can invoke `deposit()` inside the `execute()` callback using the borrowed ETH. This registers the borrowed ETH as the attacker's personal deposit in the internal accounting mapping while simultaneously restoring `address(this).balance`, tricking the flash loan check into passing.

## 3. Attack Steps
1. Call `flashLoan(1000 ether)` to borrow the entire ETH balance of the pool.
2. In the `execute()` callback, call `deposit{value: 1000 ether}()` under the attacker's identity.
3. The pool's total ETH balance is restored to 1,000 ETH, satisfying `address(this).balance >= balanceBefore` without triggering a revert.
4. Call `withdraw()` to extract the credited 1,000 ETH from the internal ledger, then transfer all funds to the recovery account.

## 4. Proof of Concept (PoC)
- **Test Contract Path:** [`test/side-entrance/SideEntrance.t.sol`](test/side-entrance/SideEntrance.t.sol)
- **Execution Command:**
  ```bash
  forge test --match-test test_sideEntrance -vvvv

## 5.Mitigation Strategies
1. **Reentrancy Lock (nonReentrant):** Apply OpenZeppelin's nonReentrant modifier to flashLoan(), deposit(), and withdraw(). When flashLoan() acquires the lock, invoking deposit() inside the execute() callback will be blocked and trigger an immediate revert.
2. **Independent State Accounting Variable:** Introduce an explicit state variable (e.g., totalDeposits) to track legitimate pool deposits. Record totalDeposits before invoking execute(), and verify after the callback that totalDeposits has not been tampered with.
3. **Explicit Individual Balance Validation:** Record balances[msg.sender] prior to executing the callback, and verify afterwards that the borrower's deposit balance remains unchanged (balances[msg.sender] != balancesBefore -> revert RepayFailed()).

## 6.Auditor's Perspective
1. Be extremely cautious when a contract relies on address(this).balance for repayment validation. Always verify whether raw contract assets have decoupled from internal ledger records.
2. Systematically inspect whether an attacker invoking functions within the execute() or receive() callback window can break the protocol's internal state invariants.
3. Check if the protocol establishes a dedicated, isolated settlement path for repayments. Any design that permits standard operational functions (such as regular deposits) to serve as repayment proof is inherently a high-severity logic vulnerability.
