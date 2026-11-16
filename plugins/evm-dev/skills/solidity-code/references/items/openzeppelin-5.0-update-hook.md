---
tool: openzeppelin
since: 5.0.0
checked: 2026-11-16
source: OpenZeppelin Contracts changelog, 5.0.0
detect: \b_(before|after)TokenTransfer\b
---

# Token hooks became _update

OpenZeppelin Contracts 5.0.0 deleted the `_beforeTokenTransfer` and `_afterTokenTransfer` hooks of `ERC20`, `ERC721`, and `ERC1155`, and added an internal `_update` function to customize instead.
`_transfer`, `_mint`, and `_burn` are no longer virtual, so every customization of a transfer, a mint, or a burn goes through `_update`.

```solidity
function _update(address from, address to, uint256 value) internal override {
    super._update(from, to, value);
}
```

In `ERC721`, `_update(address to, uint256 tokenId, address auth)` has no `from` parameter and returns the previous owner.
