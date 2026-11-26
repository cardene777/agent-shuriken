# How one transfer gets confirmed

In Canton, Alice, Bob, and Bank can each sit on a different validator, and one transaction between them is still confirmed as a whole or rejected as a whole.
This page explains the Confirmation Protocol that decides it, by following one transfer from start to end.

<!-- technique: One running example -->
The example is the same in every section.
Alice gives Bob an IOU of 100 USD that Bank issued (contract C0); C0 is consumed, and a new IOU owned by Bob (contract C1) is created.
Bank is the signatory of the IOU, Alice as its owner is the one allowed to transfer it, and Bob is only an observer of the new IOU.

```dragon
architecture The network in this example

group parties as Three parties [note: each on its own validator, color: slate, icon: user]
  box alice as Alice [note: sends, icon: user]
  box bob as Bob [note: receives, icon: user]
  box bank as Bank [note: issued the IOU, icon: user]
end

group validators as Validators [note: keep the ledger for their parties, color: green, icon: server]
  box va as Validator A [note: hosts Alice, icon: server]
  box vb as Validator B [note: hosts Bob, icon: server]
  box vc as Validator C [note: hosts Bank, icon: server]
end

group sync as Synchronizer X [note: orders and decides, color: blue, icon: net]
  box seq as Sequencer [note: orders and delivers, icon: net]
  box med as Mediator [note: collects confirmations, icon: check]
end

step Three parties on three validators
  say Validator A keeps Alice's ledger, Validator B keeps Bob's, and Validator C keeps Bank's. No validator holds every contract; each holds only the contracts its parties take part in.
  alice -> va: asks for the transfer

step They talk through the synchronizer
  say Validators do not talk to each other directly. They send messages through the Sequencer of Synchronizer X, and the Mediator of the same synchronizer decides whether to commit.
  va -> seq: confirmation request
  seq -> med: what must be confirmed
```

## What are the five stages to a commit?

<!-- technique: A map of the stages -->
The Confirmation Protocol goes through the five stages below.
Step through the figure to follow where each message of the transfer goes.
The later sections take these stages one at a time.

```dragon
sequence Five stages to a commit
box va as Validator A [note: builds and submits, color: green, icon: server]
box seq as Sequencer [note: orders and delivers, color: violet, icon: net]
box vc as Validator C [note: checks for Bank, color: green, icon: shield]
box med as Mediator [note: collects and decides, color: blue, icon: check]

step 1 Build the transaction
  say Validator A runs the Daml code and builds a proposed transaction that consumes C0 and creates C1. No ledger changes yet.

step 2 Ask for confirmation
  say Validator A splits the transaction into views, the parts each recipient may see, encrypts them, and sends them to the Sequencer as one confirmation request, together with what the Mediator must check.
  va -> seq: confirmation request

step 3 Order and deliver
  say The Sequencer gives the request a time and a place in the order, and delivers the encrypted views to the validators involved and the conditions to the Mediator.
  seq -> vc: encrypted view
  seq -> med: what must be confirmed

step 4 Check and answer
  say Validator C runs again only the view it can decrypt, checks Bank's authority, the result, and that C0 is still active, and sends a signed approval to the Mediator through the Sequencer.
  vc -> seq: signed approval
  seq -> med: signed approval

step 5 Decide and update the ledgers
  say The Mediator checks that every confirmation needed has arrived and decides a verdict, which the Sequencer delivers. On approve, each validator consumes C0 and creates C1.
  med -> seq: approve verdict
  seq -> va: approve verdict
  seq -> vc: approve verdict
```

## What does the Sequencer do with the request?

<!-- technique: Misreadings ruled out -->
The Sequencer only gives the request a time and an order and delivers it.
The Sequencer does not decrypt the views, and it does not check the result of the Daml code.
The Mediator does not receive the contracts either, and it does not run the Daml code again.
What the Mediator receives is how many confirmations from which parties the transaction needs.

## What does each validator check?

A validator asked to confirm checks four things, using only the views it was shown.

| What it checks | Where to look in the example |
|---|---|
| Authority | Alice is the owner allowed to transfer, and Bank's signature as signatory is in place |
| Result | Running the Daml code again consumes C0 and creates C1, the same result |
| Contracts still active | C0 has not been consumed and no other transaction is using it |
| What arrived | The view hash, the root hash, and the Sequencer's time agree |

If all four pass, it answers approve; if any fails, it answers reject.
This approval is not the commit yet.
The Mediator decides the commit.

## Which signature means what?

<!-- technique: Pairs told apart -->
Two kinds of signature appear in this transaction, and they mean different things.

| | Submission signature | Confirmation signature |
|---|---|---|
| What it shows | The transaction may be submitted | The transaction is correct as far as the signer can see |
| Who signs | Validator A for an internal party, Alice herself for an external party | The validators that confirm, here those of Alice and Bank |
| What it does not decide | Whether the transaction is correct | Whether the transaction commits |

Even if Alice submits with her own key, the transaction is rejected when Bank's validator finds C0 already used.

## How does the Mediator decide?

<!-- technique: Every combination of conditions -->
In this transaction, one confirmation is needed from Alice's side and one from Bank's side.
Bob is an observer, so no confirmation is needed from Bob's side.
The table gives the verdict for every combination of the two answers.

| Alice's side | Bank's side | Verdict |
|---|---|---|
| Approve | Approve | Commit |
| Approve | Reject | Reject |
| Reject | Approve | Reject |
| Approve | No answer before the deadline | Reject |

In the figure below, choose the validator that answers and its answer, send it, and see how the verdict changes.
What you enter is sent nowhere and is gone when the page is opened again.

```dragon
try Decide on two confirmations

route Confirmation path: Validator - Sequencer - Mediator [from: Validator, to: Mediator]
queue Alice-side [order: Deadline, accept: Validator-A]
queue Bank-side [order: Deadline, accept: Validator-C]
log Verdicts [all: Answer = Approve, yes: Commit, no: Reject]
ask Validator, Side, Answer, Deadline [into: Side, via: Confirmation path]
choose Validator: Validator-A, Validator-B, Validator-C
choose Side: Alice-side, Bank-side
choose Answer: Approve, Reject
choose Deadline: 1, 2, 3, 4
press Decide [from: "Alice-side, Bank-side", into: Verdicts, take: 1]
side Alice-side, Bank-side

item Validator-A [Side: Alice-side, Answer: Approve, Deadline: 2]

step One side is not enough
  say Validator A's approval has arrived, but Bank's side has not answered, so the Mediator does not decide. While Bank's queue is empty, Decide cannot be pressed.
  line Alice-side: Validator-A

step Bank's side approves too
  say When Validator C approves, each side holds one answer. Validator B, which hosts Bob, does not confirm, so its answer does not enter any queue.
  ask Validator-C, Bank-side, Approve, 3

step Both approvals commit
  say Both answers are approvals, so the Mediator decides to commit the whole transaction.
  press Decide

step One rejection rejects everything
  say When Bank's side rejects, the conditions cannot be met, so the whole transaction is rejected, and Alice's side does not change on its own either.
  ask Validator-A, Alice-side, Approve, 1
  ask Validator-C, Bank-side, Reject, 4
  press Decide
```

## When do the contracts change?

Only when the verdict is commit does each validator update its ledger.
Step through the figure to see when C0 and C1 change.

```dragon
state When C0 and C1 change

box plan as Proposed [note: only built by Daml, color: amber, icon: clock]
box active as Active [note: usable on the ledger, color: green, icon: check]
box archived as Archived [note: consumed, color: slate, icon: x]

plan -> finish: On reject nothing changes

step Before the transfer
  say Before the transfer, only C0, owned by Alice, is active.
  start -> active: Bank issued C0 [tag: C0]

step A proposal changes nothing
  say When Validator A runs the Daml code and proposes C1, C0 stays active and C1 is not on any ledger yet.
  start -> plan: C1 proposed [tag: C1]

step Commit changes both at once
  say When the Mediator decides to commit, C0 becomes archived and C1 becomes active. Neither changes without the other.
  active -> archived: Commit [tag: C0]
  plan -> active: Commit [tag: C1]
```

## What to remember

<!-- technique: A closing table and one sentence -->
| Role | What it did in this transaction |
|---|---|
| Validator A (submits) | Ran the Daml code, built the proposed transaction, and asked for confirmation |
| Sequencer | Gave the request an order and delivered it without reading it |
| Validators A and C (confirm) | Checked only the views they were shown and sent signed approvals |
| Mediator | Checked only that the confirmations needed had arrived, and decided to commit |

This is all you need to remember.
Even when each validator sees only part of a transaction, the Mediator decides only whether the confirmations needed have arrived, so one transaction is confirmed or rejected as a whole.
