# Challenge #9 - Puppet V2

## 1. Challenge Overview
- **Protocol Type:** Lending Pool & Uniswap V2 AMM Spot Price Oracle Integration
- **Objective:** Drain all 1,000,000 DVT tokens from `PuppetV2Pool` using minimal WETH collateral and transfer them to the `recovery` account.

## 2. Vulnerability Analysis
- **Vulnerability Type:** AMM Spot Price Oracle Manipulation / Low-Liquidity Pool Exploitation
- **Vulnerable Code Snippet:**
  ```solidity
	(uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
  ```
- **Root Cause & Flaw Details:**
1. **Single Data Source:** PuppetV2Pool relies exclusively on a single Uniswap V2 pair (getReserves) for price feeds without cross-checking against secondary data sources.
2. **Extremely Low Liquidity (Insufficient Pool Depth):** The Uniswap V2 pool initially contains only 100 DVT and 10 WETH. Slippage costs are negligible, allowing an attacker to trigger massive price slippage with modest capital.

## 3. Attack Steps
1. **Approve Router:** Approve uniswapV2Router to spend 10,000 DVT in preparation for dumping tokens.
2. **Define Swap Path:** Declare the path array for token exchange where path[0] is DVT and path[1] is WETH.
3. **Dump DVT for WETH:** Call uniswapV2Router.swapExactTokensForETH() with the path to swap all 10,000 DVT, crashing DVT's relative price and inflating WETH's valuation.
4. **Calculate Collateral Requirement:** Call lendingPool.calculateDepositOfWETHRequired() to query the exact amount of WETH needed to borrow 1,000,000 DVT under the manipulated market price.
5. **Approve & Borrow:** Approve lendingPool to spend the required WETH collateral (~29.4 WETH) and execute lendingPool.borrow() to withdraw 1,000,000 DVT.
6. **Transfer to Recovery:** Transfer all 1,000,000 borrowed DVT to the recovery account to complete the challenge.

## 4. Proof of Concept (PoC)
- **Test Contract Path:** [`test/puppet-v2/PuppetV2.t.sol`](../test/puppet-v2/PuppetV2.t.sol)
- **Execution Command:**
  ```bash
  forge test --match-test test_puppetV2 -vvvv
  ```

## 5. Mitigation Strategies

### Integrate Decentralized Oracle Networks (Chainlink)
Fetch price data across multiple node operators, aggregate external exchange feeds, filter out outliers, and compute average prices on-chain to eliminate single-source reliance.

### Implement Time-Weighted Average Price (TWAP) 
Use TWAP mechanisms to average asset prices over a specific time window, preventing instantaneous single-block spot price manipulation.

## 6. Auditor's Perspective
- **Oracle Mechanism Review:** Always check whether lending protocols implement Chainlink or TWAP mechanisms for price discovery, keeping a high alert for oracle manipulation vulnerabilities.
- **Never Rely on AMM Spot Prices:** Never use raw AMM spot prices directly as oracle feeds, as spot prices can easily be manipulated within a single transaction via large swaps or flash loans.