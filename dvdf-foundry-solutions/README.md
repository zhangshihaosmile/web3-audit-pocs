# Damn Vulnerable DeFi Solutions (Foundry)

A professional repository containing automated Proof-of-Concept (PoC) exploit scripts and detailed audit writeups for **Damn Vulnerable DeFi** challenges, implemented strictly using **Foundry**.

---

## Project Overview

This repository serves as a practical portfolio for Web3 smart contract auditing and vulnerability research. Every challenge is solved by writing executable Foundry tests (`.t.sol`) without relying on external web consoles or Remix, mimicking real-world commercial auditing workflows.

---

## Challenge Progress Tracker

- [x] **01. Unstoppable** | [`Writeup`](writeups/01-unstoppable.md) | [`PoC`](test/unstoppable/Unstoppable.t.sol)
- [x] **02. Naive Receiver** | [`Writeup`](writeups/02-naive-receiver.md) | [`PoC`](test/naive-receiver/NaiveReceiver.t.sol)
- [x] **03. Truster** | [`Writeup`](writeups/03-truster.md) | [`PoC`](test/truster/Truster.t.sol)
- [x] **04. Side Entrance** | [`Writeup`](writeups/04-side-entrance.md) | [`PoC`](test/side-entrance/SideEntrance.t.sol)
- [x] **05. The Reward** | [`Writeup`](writeups/05-the-rewarder.md) | [`PoC`](test/the-rewarder/TheRewarder.t.sol)
- [x] **06. Selfie** | [`Writeup`](writeups/06-selfie.md) | [`PoC`](test/selfie/Selfie.t.sol)
- [x] **07. Compromised** | [`Writeup`](writeups/07-compromised.md) | [`PoC`](test/compromised/Compromised.t.sol)
- [x] **08. Puppet** | [`Writeup`](writeups/08-puppet.md) | [`PoC`](test/puppet/Puppet.t.sol)
- [ ] **09. Puppet V2** | Writeup | PoC
- [ ] **10. Free Rider** | Writeup | PoC

---

## Repository Structure

```text
.
├── src/            # Vulnerable protocol smart contracts
├── test/           # Foundry exploit test scripts (.t.sol)
├── writeups/       # Detailed English audit reports & technical breakdowns (.md)
├── foundry.toml    # Foundry configuration file
└── README.md       # Project documentation & progress checklist
```

## Contact / Profile
- GitHub: zhangshihaosmile
- Email: smile_zhangshihao@163.com
- Role: Web3 Smart Contract Security Researcher / Auditor