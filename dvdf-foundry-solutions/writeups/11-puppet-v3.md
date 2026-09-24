# Challenge #11 - Puppet V3

## 1. Challenge Overview
- **Protocol Type:** Lending Pool & Uniswap V3 TWAP Oracle Integration
- **Objective:** Drain all 1,000,000 DVT tokens from `PuppetV3Pool` with zero (or minimal) WETH collateral and transfer them to the `recovery` account.

## 2. Vulnerability Analysis
- **Vulnerability Type:** Uniswap V3 TWAP Oracle Manipulation / Short TWAP Window / Rounding Down Precision Truncation
- **Vulnerable Code Snippet:**
  ```solidity
	uint32 public constant TWAP_PERIOD = 10 minutes;
  ```
- **Root Cause & Flaw Details:**
1. **Extremely Low Liquidity:** Initial liquidity in the Uniswap V3 pool is too shallow. An attacker can easily execute a large single-sided token dump, consuming all active tick liquidity and pushing tick indices into extreme negative territory (e.g., -887272)
2. **Short TWAP Window:** The TWAP_PERIOD is set to only 10 minutes. By holding the crashed price for just 114 seconds, extreme negative ticks accumulate massive weight, severely polluting the 10-minute weighted average tick (arithmeticMeanTick) and causing the derived asset unit price to collapse.
3. **Precision Truncation to Zero:** When the manipulated oracle unit price drops below 1 wei, Solidity's default integer division rounds down to zero, truncating the required collateral to 0.
4. **Missing Zero-Value Safety Assertion:** The protocol lacks zero-value checks (e.g., require(collateral > 0)) after computing required collateral, enabling the attacker to legally borrow all pool assets without depositing collateral. 

## 3. Attack Steps
1. **Configure Mainnet RPC:** Set up an Alchemy RPC URL to fork Ethereum mainnet state for local testing.
2. **Approve Router:** Initialize SwapRouter with its mainnet address and approve it via token.approve() to spend DVT tokens.
3. **Execute Token Dump:** Call swapRouter.exactInputSingle() to dump all held DVT into the Uniswap V3 pool, exhausting liquidity in the active tick range and pushing the tick index into an extremely low-liquidity region.
4. **Simulate Time Elapsed:** Use vm.warp(block.timestamp + 114 seconds) to advance block time by 114 seconds after the dump. The 10-minute weighted average tick (arithmeticMeanTick) drops drastically into extreme negative values (e.g., -887272).
5. **Borrow Assets with Zero Collateral:** Call pool.calculateDepositOfWETHRequired() to compute collateral for 1,000,000 DVT. OracleLibrary.consult() queries 10-minute historical tick accumulators via observe([600, 0]). Due to the heavily weighted negative tick, the calculated unit price drops below 1 wei, which Solidity rounds down to 0. Consequently, no WETH collateral is required to borrow all DVT.
6. **Transfer to Recovery:** Transfer all 1,000,000 borrowed DVT tokens to the recovery account to complete the challenge.

## 4. Proof of Concept (PoC)
- **Test Contract Path:** [`test/puppet-v3/PuppetV3.t.sol`](../test/puppet-v3/PuppetV3.t.sol)
- **Execution Command:**
  ```bash
  forge test --match-test test_puppetV3 -vvvv
  ```

## 5. Mitigation Strategies

### Extend TWAP Time Window
Set a longer TWAP time window (e.g., 30+ minutes) to capture smoother average prices across time, mitigating sustained short-term price manipulation.

### Implement Price Deviation Guards & Circuit Breakers
Enforce price deviation limits to cap maximum oracle price fluctuations within a single transaction or short time frame.

### Dual Oracles & Price Floor
Establish an oracle price floor or integrate Chainlink as a secondary cross-validation feed alongside Uniswap V3 TWAP.

### Zero Checks & Rounding Up
- Enforce require(collateral > 0) assertions on sensitive collateral and fee computations.
- Use Math.Rounding.Up (e.g., via OpenZeppelin's Math.mulDiv) when calculating collateral requirements to ensure amounts round up to at least 1 wei.

## 6. Auditor's Perspective
1. **Liquidity Depth Evaluation:** Assess whether the underlying DEX pool depth is too shallow, allowing low-cost liquidity depletion across active tick ranges.
2. **TWAP Window Sufficiency:** Verify whether TWAP_PERIOD is dangerously short (e.g., < 30 minutes), as short windows remain vulnerable to multi-block manipulation.
3. **Price Protection & Dual Oracles:** Audit for price deviation guards, circuit breakers, or cross-validation mechanisms (e.g., Chainlink / Uniswap dual feeds).
4. **Zero-Value Assertions:** Check for missing require(amount > 0) checks on key asset transfers, borrowings, and collateral calculations.
5. **Rounding Direction:** Ensure collateral and protocol fee calculations use explicit rounding up (Math.Rounding.Up) rather than defaulting to integer division truncation (floor).
6. **Multiply Before Divide:** Confirm arithmetic expressions follow the "multiply before divide" principle to avoid unexpected precision loss during intermediate steps.