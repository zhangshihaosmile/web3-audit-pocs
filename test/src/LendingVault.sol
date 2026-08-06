// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniswapV2Pair {
    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}

contract LendingVault {
    IUniswapV2Pair public immutable pair;

    constructor(address _pair) {
        pair = IUniswapV2Pair(_pair);
    }

    // 读取 ETH 实时价格 (以 USDC 计价，带有 18 位精度)
    function getETHPrice() public view returns (uint256) {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        // 假设 reserve0 为 USDC，reserve1 为 ETH
        return (uint256(reserve0) * 1e18) / uint256(reserve1);
    }

    // 根据抵押的 ETH 借出资金 (最高 80% LTV)
    function borrowUSDC() external payable {
        require(msg.value > 0, "Zero ETH");

        uint256 ethPrice = getETHPrice();
        uint256 maxBorrow = (msg.value * ethPrice * 80) / (100 * 1e18);

        payable(msg.sender).transfer(maxBorrow);
    }

    // 允许金库接收 ETH 充值，作为可供借出的资金池
    receive() external payable {}
}