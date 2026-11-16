---
tool: ethereum
checked: 2026-11-16
source: EIP-7702 (Final), Security Considerations and Backwards Compatibility, and EIP-7600 (the Pectra meta EIP)
detect: tx\.origin\s*==\s*msg\.sender|msg\.sender\s*==\s*tx\.origin|\.code\.length\s*(==|>|!=)\s*0|extcodesize
---

# A wallet can run code since EIP-7702

EIP-7702 went live on mainnet with Pectra on 2025-05-07.
A wallet (an EOA) can set a delegation, the 23-byte designator `0xef0100 || address`, and then runs that address's code when called.

- `tx.origin == msg.sender` still means the caller holds its key, but that caller can now run code. The EIP's security considerations say 7702 can "Break reentrancy guards of the style `require(tx.origin == msg.sender)`" and "Break atomic sandwich protections which rely on `tx.origin`". A delegated wallet can call a function many times in one transaction
- `EXTCODESIZE` returns 23 for a delegated wallet, so `address.code.length == 0` turns away wallets that use a delegation, and a contract still under construction also has no code

Neither check keeps contract logic out.
To limit bots, use a signature from the project, an allowlist, or a limit per address, and say why the check above does not work.
