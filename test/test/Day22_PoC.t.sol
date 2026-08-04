// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

//审计合约
contract TargetValut {
    mapping(address => uint256) public balances;
    //锁仓1天
    uint256 public lockTime = block.timestamp + 1 days;

    //存款
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    //取款
    function withdraw() external {
        require(block.timestamp > lockTime, "Locked!");
        uint256 amount = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }
}

//测试合约
contract Day22PoCTest is Test {
    TargetValut public valut;
    address public attacker = address(0xBAD);
    
    function setUp() public {
        // 部署目标合约
        valut = new TargetValut();
    }

    function test_AttackWorkflow() public {
        //1.凭空造钱：给攻击者 10 ETH
        vm.deal(attacker, 10 ether);

        //2.伪造身份：切换为攻击者身份去存款 5 ETH
        vm.prank(attacker);
        valut.deposit{value: 5 ether}();

        //断言，验证攻击者成功存了 5 ETH
        assertEq(valut.balances(attacker), 5 ether);

        console.log(address(valut).balance);

        //3.断言报错：处于锁仓期，现在提款必定会被拦截（Revert）
        vm.prank(attacker);
        vm.expectRevert("Locked!");
        valut.withdraw();

        //4.时间穿越：将区块时间拉后 2 天，跳过锁仓期
        vm.warp(block.timestamp + 2 days);

        //再次以攻击者身份提款，此时成功提走资金
        vm.prank(attacker);
        valut.withdraw();

        //最终验证：Valut 合约余额为 0，攻击者余额为 10 ETH
        assertEq(address(valut).balance, 0);
        assertEq(address(attacker).balance, 10 ether);
    }
}