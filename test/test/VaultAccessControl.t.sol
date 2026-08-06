// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Vault.sol";

contract VaultAccessControlTest is Test {
    Vault vault;

    //模拟用户
    address owner = makeAddr("owner");
    address recipient = makeAddr("recipient");
    address spender = makeAddr("spender");

    function setUp() public {
        //部署vault合约
        vault = new Vault();

        vm.deal(owner, 100 ether);//给owner地址分配100 ether

        //冒充owner地址调用deposit函数存入100 ether
        vm.prank(owner);
        vault.deposit{value: 100 ether}();
    }

    function test_withdrawFor() public {
        //冒充owner地址调用approve函数授权spender可以提取100 ether
        vm.prank(owner);
        vault.approve(spender, 100 ether);


        //冒充spender地址调用withdrawFor函数从owner提取100 ether给recipient
        vm.startPrank(spender);
        vault.withdrawFor(owner, recipient, 100 ether);

        //验证spender授权余额已全部使用，再次调用withdrawFor必定失败
        vm.expectRevert();
        vault.withdrawFor(owner, recipient, 1 ether);

        vm.stopPrank();//停止冒充spender地址

        //断言owner的余额为0，spender的授权额度为0，recipient的余额为100 ether
        assertEq(vault.balances(owner), 0);
        assertEq(vault.allowances(owner, spender), 0);
        assertEq(recipient.balance, 100 ether);
    }

}