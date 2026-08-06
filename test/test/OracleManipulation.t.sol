// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LendingVault.sol";

contract OracleManipulationTest is Test {

    LendingVault public lendingVault;

    function setUp() public {

        lendingVault = new LendingVault(address(0x1234)); // 假设 Uniswap V2 ETH/USDC 池子地址

        vm.deal(address(lendingVault), 500_000 ether);

        //伪造外部合约的返回值
        vm.mockCall(
            address(lendingVault.pair()),//伪造的合约地址
            abi.encodeWithSelector(IUniswapV2Pair.getReserves.selector),//拦截调用的函数
            //强制返回的数据，1 ETH = 30,00 USDC，带有 18 位精度
            abi.encode(uint112(30_000 * 1e18), uint112(10 * 1e18), uint32(block.timestamp))
        );
    }

    function test_BrowseUSDC() public {
        lendingVault.borrowUSDC{value: 1 ether}();

        //伪造外部合约的返回值
        vm.mockCall(
            address(lendingVault.pair()),//伪造的合约地址
            abi.encodeWithSelector(IUniswapV2Pair.getReserves.selector),//拦截调用的函数
            //强制返回的数据，1 ETH = 30,00 USDC，带有 18 位精度
            abi.encode(uint112(300_000 * 1e18), uint112(1 * 1e18), uint32(block.timestamp))
        );

        vm.mockCall(callee, data, returnData);

        lendingVault.borrowUSDC{value: 1 ether}();

        uint256 ethPrice = lendingVault.getETHPrice();
        assertEq(1 * ethPrice * 80 / (100 * 1e18), 240000); // 1 ETH + 8000 USDC
    }

    //收钱
    receive() external payable {}


}