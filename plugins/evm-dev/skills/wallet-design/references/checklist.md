# Review checklist for a wallet design

Go through this list after `verify` passes. A design that fails any rule in the first table is not finished: fix it and check again. Say which rules you could not judge and why.

## Rules a design must never break

| Rule | What fails it |
|---|---|
| Keys stay out of reach | A private key or mnemonic is kept in a `.env` file, an environment variable, source code, a database, or browser storage, or the app holds users' keys without the design saying it is custodial and how the keys are protected |
| A lost key can be recovered | The design has no recovery path for a lost or stolen key, or one person can take over an account through recovery without a delay the owner can cancel |
| Keys can be replaced | There is no way to rotate a signer, a session key, or a service key without moving funds to a new account |
| Signatures cannot be replayed | A signed message is not EIP-712 typed data whose domain holds the chain ID and the verifying contract, or it has no nonce and no deadline |
| Smart accounts can sign | Signatures are checked only with `ecrecover`, so smart accounts fail; contract signatures need ERC-1271, and accounts not yet deployed need ERC-6492 |
| Permissions are bounded | A session key or a permission granted by a signature can call any contract or function, has no amount limit, or has no expiry |
| Approvals are bounded | An approval or a Permit2 allowance is unlimited, or has no expiration, where the action needs a known amount |
| Users can revoke | Users cannot see or revoke the approvals, allowances, session keys, and permissions they granted |
| Accounts can be created | The first UserOperation also deploys another contract, such as a passkey signer, or the account's initialization reads or writes the storage of other contracts without a staked factory, which ERC-7562 does not allow at account creation |
| Recovery calls are right | The recovery steps do not name the function each party calls, such as who confirms and who executes once the delay has passed, or the names were not checked against the source code of the recovery module |
| The EntryPoint is pinned | A smart account design does not name its EntryPoint version, or relies on an EntryPoint version that the chosen bundler or paymaster does not support |
| Delegation cannot be hijacked | An EIP-7702 delegate can be initialized by anyone who sees the authorization, instead of only with the account's signature or through the EntryPoint |
| Old delegations leave no traps | Moving an EIP-7702 account to a new delegate ignores the storage the previous delegate wrote, or the design uses `tx.origin` to tell accounts from contracts |
| Sponsorship is limited | A paymaster sponsors without per-user and total limits, so anyone can drain the sponsor's balance |
| Agents cannot overspend | An AI agent holds the owner's key, or pays without a spending limit per payment and per period, an allowlist of payees, and an expiry |
| Signing is readable | Users are asked to sign a permit or permission without seeing in words what it grants, which is how signature phishing drains wallets |

## Rules to check with the team

| Area | Check |
|---|---|
| Chains | Each environment names its chains and chain IDs, and test keys and sponsors never reach mainnet |
| Services | Each bundler, paymaster, and payment service named in Accounts carries the date it was checked, and a deprecated service is not chosen |
| Fallbacks | The design says what happens when a wallet cannot batch calls, cannot use a paymaster, or does not support a permission type |
| Records | Agent payments and sponsored transactions are recorded so a person can review them |
| Testing | The rules above are listed so the contract-tests skill can turn the contract parts into tests |
