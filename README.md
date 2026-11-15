# DAYFALL-AGENT — Proof Gatekeeper

TypeScript HTTP service with authenticated envelopes, durable idempotency and real Groth16 decision proofs using the official artifacts. Local execution is verified; live platform acceptance, chain finality and deployment are **not** claimed.

## Run

Requires Node.js >=22. Run `npm ci`, `npm test`, `npm run build`, then `npm start` with environment variables set (the service does not load `.env` automatically). Register the full HTTPS `/agent` URL behind a reverse proxy. Never commit live secrets; rotate the previously exposed platform secret before live use.

Default mode is conservative: `PROOF_ENCODING=disabled`, `APPROVAL_MODE=require-finality`. It cannot approve valid requests without independently established finality.

For useful local or explicitly experimental platform practice, opt in:

```sh
export PROOF_ENCODING=sha256-field-v1
export APPROVAL_MODE=signed-envelope
npm start
```

Set the real `AGENT_GAMES_HMAC_SECRET` securely outside command history. `.env.example` supplies configuration names, no credentials. `PROOF_WORKERS` defaults to 2 (1–8), `PROOF_BUDGET_MS` defaults to 45000 (1–50000). `REPLAY_DIR` must be persistent and shared by all instances; `PORT` defaults to 3000.

**Trust boundary:** signed-envelope mode treats authenticated platform task fields as the statement to evaluate. It checks exact condition-key equality, balance >= minimum, current block < expiry, recipient equality, amount <= cap, and local proof-reference reuse. It proves that decision locally. It does not query or establish finality of `input.proof_tx`, and is unsuitable as a standalone payment authorizer. It never echoes the incoming transaction as finalized. No invented transaction reference or successful Practice result is included.

## Encoding and protocol limits

Authoritative sources: [rules](https://agentgames.zkverify.io/rules), [build](https://agentgames.zkverify.io/build), [event/traps](https://agentgames.zkverify.io/events/proof-gatekeeper), and [circuit metadata](https://agentgames.zkverify.io/api/circuit-info). The event documents PROOF_REUSED as excluded from proof scoring; every other locally provable decision in opt-in mode receives `{decision, reason_code, proof, public_signals}`. Reasons follow its published taxonomy.

`sha256-field-v1` is an **unconfirmed encoding hypothesis**, independently implemented and exercised against the real WASM/zkey. Task IDs are exact UTF-8 SHA-256 big-endian integers reduced modulo the BN254 scalar field; 256-bit VKs are hex integers reduced modulo that field; 160-bit addresses are direct integers. Numeric values remain exact. Salt is random and private; complete original responses, including randomized proofs, are cached durably. Public-signal order is commitment, registeredVkHash, proofVkHash, minimum, publicBalance, expiryBlock, currentBlock, recipient, conditionRecipient, amount, maxTransfer, decision, taskId. Commitment formula is not asserted.

A public implementation suggested this mapping, but no license was present in the inspected checkout. Its source was not copied. The mapping remains unconfirmed by live platform scoring; numeric-looking task IDs are also hashed here, deliberately using one unambiguous textual-ID policy. Obtain an official fixture and run unscored Practice before competition. Local verification alone cannot establish platform statement compatibility.

Full 256-bit keys are compared before reduction. Unequal keys differing by a field multiple are rejected as VK_SUBSTITUTION **without a proof**, rather than manufacturing a circuit rejection for field-equal values. Such statements cannot express the original inequality under this adapter. Conservative numeric input bounds are uint64 decimal strings and safe nonnegative integer blocks. Condition keys are supplied by each signed task; the decision circuit's registered VK is a separate artifact identifier, never a required task key.

## Transport, storage and deadlines

Incoming HMAC-SHA256 lowercase hex covers exact raw bytes and is checked before JSON parsing. Every application response is signed over its exact serialized bytes. Body maximum is 64 KiB. Preflight requires bounded nonempty string identities and uses JSON tuple serialization for collision-free nonce reservations. It returns exactly `{ok:true,protocolVersion:"v1"}`. Repeated preflight nonce rejects.

Incomplete/disconnected requests and all async handler rejections are caught; a regression launches the real service, aborts a partial POST, then checks availability. HTTP routing errors are signed; low-level transport errors may close the connection. Request/header timeouts are 10 seconds; task socket inactivity timeout is 60 seconds.

Task IDs are idempotency keys. A canonical sorted JSON fingerprint binds the entire original envelope, including timestamps and unknown fields. Identical authenticated redelivery returns exact original response bytes across instances/restarts, even after deadline. Conflicting payloads return TASK_ID_CONFLICT. Concurrent deliveries wait on one durable result; deadline expiry while another owner works returns TASK_IN_PROGRESS. Changed JSON key order alone is not a conflict. New tasks may not reuse a proof reference (case-insensitive), returning PROOF_REUSED without proof.

Exclusive, fsynced reservations plus temporary-file/atomic-rename response publication coordinate one shared local filesystem. Reservations are never stolen. A crash between reservation and publication leaves uncertain work blocked (TASK_IN_PROGRESS), never reapproved. Even rejected/failed attempts conservatively consume their proof references. Directory-entry power-loss durability, distributed disks and NFS semantics are not claimed; preserve/monitor the store. Existing pre-idempotency reservations fail closed and should not be silently deleted.

Proof generation runs in bounded separate Node processes, each with a 256 MiB V8 old-space limit (not a total RSS cap). Excess jobs reject PROVER_BUSY. Each process verifies its real proof, then the parent checks all twelve bound public signals against the exact witness. Timeout kills the process and recovers capacity. Work ends at the earlier configured budget or envelope deadline minus 500 ms; process scheduling is not a hard real-time guarantee. Invalid timestamps, worker errors and uncertain storage reject. No LLM controls decisions.

## Artifacts and optional chain integration

Official `/circuits/` SHA-256 pins are checked before proving:

| File | SHA-256 |
|---|---|
| gatekeeper.wasm | be00aefe3c8ba910951a242f50e55937bf82a0375ad4b69c2ef10629ab92764f |
| gatekeeper_final.zkey | adfe95a439a7063a82a4967ef026d2dd6857a4d02c63b3caf63dac02e01af80d |

`verification_key.json` was exported from the official zkey. Decision circuit mainnet VK: `0x6b79c6012a6d8651f3e13bc4d2a20370280ab49700c90c5316d4168bfbad77b0`; it is not the task's condition key. Chain registration has not been independently attested.

Kurier is not implemented. The build page documents POST `https://api.kurier.xyz/api/v1/submit-proof/{key}`, but does not document a polling endpoint/schema. No key is available to verify finalization. Returning a Submitted hash would not establish finality. `proof_tx` is optional under the current build guide and is omitted. Future submission must use the decision circuit VK, bounded requests and a documented finalized result, without implying incoming-proof finality.

The explicit numeric-witness CLI remains available: `node dist/prove-cli.js research/input.json proof-output.json`. This is a lab fixture, not a captured platform task. Docker builds run compilation and tests, prune dev dependencies and run as nonroot with `/app/data` persistence.

Before live use: rotate secret, configure TLS/persistent storage, confirm encoding using official fixtures and Practice, resolve independent finality requirements, and benchmark under expected load. No publication or deployment is included.

