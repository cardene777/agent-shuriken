---
layout: guide
note: pop
---

# How a transfer gate works

The gate takes each transfer an agent builds and lets only the ones that follow the owner's rules reach the signer.

```dragon
architecture Where the gate stands

box owner as Owner [note: Writes the rules, icon: user]
box agent as Agent [note: Builds each transfer, icon: user]
box gate as Gate [note: Checks each transfer against the rules, icon: server]
box signer as Signer [note: Signs only checked transfers, icon: sign]

step Write the rules
  say The owner writes which recipients and amounts are allowed.
  owner -> gate: rules
step Check a transfer
  say The agent sends a transfer, and the gate checks it before anything is signed.
  agent -> gate: transfer
  gate -> signer: checked transfer
```

The first topic explains what the gate stops, and the second explains the order of its checks.

## What the gate does

### What does the gate stop? [menu: What it stops]

> It stops a transfer that breaks the owner's rules before it is signed.

Look at which transfers reach the signer.

```dragon
architecture The gate between the agent and the signer

box agent as Agent [note: Builds each transfer, icon: user]
box gate as Gate [note: Checks each transfer, icon: server]
box signer as Signer [note: Signs only checked transfers, icon: sign]

step Send
  say The agent sends a transfer to the gate.
  agent -> gate: transfer
step Pass
  say Only a transfer that follows the rules goes on to the signer.
  gate -> signer: checked transfer
```

Only a transfer that follows the rules goes on to the signer.
A transfer that breaks a rule stops at the gate, so the signer never sees it.

## How the gate checks

### In what order does the gate check a transfer? [menu: Check order]

> It reads the transfer, compares it with the rules, and only then lets it go on.

Look at the two checks the gate makes in turn.

```dragon
sequence One transfer through the gate

box agent as Agent [icon: user]
box gate as Gate [icon: server]

step Read
  say The gate reads the recipient and the amount.
  agent -> gate: transfer
step Answer
  say The gate answers with pass or stop.
  gate -> agent: pass or stop [side: below]
```

The gate reads the transfer before it compares anything, so a transfer it cannot read never passes.
The answer is pass or stop, and nothing in between.
