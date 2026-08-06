// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/EtherBank.sol";
import "../src/Attacker.sol";

contract ReentrancyTest is Test {
    EtherBank public etherBank;
    Attacker public attacker;

    //模拟正常用户
    address public alice = makeAddr("alice");
    //模拟攻击者地址
    address public attackerUser = makeAddr("attacker");


    function setUp() public {
        // 部署 EtherBank 合约
        etherBank = new EtherBank();

        // 给 Alice 发送 10 ETH
        vm.deal(alice, 10 ether);

        //给 attackerUser 发送 1 ETH
        vm.deal(attackerUser, 1 ether);

        //切换到Alice身份，存入 5 ETH 到银行
        vm.prank(alice);
        etherBank.deposit{value: 10 ether}();

    }

    //测试代码
    function test_ReentrancyAttack() public {
        // 部署 Attacker 合约，并传入 EtherBank 的地址
        attacker = new Attacker(address(etherBank));
        
        //切换到攻击者身份
        vm.startPrank(attackerUser);
        vm.expectRevert();
        attacker.attack{value: 1 ether}();//攻击者存入 1 ETH 并触发攻击
        
        // attacker.collectFunds();//攻击者把合约里的钱转给自己

        vm.stopPrank();//结束攻击者身份

        console.log(address(attackerUser).balance);

        //断言：攻击者成功把银行里的钱都提走了
        // assertEq(etherBank.getBalance(), 0, "EtherBank should be drained");

        //断言：攻击者自己账户的余额应该是 11 ETH（1 ETH + 10 ETH）
        // assertEq(address(attackerUser).balance, 11 ether, "Attacker should have 11 ETH");
        
    }   



}