# Challenge #8 - Puppet

## 1. Challenge Overview
- **Protocol Type:** Lending Pool & AMM Spot Price Oracle Integration
- **Objective:** Drain the entire 100,000 DVT balance from PuppetPool using minimal ETH collateral and transfer all funds to the recovery account.

## 2. Vulnerability Analysis
- **Vulnerability Type:** AMM Spot Price Oracle Manipulation / Low-Liquidity Pool Exploitation
- **Vulnerable Code Snippet:**
  ```solidity
	function _computeOraclePrice() private view returns (uint256) {
		// Flaw: Directly calculating spot price via live Uniswap pool balances enables instantaneous manipulation
		return uniswapPair.balance * (10 ** 18) / token.balanceOf(uniswapPair);
	}
  ```
- **Root Cause & Flaw Details:**
1. **Single Data Source:** PuppetPool relies exclusively on a single Uniswap v1 pair for price feeds without cross-checking against secondary sources.
2. **Instantaneous Spot Pricing:** The oracle uses real-time reserve balances (balance), allowing the spot price to be drastically altered within a single transaction.
3. **Low Pool Liquidity:** The initial pool contains only 10 DVT and 10 ETH. Slippage costs are negligible, enabling an attacker to crush DVT's relative value with modest capital.


## 3. Attack Steps
1. Contract Setup: Deploy the Attack contract. Transfer 1,000 DVT and 25 ETH from player to Attack (maintaining getNonce(player) == 1).
2. Dump DVT on Uniswap: Approve Uniswap v1 to spend 1,000 DVT and call tokenToEthSwapInput() to swap 1,000 DVT for ETH.
3. Trigger Price Collapse: The Uniswap pool reserves shift from 10 ETH : 10 DVT to ~0.1 ETH : 1,010 DVT. DVT's spot price collapses while ETH's relative valuation surges.
4. Borrow Under-Collateralized Assets: Call PuppetPool.borrow() to withdraw all 100,000 DVT. Due to the manipulated oracle price, the required ETH collateral drops from 200,000 ETH down to just 19.66 ETH. Transfer all borrowed DVT to the recovery address.
5. Refund & Complete: Refund the remaining ETH from the Attack contract back to player.

## 4. Proof of Concept (PoC)
- **Test Contract Path:** [`test/puppet/Puppet.t.sol`](../test/puppet/Puppet.t.sol)
- **Execution Command:**
  ```bash
  forge test --match-test test_puppet -vvvv
  ```

## 5. Mitigation Strategies

### Integrate Decentralized Oracle Networks (Chainlink)
Replace single-pair DEX queries with decentralized oracle networks like Chainlink. Chainlink aggregates price feeds across multiple liquid exchanges, filters out statistical outliers, and publishes median values on-chain to prevent localized pool manipulation.

### Implement Time-Weighted Average Price (TWAP) 
Utilize TWAP mechanisms (e.g., Uniswap v2/v3 TWAP) that average asset prices over a defined time window (e.g., 30 minutes). TWAP prevents instantaneous single-block spot price manipulation via large swaps or flash loans.

## 6. Auditor's Perspective & Lessons Learned
- **Avoid AMM Spot Prices for Collateralization:** Never use raw AMM spot prices (balanceOf ratios) as collateral valuation feeds in lending/borrowing protocols.
- **Liquidity Depth Assessment:** Always assess the liquidity depth of underlying DEX pairs used as oracle sources; low-liquidity pairs present severe economic attack vectors.