// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Vault {

    mapping(address => uint256) public balances;//记录每个地址的余额

    mapping(address => mapping(address => uint256)) public allowances;//记录每个地址对其他地址的授权额度


    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    // 协议初衷：允许特定的第三方（或授权代理）帮用户把钱提走给 recipient
    function withdrawFor(address owner, address recipient, uint256 amount) external {
        //检查转账账户owner是否有足够的余额
        require(balances[owner] >= amount, "Insufficient balance");
        //检查调用者是否被授权提取指定金额
        require(allowances[owner][msg.sender] >= amount, "Not allowed to withdraw this amount");

        balances[owner] -= amount;//扣除owner的余额
        allowances[owner][msg.sender] -= amount;//扣除授权额度
        payable(recipient).transfer(amount);//将金额转给recipient
    }

    function approve(address spender, uint256 amount) external {
        //判断调用者的余额是否足够授权
        require(balances[msg.sender] >= amount, "Insufficient balance to approve");
        allowances[msg.sender][spender] = amount;//记录授权额度
    }
}