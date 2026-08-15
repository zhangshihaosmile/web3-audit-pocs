# Challenge #6 - Selfie

## 1. Challenge Overview
- **Protocol Type:** Governance & Flash Loan Integration
- **Objective:** Drain the entire 1.5 million DVT balance from `SelfiePool` and transfer all funds to the `recovery` account.

## 2. Vulnerability Analysis
- **Vulnerability Type:** Instantaneous Flash-Loan Governance Manipulation / Lack of Historical Checkpoints
- **Vulnerable Code Snippet:**
  ```solidity
  uint256 balance = _votingToken.getVotes(who);
  ```
- **Root Cause & Flaw Details:**
The SimpleGovernance contract determines proposal eligibility by checking voting power at the current block height via _votingToken.getVotes(who). Because it relies on instantaneous voting weight rather than historical block snapshots, an attacker can temporarily acquire governance tokens via a flash loan to satisfy the _hasEnoughVotes() threshold (>50% of total supply) and queue a malicious governance action within a single transaction.


## 3. Attack Steps
1. Flash Loan Execution: Call flashLoan() on SelfiePool to borrow 1,500,000 DamnValuableVotes (DVT) tokens.
2. Delegate Voting Weight: Inside the onFlashLoan() callback, execute DamnValuableVotes(token).delegate(address(this)) to convert the borrowed tokens into active voting power.
3. Queue Malicious Action: Call SimpleGovernance.queueAction(). Pass the SelfiePool address as the target contract and abi.encodeWithSignature("emergencyExit(address)", recovery) as the call payload (data).
4. Flash Loan Repayment: Approve SelfiePool to pull the borrowed 1.5M DVT tokens, completing the flash loan cycle.
5. Proposal Validation: During queueAction(), _hasEnoughVotes() evaluates the attacker's current-block voting weight (1.5M votes out of 2M total supply > 50%), successfully passing proposal checks and queuing the actionId.
6. Fast-Forward Timelock: The protocol enforces a 2-day execution delay (ACTION_DELAY = 2 days). Advance the chain timestamp using Foundry cheatcode vm.warp(block.timestamp + 2 days).
7. Execute Malicious Proposal: Call SimpleGovernance.executeAction(actionId). The governance contract invokes emergencyExit(recovery) on SelfiePool via functionCallWithValue(), sweeping all 1.5M DVT tokens to the recovery address.

## 4. Proof of Concept (PoC)
- **Test Contract Path:** [`test/selfie/Selfie.t.sol`](../test/selfie/Selfie.t.sol)
- **Execution Command:**
  ```bash
  forge test --match-test test_selfie -vvvv
  ```

## 5.Mitigation Strategies

### Enforce Historical Block Checkpoints (Core Fix)
Governance contracts must query voting power from historical block snapshots (e.g., OpenZeppelin ERC20Votes.getPastVotes(who, block.number - 1)) rather than instantaneous current-block states, neutralizing flash loan manipulation.

### Introduce Voting Delay & Token Lockups 
- **Voting Delay:** Implement a mandatory delay (e.g., 100 blocks / ~20 minutes) between proposal submission and voting/queuing.
- **Token Locking:** Require governance tokens used for proposing or voting to be locked/staked in the governance contract for a set period (e.g., 3 days).

### Governance Thresholds & Security Controls 
- **Proposal Threshold:** Require proposal creators to hold a minimum percentage (e.g., 1% to 5%) of circulating supply over an extended duration.
- **Emergency Multisig Guard:** Implement a Security Council or Multisig with emergency powers to call cancel() on malicious queued actions during the timelock window.

## 6.Auditor's Perspective & Lessons Learned
- Historical Snapshots in Governance: When auditing governance modules, ensure voting power evaluations strictly use historical snapshots (getPastVotes()) rather than current-block balances (getVotes() or balanceOf()).