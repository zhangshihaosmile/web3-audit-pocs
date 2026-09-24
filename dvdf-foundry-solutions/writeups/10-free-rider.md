# Challenge #10 - Free Rider

## 1. Challenge Overview
- **Protocol Type:** NFT Marketplace & Flash Loans / Recovery Manager Integration
- **Objective:** Acquire all 6 NFTs from the marketplace using only 15 WETH via a flash loan, transfer them to the recovery manager contract to collect the 45 ETH bounty, repay the flash loan, and deliver the profits to the player.

## 2. Vulnerability Analysis
- **Vulnerability Type:** `msg.value` Reuse in Loop / Inverted Asset Settlement Logic (CEI Violation)
- **Vulnerable Code Snippet:**
  ```solidity
	function _buyOne(uint256 tokenId) private {
		uint256 priceToPay = offers[tokenId];
		if (priceToPay == 0) {
			revert TokenNotOffered(tokenId);
		}
		// Flaw 1: Failed to validate dynamic remaining balance inside loop
		if (msg.value < priceToPay) {
			revert InsufficientPayment();
		}

		--offersCount;
		// Flaw 2: Ownership transferred before payment settlement
		// transfer from seller to buyer
		DamnValuableNFT _token = token; // cache for gas savings
		_token.safeTransferFrom(_token.ownerOf(tokenId), msg.sender, tokenId);

		// pay seller using cached token
		payable(_token.ownerOf(tokenId)).sendValue(priceToPay);

		emit NFTBought(msg.sender, tokenId, priceToPay);
	}
  ```
- **Root Cause & Flaw Details:**
1. **msg.value Reuse in Loop:** The buyMany function calls _buyOne in a loop without tracking or deducting spent msg.value. Relying on static global msg.value allows an attacker to purchase 6 NFTs (15 ETH each = 90 ETH total) using only 15 ETH.
2. **Inverted Settlement Order:** The marketplace executes safeTransferFrom before paying the seller. Calling _token.ownerOf(tokenId) after the transfer causes the payment target to resolve to the buyer (attacker), effectively refunding the purchase funds back to the buyer.
3. **Lack of CEI Pattern:** State updates and asset transfers are executed out of order, leading to logic flaws during fund settlement.


## 3. Attack Steps
1. **Flash Swap WETH:** Call UniswapV2Pair.swap() to flash borrow 15 WETH from the Uniswap V2 pair.
2. **Unwrap WETH to Native ETH:** Inside uniswapV2Call, withdraw 15 WETH into native ETH via weth.withdraw(15 ether).
3. **Exploit Marketplace Batch Buy:** Call FreeRiderNFTMarketplace.buyMany{value: 15 ether}(tokenIds) to purchase all 6 NFTs. The inverted settlement logic refunds 15 ETH per NFT back to the attacker, resulting in zero-cost acquisition.
4. **Trigger Bounty Payout:** Transfer all 6 NFTs to FreeRiderRecoveryManager using safeTransferFrom to trigger onERC721Received and receive the 45 ETH bounty.
5. **Repay Flash Loan:** Wrap enough ETH back into WETH to repay the principal plus the 0.3% fee (~15.045 WETH), return funds to UniswapV2Pair, and complete the attack.

## 4. Proof of Concept (PoC)
- **Test Contract Path:** [`test/free-rider/FreeRider.t.sol`](../test/free-rider/FreeRidert.t.sol)
- **Execution Command:**
  ```bash
  forge test --match-test test_freeRider -vvvv
  ```

## 5. Mitigation Strategies

### Validate Cumulative msg.value Outside Loop
Validate the total payment upfront outside the loop (e.g., require(msg.value >= priceToPay * tokenIds.length)), rather than repeatedly reading static msg.value inside _buyOne.

### Adhere to Checks-Effects-Interactions (CEI) Pattern 
Cache the original seller address (address seller = _token.ownerOf(tokenId)) prior to transferring the NFT, ensuring asset settlement targets the true seller before ownership changes hands.

## 6. Auditor's Perspective
**Core Logic Mapping:** Map out the primary protocol flow and high-risk control points first, filtering out auxiliary functions to focus on key execution paths and trace state changes under real scenarios.
**`msg.value` Validation:** When auditing payment routines, check whether static global variables like `msg.value` are repeatedly evaluated or relied upon across loops without proper accounting.
**CEI Pattern Compliance:** Verify that all contract state updates are completed before triggering external calls or asset transfers, strictly following the Checks-Effects-Interactions (CEI) pattern.