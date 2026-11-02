# Morpheus — Submission Bundle

**Platform:** official program (see program page / Cantina-adjacent Morpheus bounty). Reward est. $22.5k–67.5k combined.
**Requirement:** program wants PoC in a public repo/gist — publish this folder's PoCs before submitting.
**Bytecode match:** 15/16 Sourcify exact/match (see REPORT.md §scope); SessionRouter behavioral match noted.

## Reports to submit (separately)
1. **F-1 Yield-donation buys MOR emission share** (High, VERIFIED) — `MorCapitalPoC.t.sol` — LEAD with "theft of cross-pool emission split, net +EV", NOT donation-forcing (C4-2025-08 LOW-01 adjacency — frame as the profitable theft that donation-forcing enables).
2. **F-3 Fabricated sessions drain fundingAccount** (High, VERIFIED) — `LumerinSessionPoC.t.sol` — anticipate "no proof-of-inference by design" counter; argue unprivileged budget drain (~$74.5k) is not an intended cost model.
3. **F-2 Self-referral** (Med–High, VERIFIED) — in MorCapitalPoC.t.sol — possible dedup vs 2024 V5 referral audit (not machine-verifiable).
4. **F-4 Forced-claim multiplier destruction** (Low, LIKELY) — optional add.

## Run
```
export PATH="$HOME/.foundry/bin:$PATH"
forge test -vvv   # pinned blocks: ETH 26,321,432 / Base 53,383,498
```
