---
topic: accounts
subject: EIP-7702 delegation and its initialization
checked: 2026-11-17
source: Ethereum Foundation, EIP-7702 page of the Pectra roadmap on ethereum.org
---

# An EIP-7702 delegate must not be initialized by whoever sees the authorization first

An externally owned account delegated with EIP-7702 runs the code of its delegate. When the delegate's initializer is called in the same transaction that sets the delegation, anyone who sees the signed authorization can call the initializer first with their own parameters and take over the account. The page names two fixes: an initializer that requires the account's own signature over its parameters, or an initializer that only the ERC-4337 EntryPoint may call. Delegating to new code does not clear the storage the previous delegate wrote, and `tx.origin` may now be an account with code. Wallets are expected to allow only delegates they have vetted, so an app should not expect to ask users to sign authorizations for its own delegate, and a delegate should not depend on one trusted relayer.

For a design:

- Let the wallet choose and vet the delegate, and batch and sponsor through the wallet (EIP-5792 `wallet_sendCalls`) instead of asking users to sign an authorization to the app's contract
- When the app does choose the delegate, bind its initializer to the account's signature or to the EntryPoint, and say how storage left by a previous delegate is handled
- Do not treat `tx.origin == msg.sender` as proof that the caller is an externally owned account
