# Challenge #7 - Compromised

## 1. Challenge Overview
- **Protocol Type:** Off-Chain Oracle Leakage & Spot Price Manipulation
- **Objective:** Manipulate the NFT oracle price to buy low and sell high, drain all ETH from the exchange, transfer 999 ETH to the recovery account, and restore the original NFT price.

## 2. Vulnerability Analysis
- **Vulnerability Type:** Off-Chain Private Key Leakage / Oracle Median Price Manipulation
- **Vulnerable Data Snippet (HTTP Response Headers):**
  ```HTTP
	HTTP/2 200 OK
	content-type: text/html
	content-language: en
	vary: Accept-Encoding
	server: cloudflare

	4d 48 67 33 5a 44 45 31 59 6d 4a 68 4d 6a 5a 6a 4e 54 49 7a 4e 6a 67 7a 59 6d 5a 6a 4d 32 52 6a 4e 32 4e 6b 59 7a 56 6b 4d 57 49 34 59 54 49 33 4e 44 51 30 4e 44 63 31 4f 54 64 6a 5a 6a 52 6b 59 54 45 33 4d 44 56 6a 5a 6a 5a 6a 4f 54 6b 7a 4d 44 59 7a 4e 7a 51 30

	4d 48 67 32 4f 47 4a 6b 4d 44 49 77 59 57 51 78 4f 44 5a 69 4e 6a 51 33 59 54 59 35 4d 57 4d 32 59 54 56 6a 4d 47 4d 78 4e 54 49 35 5a 6a 49 78 5a 57 4e 6b 4d 44 6c 6b 59 32 4d 30 4e 54 49 30 4d 54 51 77 4d 6d 46 6a 4e 6a 42 69 59 54 4d 33 4e 32 4d 30 4d 54 55 35
  ```
- **Root Cause & Flaw Details:**
1. **Off-Chain Key Exposure：** Two oracle node private keys were exposed inside hex/base64-encoded HTTP response headers.
2. **Low Quorum Threshold:** The oracle calculates prices based on the median of only 3 trusted nodes. Controlling 2 out of 3 nodes (a 66% majority) allows total control over the reported median spot price.
 

## 3. Attack Steps
1. Key Extraction: Intercept the HTTP response headers and decode the raw hex/base64 payload to extract 2 oracle node private keys and derive their wallet addresses.
2. Manipulate Price Downward: Impersonate both compromised oracle nodes using vm.prank() and call TrustfulOracle.postPrice(), setting the price of DVNFT to 0.01 ether for both nodes.
3. Trigger Median Price Collapse: Since 2 out of 3 nodes report 0.01 ether, the median price of DVNFT drops from 999 ether down to 0.01 ether.
4. Buy NFT at Low Price: Impersonate the player account using vm.prank() and call Exchange.buyOne{value: 0.01 ether}() to purchase 1 DVNFT at the drastically reduced price.
5. Manipulate Price Upward: Impersonate both oracle nodes again and call postPrice() to update the DVNFT price to 999.01 ether (matching the total ETH balance of the Exchange contract, including the 0.01 ether paid during purchase).
6. Sell NFT & Drain Exchange: Impersonate the player account, approve Exchange to handle the DVNFT, and call Exchange.sellOne() to sell the NFT at 999.01 ether, completely draining the exchange's ETH balance.
7. Fund Recovery & Reset Price: Transfer 999 ETH to the recovery account. Finally, impersonate the oracle nodes to restore the original DVNFT price back to 999 ether to satisfy assertEq(oracle.getMedianPrice("DVNFT"), INITIAL_NFT_PRICE).

## 4. Proof of Concept (PoC)
- **Test Contract Path:** [`test/compromised/Compromised.t.sol`](../test/compromised/Compromised.t.sol)
- **Execution Command:**
  ```bash
  forge test --match-test test_compromised -vvvv
  ```

## 5. Mitigation Strategies

### 1. Increase Oracle Threshold & Source Nodes
- **Flaw:** The system relies on only 3 oracle nodes, where compromising 2 keys grants total control over the median price.
- **Fix:** Increase the number of independent oracle nodes (e.g., 10+) and raise the minimum quorum requirement to significantly increase the cost of a 51%/majority takeover attack.

### 2. Implement Time-Weighted Average Price (TWAP) 
- **Flaw:** TrustfulOracle directly uses instantaneous spot median prices, allowing extreme price spikes or crashes within a single block.
- **Fix:** Integrate Time-Weighted Average Price (TWAP) mechanisms (such as Uniswap v3 TWAP or Chainlink time windows). Even if spot prices are briefly manipulated, TWAP requires multiple blocks to shift, completely neutralizing single-block arbitrage and flash loan exploits.

### 3. Enforce Price Bounds & Circuit Breakers
Introduce maximum price change thresholds in TrustfulOracle.sol to reject anomalous outlier price reports (e.g., jumping instantaneously from 0.01 ETH to 999 ETH):
```solidity
// Maximum allowed percentage price change per update (e.g., ±20%)
uint256 public constant MAX_PRICE_CHANGE_PERCENT = 20;

function _isValidPriceChange(uint256 newPrice, uint256 oldPrice) internal pure returns (bool) {
    if (oldPrice == 0) return true;
    uint256 maxAllowed = oldPrice + (oldPrice * MAX_PRICE_CHANGE_PERCENT / 100);
    uint256 minAllowed = oldPrice - (oldPrice * MAX_PRICE_CHANGE_PERCENT / 100);
    return newPrice >= minAllowed && newPrice <= maxAllowed;
}
```

## 6. Auditor's Perspective & Lessons Learned
- **Custom / Low-Node Oracles:** Always flag custom oracle implementations with small node sets as critical attack vectors for price manipulation.
- **Dynamic Balance Drain:** When cashing out, avoid hardcoding balance amounts (like 999.01 ether). Dynamically query address(exchange).balance to guarantee the pool is fully drained for _isSolved() verification.
- **Off-Chain Leakage Risks:** Smart contract security extends beyond on-chain logic (reentrancy, overflows). Off-chain data exposure—such as private keys in API headers, config files, or frontend logs—presents an immediate, catastrophic threat to on-chain funds.