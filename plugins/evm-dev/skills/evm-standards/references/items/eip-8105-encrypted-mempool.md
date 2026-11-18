---
status: specified
checked: 2026-11-18
source: ethereum/EIPs: the EIP-8105, EIP-7732, EIP-7805, EIP-7773 (the Glamsterdam meta EIP), and EIP-8081 (the Hegotá meta EIP) documents
can: Transactions could stay encrypted in the mempool until they enter a block, so others cannot read them before they are ordered.
---

# EIP-8105 (Bring an encrypted mempool into the protocol)

A standard that brings into the protocol an encrypted mempool, which keeps transaction contents hidden by encryption until they enter a block.
It does not fix a single encryption scheme, and anyone can register a key provider.

The document sets its aims as preventing reordering attacks (front running and sandwiches) and raising resistance to real-time censorship (`weak` censorship).
It says it does not aim for transaction privacy, because transactions become public later.
It says it builds on the earlier `Shutterized Beacon Chain` research and on an encrypted mempool implementation outside the protocol that already runs on Gnosis Chain.

| Point | What the document says |
|---|---|
| Registering key providers | A system contract (key provider registry) sits on the execution layer, any account can register a key provider, and each registration gets a number. A registration points to a contract that has a decryption function and a key verification function. The consensus layer copies this registry into the beacon chain state. The contract's code is not decided yet |
| Trust links | A key provider can point to another key provider as one it trusts. When there is a directed path from A to B, A is treated as trusting B |
| Encrypted transaction | A new EIP-2718 transaction type `0x05`. It holds the fees, `gas_amount`, the key provider number, the key number, the encrypted contents, and an outer signature |
| Decrypted transaction | A new EIP-2718 transaction type `0x06`. It holds the outer signer (`envelope_signer`), `nonce`, the recipient, the amount, `data`, `access_list`, and a signature |
| Releasing keys | A key provider looks at the execution payload the builder published and, for encrypted transactions that point to its number, either releases the key or announces that it will not. For each key number those transactions name, it must publish one or the other |
| PTC votes | The EIP-7732 PTC (the committee that votes on whether the payload arrived in time) checks the keys and votes, in a dedicated bitfield, on whether a key was present for each encrypted transaction |
| Block order | Decrypted transactions go first, encrypted transactions go last, and other transactions go between them. Each decrypted transaction corresponds, in the same order, to an encrypted transaction of the previous block. It is left out when, for example, the key is attested as missing or decryption fails. An encrypted transaction may come after another only if both use the same key provider or its key provider trusts the earlier one's |
| Execution | An encrypted transaction advances the outer signer's `nonce` and pays for `gas_amount` the same way as EIP-1559. A decrypted transaction pays no fee, and the gas it uses does not count toward the block gas limit |

It says the encryption scheme can be any of threshold encryption, an MPC committee, a TEE, time-lock encryption that can only be broken by spending time, or FHE.
Users rely on key providers not to release keys early and to release them without delay.
As ways for key providers to earn trust, the document lists cryptographic means (threshold encryption, hardware encryption), economic means (slashing for misconduct), and governance means (electing reputable parties by vote).
Rewards and penalties for key providers are not put into the protocol and are left to arrangements decided outside it.

## Current status

The document's status is `Draft`, and it was created on 2025-12-17.
It lists EIP-7732 as a required standard.
When checked on 2026-11-18, it was in none of the four lists (`Scheduled for Inclusion`, `Considered for Inclusion`, `Proposed for Inclusion`, `Declined for Inclusion`) of the Hegotá meta EIP (EIP-8081, status `Draft`).
The required EIP-7732 (enshrined proposer-builder separation) was still in `Last Call`, past its deadline of 2026-11-01, and the Glamsterdam meta EIP (EIP-7773) lists it as `Scheduled for Inclusion`.

A standard that also handles encrypted transactions and delivers them through inclusion lists is covered by the `eip-8184-lucid-encrypted-mempool` item.
The inclusion list standard, EIP-7805 (FOCIL), is `Draft`, and the Hegotá meta EIP lists it as `Scheduled for Inclusion`.

## Not yet shipped

It has not become `Final` and does not run on mainnet.
The code of the registry contract is not yet decided in the document.
Precompiles needed for encryption schemes that are expensive in the EVM are left outside the range of this standard.
Which upgrade it will go into has not been decided.
