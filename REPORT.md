# Morpheus — White-Hat Bug Bounty Audit Report

**Target program:** Morpheus Bug Bounty, Version 2 (effective 2026-08-07) — https://mor.org/bug-bounty · $100,000 Protection Fund, Critical capped at 10% of demonstrated funds at risk.
**Report date:** 2026-11-01
**Submission channel (per program):** devs@mor.org, subject `[BOUNTY] <Contract name> — <one-line impact>`
**Audited code:** `MorpheusAIs/SmartContracts` @ `07f6032fde968ba95948e53681762105d6440b27` (2025-09-29, repo HEAD) and `MorpheusAIs/Morpheus-Lumerin-Node` @ `a54719435022f72af62499fed81a433c8b22b131` (2026-10-28, repo HEAD; deploy-era SessionRouter code = PR #830 / commit `214024e` / cherry-pick `e3dff9d`).
Note: the initially provided clone (`/mnt/data/crypto/bounty/morpheus`, `MorpheusAIs/morpheus` @ `c3012007…`) is the client/node monorepo. Its `contract_library/` is an un-deployed hardhat sample and is **out of scope** (not in Appendix A). All in-scope code was sourced from the two repositories above and matched against deployed bytecode.

**PoC status:** 3 of 3 core findings have **passing Foundry local-fork tests** (`forge test`, pinned blocks, unprivileged attacker, loss assertions). PoC source: `/tmp/opencode/mor-poc/{test/MorCapitalPoC.t.sol, test/LumerinSessionPoC.t.sol}` (to be published as a public repo/gist at submission time — program requires a public link).

---

## 1. Deployment mapping (source → deployed address, chain)

ERC1967 implementation slots read on-chain 2026-11-01; source matching via Sourcify v2 (`exact_match`/`match`) and direct compilation.

### Ethereum Mainnet — Capital

| Appendix A address | Type | Implementation (ERC1967 slot) | Verified source | Match status |
|---|---|---|---|---|
| MOR token `0xcBB8f1BDA10b9696c57E13BC128Fe674769DCEc0` | token | n/a | `contracts/MOROFT.sol:MOROFT` | Sourcify **exact_match** |
| DepositPool (stETH) `0x47176B2Af9885dC6C4575d4eFd63895f7Aaa4790` | ERC1967 | `0xdB10dAEF167eA2233Ba6811457dD24D676FbD670` | `contracts/capital-protocol/DepositPool.sol` (libs ReferrerLib `0x9a397c63…`, LockMultiplierMath `0x345B8B23…`) | Sourcify **match** |
| DepositPool (wETH) `0x9380d72aBbD6e0Cc45095A2Ef8c2CA87d77Cb384` | ERC1967 | same impl `0xdB10dAEF…` | same | same |
| DepositPool (wBTC) `0xdE283F8309Fd1AA46c95d299f6B8310716277A42` | ERC1967 | same impl | same | same |
| DepositPool (USDC) `0x6cCE082851Add4c535352f596662521B4De4750E` | ERC1967 | same impl | same | same |
| DepositPool (USDT) `0x3B51989212BEdaB926794D6bf8e9E991218cf116` | ERC1967 | same impl | same | same |
| Distributor `0xDf1AC1AC255d91F5f4B1E3B4Aef57c5350F64C7A` | ERC1967 | `0x52f76e8be3dfabcc3b0ded02882a22be47dade03` | `contracts/capital-protocol/DistributorV2.sol` | Sourcify **exact_match** |
| RewardPool `0xb7994dE339AEe515C9b2792831CD83f3C9D8df87` | ERC1967 | `0xe30279b79392AEfF7fDf1883C23d52eBA9D88A75` | `contracts/capital-protocol/RewardPool.sol` (lib LinearDistributionIntervalDecrease `0xfb1a7d49…`) | Sourcify **match** |
| ChainLinkDataConsumer `0xd182263D06Fdc463c96190005d6359Cc3d3BbC5E` | ERC1967 | `0x94e6720a624ea275b44d357a7f21bfcf09ff7e11` | `contracts/capital-protocol/ChainLinkDataConsumer.sol` | Sourcify **exact_match** |
| L1SenderV2 `0x2Efd4430489e1a05A89c2f51811aC661B7E5FF84` | ERC1967 | `0x50e80ea310269c547b64cc8b8a606be0ec467d1f` | `contracts/capital-protocol/L1SenderV2.sol` | Sourcify **exact_match** |

### Arbitrum One — cross-chain

| Appendix A address | Type | Implementation | Verified source | Match |
|---|---|---|---|---|
| MOR `0x092bAaDB7DEf4C3981454dD9c0A0D7FF07bCFc86` | token | n/a | `MOROFT.sol` | **exact_match** |
| L2MessageReceiver `0xd4a8ECcBe696295e68572A98b1aA70Aa9277d427` | ERC1967 | `0x2efd4430489e1a05a89c2f51811ac661b7e5ff84` | `contracts/L2MessageReceiver.sol` | **exact_match** |
| L2TokenReceiverV2 `0x47176b2af9885dc6c4575d4efd63895f7aaa4790` | ERC1967 | `0x27353ffadfd53538e8bdf81be7041c56ce2d5ae4` | `contracts/L2TokenReceiverV2.sol` | **exact_match** |

### Base — token / Builders

| Appendix A address | Type | Implementation | Verified source | Match |
|---|---|---|---|---|
| MOROFT `0x7431aDa8a591C955a994a21710752EF9b882b8e3` | token | n/a | `MOROFT.sol` | **exact_match** |
| BuildersV4 `0x42BB446eAE6dca7723a9eBdb81EA88aFe77eF4B9` | ERC1967 | `0x18faef315b40a6d9cf49628f1133b1aa507513b0` | `contracts/builder-protocol/BuildersV4.sol` | **exact_match** |
| BuildersTreasuryV2 `0x9eba628581896ce086cb8f1A513ea6097A8FC561` | ERC1967 | `0xe71eb0b69bbd4207e2cb10df929d1311d2ad57e5` | `contracts/builder-protocol/BuildersTreasuryV2.sol` | **exact_match** |
| RewardPool (Builders) `0xDC99a8596e395E52aba2BD08C623E1e428Dc3980` | ERC1967 | `0x4de9d52a6a951c2dc7b22805eeec2bc41404909d` | `contracts/RewardPool.sol` (lib `0x2265ae41…`) | **match** |
| FeeConfig `0x845FBB4B3e2207BF03087b8B94D2430AB11088eE` | ERC1967 | `0x2e1ff173085a5ef12046c27e442f12f79a0092b7` | `contracts/FeeConfig.sol` | **exact_match** |
| LinearDistributionIntervalDecrease `0x2265ae4127a49218c1C562Cb16822971f295Ed50` | library | n/a | `contracts/libs/LinearDistributionIntervalDecrease.sol` | **exact_match** |

### Base — Inference marketplace (EIP-2535 diamond `0x6aBE1d282f72B474E54527D93b979A4f64d3030a`)

| Facet (in scope through the diamond) | Address | Verified source | Match |
|---|---|---|---|
| LumerinDiamond | `0x6aBE1d282f72B474E54527D93b979A4f64d3030a` | `contracts/diamond/LumerinDiamond.sol` (0.8.24) | **exact_match** |
| ProviderRegistry | `0xE30279b79392AEfF7fDf1883C23d52eBA9D88A75` | `diamond/facets/ProviderRegistry.sol` | **exact_match**, repo file byte-identical |
| ModelRegistry | `0xb7994dE339AEe515C9b2792831CD83f3C9D8df87` | `diamond/facets/ModelRegistry.sol` | **exact_match**, byte-identical |
| Marketplace | `0x5B660aB78f3AC743953F9E68630A2D66e7b45F64` | `diamond/facets/Marketplace.sol` | **exact_match**, byte-identical |
| Delegation | `0x345B8B23c38F70f1d77560C60493Bb583f012Cb0` | `diamond/facets/Delegation.sol` | **exact_match**, byte-identical |
| SessionRouter | `0x3a3952F0e57B343F00B31f7da039Ef16389B7260` | `diamond/facets/SessionRouter.sol` @ deploy-era code (PR #830, `214024e`/`e3dff9d`) | **Strong behavioral match** (see below); Sourcify unverified; byte-metadata match not completed |

**SessionRouter matching note (honesty requirement):** the deployed facet is not on Sourcify. Its runtime bytecode (solc 0.8.24, paris, runs 200, ipfs metadata — same settings as the 4 exact-matched sibling facets) embeds metadata hash `5fc3266b5582f7e5909db89644902e60ea73210d3ee8bbf85ca9f393fdb6e90c`. My rebuild of the repo source at the deploy-era commit reproduces the exact ABI and semantics (see F-3 PoC, which exercises the deployed facet directly on a Base fork and reproduces the PR-#830 day-lock behavior that distinguishes the deployed version from its predecessor), but the metadata hash differs (`86636926…`) due to a dependency-content sub-version drift inside the `@solarity/solidity-lib` closure. Before submission, re-run the match with the deploy lockfile, or request the team's verified source. All F-3 exploitation calls target the **deployed facet through the diamond** and do not depend on the unmatched file contents.

**Notable deployment facts:** the five DepositPool proxies share one implementation (0xdB10dAEF…); CREATE2 address reuse across chains (e.g., Arbitrum L2TokenReceiverV2 == mainnet DepositPool-stETH address); the deployed Distributor v7 already contains fixes for C4 M-02 (balance-delta accounting in `supply`), M-03 (dynamic `getPool()`), and M-04 (yield loop before the `rewards_ == 0` return) — those C4 issues are **not** present in the deployed bytecode.

---

## 2. Trust boundaries

| Boundary | Who | Capability |
|---|---|---|
| TB-1 Users | anyone | stake/withdraw/claim on DepositPools (public reward pool 0), open/close sessions, register providers/models/bids on the diamond |
| TB-2 Owner multisig `0x1FE04BC1…` (owner of all UUPS proxies) | privileged | upgrades, add deposit pools, referrer tiers, Aave/Chainlink/LZ config. **Out of scope per program (admin-key findings excluded).** |
| TB-3 `networkShareOwner`, `claimAdmin`, subnet admins (Builders) | privileged | reward-share/claim routing. Out of scope. |
| TB-4 Chainlink feeds | oracle | price inputs for reward weighting (staleness-checked in ChainLinkDataConsumer) |
| TB-5 Aave v3 / Lido | external yield source | aToken balances & stETH rebase define "yield" in DistributorV2 |
| TB-6 LayerZero v1 + Arbitrum bridge | message/asset transport | MOR mint messages (L1SenderV2 → L2MessageReceiver.mint) |
| TB-7 `fundingAccount 0x5160C0311A95E0A1072FA85Df23712A7BA1cD4b1` | marketplace compute budget | pays providers in `SessionRouter._claimForProvider`; holds 87,079 MOR (~$74.5k) |

## 3. Invariants (as designed)

1. **INV-1 (emission conservation):** per distribution period, Σ rewards allocated to DepositPools ≤ `RewardPool.getPeriodRewards`; per pool, stakers' + referrers' claimable ≤ allocated (rate-index accounting on `virtualDeposited`).
2. **INV-2 (yield proportionality):** a DepositPool's share of the MOR emission is proportional to the **real yield its staked capital generated** during the period (`yields_[i] × rewards_ / totalYield_`).
3. **INV-3 (stake redemption):** user principal is always withdrawable (subject to configured locks); rewards accrue only on `virtualDeposited` weights (lock multiplier ≤ 10.7×, referral bonus 1%, referrer tiers 3–15% of referred stake).
4. **INV-4 (marketplace solvency):** Σ payouts from `fundingAccount` ≤ budget, and each provider's claims ≤ `provider.stake` per 365-day limiter period.
5. **INV-5 (mint authorization):** MOR is minted only against `L1SenderV2.sendMintMessage` (gated to the Distributor, which is gated to registered DepositPools) or OFT transfers.

---

## 4. Findings

### F-1 — Yield-donation buys MOR emission share (cross-pool reward theft) — **HIGH candidate**

* **Where:** `DistributorV2.sol` lines 397–442 (deployed impl `0x52f76e8b…`, proxy `0xDf1AC1AC…`): `uint256 balance_ = IERC20(yieldToken_).balanceOf(address(this)); … underlyingYield_ = (balance_ - depositPool.lastUnderlyingBalance).to18(decimals_); uint256 yield_ = underlyingYield_ * depositPool.tokenPrice;` then `distributedRewards[i] += (yields_[i] * rewards_) / totalYield_;`.
* **Bug:** "Yield" is measured as the raw token/aToken balance delta of the Distributor. **Anyone can manufacture yield** by transferring the pool's yield token (aToken for AAVE pools; the token itself for the stETH/NONE pool) directly to the Distributor. The donation is one-shot consumed as period yield and buys the donor's pool a share of the MOR emission **proportional to the donation instead of organic yield**, stealing from all other pools' stakers.
* **Exploit scenario (unprivileged, repeatable daily):**
  1. Attacker deposits into the pool with the lowest organic yield (currently USDT pool, TVL $4.7k) to become its dominant reward earner.
  2. Attacker converts cash to that pool's yield token (aUSDT via Aave `supply`) and transfers $D of it straight to the Distributor.
  3. Attacker calls `distributeRewards(0)` (public) at the next distribution boundary (≥ `minRewardsDistributePeriod` = 24 h). The pool's measured yield jumps by $D; it receives `rewards × (Y_i+D)/(Y+D)` instead of `rewards × Y_i/Y`.
  4. Attacker claims the inflated MOR (14-day claim lock) and withdraws principal (7-day withdraw lock). Only the donation is a real cost; it is swept to the treasury as "yield".
* **Impact (measured at pinned block 26,321,432, MOR $0.856, prices read on-chain):** daily emission of public pool 0 = 2,865.68 MOR ≈ **$2,454/day**; steady-state organic yield of the 5 pools ≈ **$940/day** (stETH 4,839 @ ~3% APR ≈ $900, USDC $36, wETH $1, wBTC/USDT <$1). Since emission value > yield value, donations are profitable at the margin: PoC run (500k USDT dominant stake, $300 donation) yields **381.14 MOR ($326) of over-accrual for a $300 cost (net +$26/period)** and **drains 32.48 MOR ($27.8)/period from a comparable honest 1,000-stETH staker**. Scaling: over-accrual ≈ `attackerShare × R×D/(Y+D)`; with a dominant stake and optimal `D* ≈ √(R·Y)−Y ≈ $550`, attacker-side extraction approaches **$100–300/day (~$35–110k/yr)** while honest stETH/WETH/WBTC/USDC providers collectively lose the same. Funds at risk scale with the emission stream (~$2.4k/day, ~$900k/yr).
* **PoC status:** **VERIFIED** — `test_PoC_YieldDonation_StealsEmissionShare` (Foundry, `vm.createSelectFork(ETH_RPC_URL, 26321432)`, run A/B via `snapshotState/revertToState`, asserts attacker over-accrual > donation cost AND victim dilution > 0). Oracle heartbeat and one day of organic yield are simulated identically in both runs (frozen fork cannot accrue Aave/Lido yield); no privileged pranks.
* **Chainability:** chains with F-2 (self-referral raises attackerShare inside the inflated pool) and with the stETH-pool donation variant (stETH is its own yield token — cheapest donation path).
* **De-dup risk (be honest):** Code4rena 2025-08 (LOW-01) publicly disclosed that donations count as yield and can "force the distributor to mint MOR … in a period of no new generated yield" (the `totalYield_ == 0` branch). The **profitable cross-pool re-weighting** of this report (the `yields_[i]/totalYield_` branch, net-profit economics, victim accounting) is not in that report or in any public audit found. Root cause adjacency may still trigger a "known" close; the submission should pre-empt this by quoting LOW-01 and differentiating the impact.
* **Severity/payout estimate:** program tier High ("measurable over-issuance of rewards") — **$10,000–$50,000 tier; realistic $10k–$25k** given the dedup risk. Fix: measure yield as `min(balance, debt-scaled)` accrual, or weight by `aToken` index growth of tracked positions instead of raw balance deltas; ignore unsolicited balances.

---

### F-2 — Self-referral: any staker earns +16% extra emission weight on their own deposit — **MEDIUM/HIGH candidate**

* **Where:** `DepositPool.sol` lines 251–259 (`stake` takes an arbitrary `referrer_`), 350–421 (`_stake`), 605–661 (`_applyReferrerTier` — no `referrer_ != user_` check anywhere), `ReferrerLib.sol` lines 30–45 (`applyReferrerTier` credits `amountStaked` to the referrer), `ReferrerLib.getReferralMultiplier` (flat +1% for any non-zero referrer). On-chain tiers (stETH pool proxy, `referrerTiers(0,i)`): ≥1 → 3%, ≥2.5 → 5%, ≥25 → 10%, **≥62.5 → 15%** (multiplier scale 1e25).
* **Bug:** `stake(pool, amount, lockEnd, referrer_ = user)` registers the user's own deposit as "referred stake" of themselves. The user simultaneously earns (a) the +1% referral weight on their staker position and (b) the full referrer tier weight (15% at ≥62.5 tokens) on the same deposit via `claimReferrerTier`, with zero cost and no new capital brought in.
* **Exploit scenario:** stake ≥62.5 stETH (or wETH) with `referrer = self`; claim both user and referrer reward streams. Repeat across wallets; combine with max lock multiplier (10.7×) per risk appetite.
* **Impact (measured, pinned block, one distribution period, identical 1,000 stETH stakes):** self-referrer earned **233.95 MOR vs 201.69 MOR** for the honest staker = **+15.99%** (≈ +32.27 MOR ≈ $27.6 per 1,000 stETH per day). Scales linearly: 5,000 stETH self-referred ≈ +100 MOR/day (~$31k/yr) at current state; theoretical ceiling ≈ 16% of the stETH pool's ~2,400 MOR/day allocation if the attacker supplies most of the pool weight (~$330/day). Victims: all other stakers in the shared reward pool (dilution of exactly the over-issued amount — PoC measures both sides).
* **PoC status:** **VERIFIED** — `test_PoC_SelfReferral_MintsExtraRewards` (asserts own-deposit referrer record `amountStaked == stake`, `virtualStaked == 15% × stake`, and uplift ≥ 15%).
* **Chainability:** F-1 × F-2 (self-referral raises the attacker's share of the donation-inflated pool) — combined uplift ≈ +16% share on stolen emissions. Also combinable with lock-multiplier optimization.
* **De-dup risk:** not in the C4 2025-08 report (checked all 4 MEDIUMs + published LOWs). The 2024 "Distribution V5 (Referral Program)" audit PDF could not be machine-read (text extraction failed); if it already flagged self-referral the report will close as known. Recommend the submission quotes this uncertainty.
* **Severity/payout estimate:** program High language ("measurable over-issuance of rewards") fits; bounded and modest → likely placed Medium. **Estimate $2,500–$10,000** (Medium), upside $10k if judged High. Fix: `require(referrer_ != user_)` in `_stake`, and/or exclude self-referrals from tier accrual.

---

### F-3 — Fabricated sessions drain the marketplace `fundingAccount` (self-dealing provider/consumer) — **HIGH candidate**

* **Where:** `SessionRouter.sol` (deployed facet `0x3a3952F0e57B343F00b31F7dA039Ef16389B7260` through diamond `0x6aBE1d282f72B474E54527D93b979A4f64d3030a`): `openSession` (83–123) accepts any user-signed-by-provider approval; `closeSession` (211–234) accepts a provider-signed receipt; `_claimForProvider` (374–403) pays `pricePerSecond × duration` from `fundingAccount` with no service attestation; `stakeToStipend` (183–190) converts user stake to payout at the fixed rate `computeBalance/(totalMORSupply×100)`.
* **Bug:** a single address can be both consumer and provider (both registration paths are permissionless and stake-gated only). It self-signs the provider approval and closeout receipt, opens a session with itself, closes it, and collects MOR from the compute budget without serving any inference. The user-side stake is fully recoverable (day-hold recycle via `withdrawUserStakes`, or immediate return on late close), so the attack is collateral-free beyond a ~1-day hold.
* **Exploit scenario (unprivileged):** register provider (stake S) + model + bid; `openSession(self, S_user, false, approval-self-signed)`; warp to `endsAt`; `closeSession(self-signed receipt)` → `fundingAccount` pays `stakeToStipend(S_user)` (≈ 0.292% of the recycled stake); next day `withdrawUserStakes` recycles the stake; repeat.
* **Impact (measured, pinned Base block 53,383,498):** one fabricated 1-hour session on a 10,000 MOR recycled stake extracted **29.207 MOR (~$25)** from `fundingAccount`; stake fully recovered (assert passes). Cycle economics: extraction = `stakeToStipend(stake)` per session regardless of duration, with stake recycled daily → ~106%/yr on recycled stake, **capped only by `PROVIDER_REWARD_LIMITER_PERIOD` (365 days) at `provider.stake`/year ≈ 100% APR conversion of MOR stake into treasury drain**. `fundingAccount` currently holds **87,079 MOR ≈ $74.5k** (read at fork block); an attacker staking 87k MOR (~$74.5k, recoverable) can drain the full budget within a year; parallel provider addresses raise throughput.
* **PoC status:** **VERIFIED** — `test_PoC_FabricatedSession_DrainsFundingAccount` (Foundry, `vm.createSelectFork(BASE_RPC_URL, 53383498)`; asserts `fundingAccount` delta > 0 and equals attacker profit while the full stake is recovered). No privileged pranks; signatures produced with `vm.sign` on the attacker's own key.
* **Design-intent caveat (be honest):** the marketplace has no on-chain proof-of-inference; the team may argue sessions are policed off-chain (consumer honesty, ratings, TEE attestation). Counter-argument: the program pays for "measurable loss of funds" caused by an unprivileged actor — here the loss is a direct treasury (`fundingAccount`) transfer and the 365-day stake-proportional limiter shows fabricated-claim throttling was anticipated but not prevented.
* **Chainability:** stack N provider addresses for throughput; chains with F-1/F-2 economically (both convert MOR positions into emission/treasury extraction).
* **De-dup risk:** the publicly known Lumerin issue (`withdrawUserStakes` selector missing, GitHub issue #62) is different and excluded as known. The self-dealing drain is not publicly disclosed as far as searched.
* **Severity/payout estimate:** "theft of treasury assets" → Critical language, but impact is bounded by attacker stake and the $74.5k budget → realistically **High $10,000–$50,000; realistic $10k–$30k**. Fix: require the consumer signature to come from an address ≠ provider (and not delegated to it), and/or exclude provider-owned consumer sessions from budget payouts.

---

### F-4 — Forced claim destroys a staker's lock multiplier permanently (griefing) — **LOW/MEDIUM candidate**

* **Where:** `DepositPool.sol` 284–292 (`claimFor`: if `claimReceiver[pool][staker] != 0`, **any caller** may trigger the claim), `_claim` 505–566 (resets `claimLockStart/End = 0`, recomputes `virtualDeposited` with multiplier from (0,0) → drops the up-to-10.7× lock weight to ~1.01×).
* **Bug/impact:** once a staker sets `claimReceiver` (the DistributionV6 "claim on behalf" feature) and their claim locks expire, anyone can force a claim and permanently reduce the victim's earning weight (e.g., 10.7× → 1.01×, a ~90% reduction of their emission share) because re-locking later computes `getLockPeriodMultiplier(now, end)` on the saturating tanh curve, which can never restore the original window's multiplier. The rewards themselves are not stolen (they go to the designated receiver).
* **PoC status:** **LIKELY (logic-verified, no PoC run)** — chainable with a per-victim quantification (victim share loss × daily emission) if pursued.
* **Severity/payout estimate:** griefing with quantified cost, but requires the victim to have opted into `claimReceiver`; the program excludes "griefing that does not result in permanent loss" while listing "quantified loss to a subset of users" as Medium. **Estimate $500–$2,500 (Low)** or closed as design. Fix: require the caller to be the staker or an authorized `claimSender` even when `claimReceiver` is set.

---

### Known-adjacent / excluded (documented for completeness)

* **Oracle staleness freezes all capital pools** (`updateDepositTokensPrices` `require(price_ > 0)` + `distributeRewards` reverting on stale feeds → `stake/withdraw/claim` DoS while any of the 6 feeds exceeds its `allowedPriceUpdateDelay`): C4 M-01 adjacency (shared heartbeat) — excluded as known + DoS-without-loss.
* **LibSD int64 overflow in stats via provider-signed receipts** (`LibSD.add` TODO: underflow; `_setStats` runs in `closeSession`): a malicious provider can poison `modelStats` and revert clean closes for a model (disputed closes still work) → griefing, excluded.
* **Emissions while `totalVirtualDeposited == 0` are burned** (DepositPool `_getCurrentPoolRate` marks them distributed) and **BuildersV4 `undistributedRewards` is never claimable** — accounting oddities, no attacker profit.
* C4 M-02/M-03/M-04 — fixed in the deployed v7 code (verified in deployed sources).

---

## 5. PoC run instructions

```bash
git clone <this-poc-repo> && cd <this-poc-repo>
export ETH_RPC_URL=<archive RPC, e.g. https://eth.drpc.org>
export BASE_RPC_URL=<base RPC, e.g. https://base.publicnode.com>
forge test -vv
# 5 passed (incl. scaffolding): PoC1 self-referral, PoC2 yield-donation, PoC3 fabricated session
```

Pinned blocks: Ethereum **26,321,432**, Base **53,383,498**. Attacker = fresh address (`vm.addr(0xA11CE)`), no `vm.prank` of owner/admin/multisig anywhere. Fork-environment simulation only: (a) Chainlink `latestRoundData` mocked with real answers + fresh `updatedAt` (feeds are frozen on a fork; production heartbeats update them), (b) one day of organic Aave/Lido yield credited identically to both compared runs.

## 6. Summary table

| # | Finding | Target (Appendix A) | Severity (self) | PoC | Est. payout |
|---|---|---|---|---|---|
| F-1 | Yield-donation buys emission share (cross-pool reward theft, ~$100–300/day at optimal play; $2.4k/day emission at risk) | Distributor `0xDf1AC1AC…` (impl 0x52f76e8b…) | High | VERIFIED (fork) | $10k–$25k (dedup risk w/ C4 LOW-01) |
| F-2 | Self-referral +16% reward weight (measured +15.99%) | 5 DepositPools (impl 0xdB10dAEF…) | Medium–High | VERIFIED (fork) | $2.5k–$10k |
| F-3 | Fabricated sessions drain fundingAccount (~100%/yr of stake; $74.5k budget) | LumerinDiamond `0x6aBE1d28…` / SessionRouter | High | VERIFIED (fork) | $10k–$30k (design-intent risk) |
| F-4 | Forced-claim multiplier destruction (griefing) | DepositPools | Low | LIKELY (logic) | $0.5k–$2.5k |

**Chain potential:** F-1×F-2 compound (self-referral increases the share of donation-stolen emissions); F-1 and F-3 both convert attacker capital into protocol-value extraction at positive expected value at current on-chain parameters.

**Honest confidence statement:** F-1/F-2/F-3 mechanics and loss figures are reproduced by passing fork tests with on-chain state; the two residual risks are (a) program-side de-duplication judgments (C4 LOW-01 adjacency for F-1; unreadable V5 referral audit for F-2) and (b) the design-intent argument for F-3. SessionRouter byte-level source match is strongly supported (deployed behavior + 4/5 sibling facets byte-exact) but not completed.

---

# Pass 2 addendum (2026-11-02)

Second-pass review covering the Builder protocol, cross-chain contracts (L1SenderV2/L2MessageReceiver/L2TokenReceiverV2/MOROFT), ChainLinkDataConsumer, RewardPool curve math, plus adversarial red-teaming of F-1/F-3. Note: the public SmartContracts repo tops out at Builders **V3**; the BuildersV4 analysis below uses the Sourcify-matched deployed source.

## P2-1 — BuildersV4 subnet front-running → emission capture — **VERIFIED (fork PoC)**

`createSubnet(Subnet,SubnetMetadata)` (BuildersV4.sol:194-217) is unpermissioned — `_validateSubnet` (:243-251) has no `admin == msg.sender` check — and `subnetCreationFeeAmount() == 0` live (FeeConfig), so subnet creation is free. An attacker front- registers a subnet name a victim intends to use; the victim stakes via the normal `deposit()` flow (:280-297); each subnet's reward share is weighted by `subnetsData[id].deposited` (:361-413); `claim(bytes32,address)` (:326-352) pays ALL pending subnet rewards to the subnet admin/claimAdmin (FEE_CLAIM_OPERATION fee == 0 live).

**Measured (Base fork @ block 53,418,336):** zero-MOR attacker registers "PrettyLegitSubnet"; victim deposits 10,000 MOR; one day later attacker's `claim` receives **7.807 MOR — 100% of the victim-generated emission** (matches `getCurrentSubnetRewards` and closed-form curve math to 0.01%). ≈0.78 MOR/day per 10k MOR victim stake (80% networkShare × stake share of live ~2.93M MOR totalDeposited). Victim principal intact (7-day lock) — reward-stream capture only.
**PoC:** `test/BuildersSubnetFrontrun.t.sol` — `test_SubnetFrontrun_CapturesVictimEmission` (passes; no privileged pranks).
**Fix:** gate `createSubnet` on `admin == msg.sender` (or signature), and/or set `subnetCreationFeeAmount > 0` so name-squatting carries real cost.

## P2-2 — ChainLinkDataConsumer multi-feed `res_ == 0` sentinel (Info)

The zero sentinel for "feed not set" can in principle re-base on a feed that legitimately returns 0; unreachable with the live wBTC (BTC,BTC/USD) configuration. Informational only.

## P2-3 — DistributorV2 unbounded Arbitrum mint delegation (Info, defense-in-depth)

DistributorV2.sol:496-506 delegates unbounded MOR minting on Arbitrum to every owner-registered pool (one hop from critical if any pool registration becomes attacker-influenced). Defense-in-depth note only — owner is a trusted role.

## Red-team verification of F-1 and F-3 (strengthens the originals)

- **F-1:** the donation is fully recoverable (NONE-pool surplus swept via transfer, DistributorV2.sol:532-538; AAVE-pool aTokens withdrawn via pool, :523-531) and there is no self-counting — `supply()` measures the yield-token balance BEFORE the stake transfer is pulled in (:290-297 vs :411-416), so the attacker's own stake never contaminates the measured yield delta. No counterargument survived.
- **F-3:** nothing on-chain binds consumer ≠ provider — `_extractProviderApproval` (SessionRouter.sol:193-196) decodes the consumer address from the provider-signed approval and DISCARDS it; `_isValidProviderReceipt` (:537-560) authenticates the provider only. The self-dealing loop is fully reachable on deployed bytecode.

## Verified-no-bug notes (recorded to save reviewers time)

- LZ v1 packet forgery impossible: packet `srcAddress` is the DVN-proven `msg.sender` of `Endpoint.send`; app check (`sender == L1SenderV2`) sound; gateway config matches official LZ tables; Arbitrum supply ≈ emission curve.
- MOROFT peer wiring complete on all three chains (an earlier "unset peer" observation was a wrong-EID artifact).
- RewardPool/LinearDistributionIntervalDecrease curve math: 140k-window property test vs exact integral — zero over-issuance/superadditivity; all rounding floors.
- BuildersV4 rate accounting conserves rewards exactly under the deposit/claim flows exercised; no donation vector found beyond P2-1.
