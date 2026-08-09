# Challenge #2 - Naive Receiver

## 1. Challenge Overview
- **Protocol Type:** Flash Loan / Meta-Transactions (ERC-2771) / Multicall
- **Objective:** Drain all 10 WETH from the receiver contract and transfer all 1,010 WETH in the pool contract to the recovery account.

## 2. Vulnerability Analysis
- **Vulnerability Types:** Access Control Flaw & Calldata Injection / Context Smuggling (ERC-2771 + Multicall Interaction)
- **Vulnerable Code Snippets:**
  ```solidity
  // Access Control Vulnerability
  function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data) external ...

  // Calldata Injection Vulnerability
  results[i] = Address.functionDelegateCall(address(this), data[i]);
  ```
- **Root Cause & Flaw Details:**
1. **Lack of Access Control:** flashLoan() does not verify whether receiver == msg.sender, allowing anyone to trigger flash loans on behalf of the receiver and force it to pay a 1 WETH fee per execution.
2. **Context Smuggling (ERC-2771 + Multicall):** NaiveReceiverPool inherits ERC2771Context, where _msgSender() extracts the caller's address from the last 20 bytes of msg.data when invoked by trustedForwarder (BasicForwarder). When combined with multicall(), internal delegatecall executions process off-chain constructed calldata without stripping user-controlled trailing bytes. An attacker can craft a sub-call to withdraw() with an arbitrary address (deployer) manually appended to the calldata tail, spoofing _msgSender() to withdraw the protocol's 1,010 WETH.

## 3. Attack Steps
1. **Construct Calldata Array Off-Chain:** Prepare an array of 11 calls in dynamic array calldatas:
	- Calls 0–9: 10 sub-calls to flashLoan() targeting receiver to drain its 10 WETH in fees.
	- Call 10: 1 sub-call to withdraw() with the deployer address (20 bytes) manually appended to the calldata tail to forge administrator identity.
2. **Package Multicall Request:** Encode multicall(calldatas) into request.data for BasicForwarder.
3. **Sign Request (EIP-712):** Sign requestHash using playerPk to generate a valid signature (r, s, v).
4. **Execute Forwarder Request:** Call BasicForwarder.execute(request, signature). Signature verification passes, and BasicForwarder appends player address to the end of request.data.
5. **Trigger Multicall & Calldata Injection:** Inside multicall(), ABI decoder parses only the dynamic array calldatas, ignoring the trailing player address. During the 11th call (withdraw()), msg.sender remains BasicForwarder, and msg.data retains the off-chain forged withdraw() + deployer address.
6. **Unauthorized Withdrawal:** NaiveReceiverPool.withdraw() executes, and _msgSender() reads the trailing deployer address from msg.data, successfully draining all 1,010 WETH to the recovery account.

## 4.Proof of Concept (PoC)
- **Test Contract Path:** [`test/naive-receiver/NaiveReceiver.t.sol`](../test/naive-receiver/NaiveReceiver.t.sol)
- **Execution Command:** 
  ```bash
  forge test --match-test test_naiveReceiver -vvvv
  ```
  
## 5.Mitigation Strategies

### Access Control Mitigation 
- Add caller validation in flashLoan() to ensure only the receiver can trigger a loan on its own behalf:
  ```solidity
  require(receiver == msg.sender, "Receiver must be caller");
  ```

### Calldata Vulnerability Mitigations
1. **Disable Multicall via Forwarder (Recommended):**
   Explicitly restrict multicall() from being invoked through BasicForwarder:
   ```solidity
   require(!isTrustedForwarder(msg.sender), "Multicall from Forwarder disabled");
   ```
   **Effect:** Users can still call individual pool functions via BasicForwarder or call multicall() directly, but cannot execute multicall() through BasicForwarder.
2. **Strict Calldata Length Validation (Defensive Programming):**
   Enforce exact calldata length checks when invoked via forwarder:
   ```solidity
   require(msg.data.length == 88, "Invalid calldata length");
   ```
   **Effect:** When an attacker attempts to inject a 20-byte deployer address at the end of sub-call data[10], the sub-call's msg.data.length becomes 108 bytes, triggering an immediate revert.
3. **Handle Batching in Forwarder (Architectural Fix):**
   Implement batch signature verification and looping at the BasicForwarder level:
   ```solidity
   function executeBatch(Request[] calldata requests, bytes[] calldata signatures) external {
    for (uint256 i = 0; i < requests.length; i++) {
        _verify(requests[i], signatures[i]);
        (bool success, ) = requests[i].target.call(
            abi.encodePacked(requests[i].data, requests[i].from)
        );
        require(success);
    }
   }
   ```
   **Effect:** Bypasses inner delegatecall inside target contracts. The trailing 20 bytes for every sub-call are re-appended by BasicForwarder, preventing attackers from spoofing addresses in sub-call payloads.
 
 # 6. Auditor's Perspective
 - **External Parameter Access Control:** Always check for missing authorization checks when external calls allow passing target/receiver addresses.
 - **ERC-2771 & Multicall Collision:** Exercise extreme caution when combining ERC-2771 meta-transactions (_msgSender()) with Multicall (delegatecall), as nested call delegation can easily lead to context smuggling.
 - **Strict Calldata Boundaries:** Whenever identity extraction relies on slicing trailing bytes from msg.data, rigorously verify that strict calldata length validation is enforced.
 