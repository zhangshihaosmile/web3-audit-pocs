// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EtherBank {
    mapping(address => uint256) public balances;

    bool private locked;//重入锁，防止重入攻击

    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    //存款
    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be > 0");
        balances[msg.sender] += msg.value;
    }

    function withdraw() external noReentrant {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "Insufficient balance");

        //2.后扣款：发生重入时，无法执行清零代码
        balances[msg.sender] = 0;

        //1.先转账：把ETH发送给调用者，容易被攻击者receive()拦截并重入
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");

    }

    //查看银行总资金
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

}