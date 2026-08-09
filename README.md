# Smart Contract Security & Audit Portfolio

> **Software QA Engineer transitioning to Full-Time Web3 Smart Contract Security Auditor.**  
> Focused on EVM vulnerability research, DeFi protocol analysis, and property-based unit testing with Foundry.

---

## About Me

- **Current Role:** Software Testing Engineer (Strong background in test design, edge-case discovery, and systematic verification).
- **Target Goal:** Web3 Smart Contract Auditor / Security Researcher.
- **Core Focus:** EVM Deep Dive, DeFi Attack Vectors, Protocol Logic Flaws, and Foundry PoC Development.
- **Philosophy:** Applying rigorous software QA methodologies to smart contract security analysis.

---

## Technical Skill Matrix

| Category | Tooling & Knowledge Base |
| :--- | :--- |
| **Languages** | Solidity, JavaScript, SQL |
| **Audit & Test Frameworks**| Foundry (Forge/Cast), Remix, Hardhat |
| **Standards & Protocols** | ERC-20, ERC-721, ERC-1155, ERC-2771 (Meta-Tx), EIP-712 |
| **Known Attack Vectors** | Access Control, Reentrancy, Context Smuggling, Flash Loans, Calldata Injection |

---

## Repository Content

This repository contains my security research, vulnerability teardowns, and executable Proof-of-Concept (PoC) tests.

```text
web3-audit-pocs/
├── dvdf-foundry-solutions/   # Executable PoCs for Damn Vulnerable DeFi (Foundry)
├── Ethernaut/                # Solutions & notes for OpenZeppelin Ethernaut
└── test/                     # Custom security test suites & C4 report breakdowns
```

## Key PoC Achievements & Progress

### Damn Vulnerable DeFi (Foundry)
- Unstoppable: Identified pool balance manipulation leading to flash loan DoS.

- Naive Receiver: Exploited lack of access control & ERC-2771 context smuggling (Multicall + delegatecall) to drain 1,010 WETH.

- Truster: Exploited arbitrary functionCall to issue unauthorized ERC20 token approvals.

- Side Entrance: Utilized flash loan deposits to bypass protocol accounting balance checks.

### Ethernaut (OpenZeppelin)
- Completed Levels 00–10 (Fallback, Fallout, Reentrancy, Telephone, Token, Delegation, etc.).

## Contact & Links4
- GitHub: zhangshihaosmile
- Email: smile_zhangshihao@163.com
- Status: Open for Independent Audits, Bug Bounties, and Web3 Security Roles.