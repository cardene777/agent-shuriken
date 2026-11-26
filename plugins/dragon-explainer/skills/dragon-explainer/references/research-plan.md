# Research plan

For an explainer of a standard, an API, or a protocol, research in this order before writing text or drawing figures.

## Order

1. **Pin the version**: record the specification URL, its version, and the date you checked it. When the page says the specification has been obsoleted or updated by a newer one, read the newer one too, and explain the version the reader will meet in practice; name the other one as a fact about the topic (for example "RFC X replaces RFC Y and renames Z").
2. **Read the scope**: what it defines and what it leaves out.
3. **List the operations**: the logical operations of an API (create, get, update, complete, cancel, ...) or the messages of a protocol.
4. **Read the bindings**, when it has them: for each transport (for example REST), the endpoint, method, input, and response.
5. **Read states and failures**: state transitions, completion, cancellation, retries, and idempotency.
6. **Separate implementation differences**, when there is an implementation to explain: keep what a demo leaves out and what production adds apart from what the specification says.

## Claim ledger

Save the findings as `claims.json` next to `content.json`, in this shape.

```json
{
  "sources": [
    {
      "id": "lending-api-rest",
      "url": "https://example.org/spec/2026-01/lending-rest/",
      "version": "2026-01",
      "checked_at": "YYYY-MM-DD"
    }
  ],
  "claims": [
    {
      "id": "loan-operations",
      "claim": "A loan has five logical operations",
      "source": "lending-api-rest",
      "location": "Operations",
      "artifact": {"section": "a-s2", "figure": "a-ladder"}
    }
  ]
}
```

Do not add tables or code examples for a claim that has no section or figure in the ledger.
