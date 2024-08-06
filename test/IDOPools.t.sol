// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../src/mock/MockERC20.sol";
import "./helpers/TestStandardIDOPool.sol";

contract IDOPoolTest is Test {
    TestStandardIDOPool ido;
    MockERC20 idoToken;
    MockERC20 buyToken;
    MockERC20 fyToken;

    error NotStarted();
    error IDONotEnded();

    address deployer;
    address user1 = address(1);
    address user2 = address(2);
    address user3 = address(3);
    address user4 = address(4);
    uint256 idoPrice = 1 ether;
    uint256 idoSize = 1_000_000 ether;
    uint256 minimumFundingGoal = 500_000 ether;
    uint16 fyTokenMaxBasisPoints = 5000; // 50%
    uint64 idoStartTime;
    uint64 idoEndTime;
    uint64 claimableTime;

    function setUp() public {
        deployer = address(0x1);
        idoToken = new MockERC20("IDO Token", "IDOT");
        buyToken = new MockERC20("Buy Token", "BUY");
        fyToken = new MockERC20("FY Token", "FY");

        idoStartTime = uint64(block.timestamp + 1 days);
        idoEndTime = idoStartTime + 1 weeks;
        claimableTime = idoEndTime + 1 days;

        // Deploy TestStandardIDOPool contract
        vm.startPrank(deployer);
        ido = new TestStandardIDOPool();
        ido.init(deployer, deployer);
        vm.stopPrank();

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(user4, 10 ether);
    }

    function _verifyIDORoundConfig(uint32 newIdoRoundId) internal view {
        (
            address _idoToken,
            uint8 _idoTokenDecimals,
            uint16 _fyTokenMaxBasisPoints,
            address _buyToken,
            address _fyToken
        ) = ido.getIDORoundConfigPart1(newIdoRoundId);

        assertEq(_idoToken, address(idoToken), "IDO token address mismatch");
        assertEq(_buyToken, address(buyToken), "Buy token address mismatch");
        assertEq(_fyToken, address(fyToken), "FY token address mismatch");
        assertEq(
            _fyTokenMaxBasisPoints,
            fyTokenMaxBasisPoints,
            "FY token max basis points mismatch"
        );
        assertEq(
            _idoTokenDecimals,
            idoToken.decimals(),
            "IDO token decimals mismatch"
        );

        (
            uint256 _idoPrice,
            uint256 _idoSize,
            uint256 _idoTokensSold,
            uint256 _minimumFundingGoal,
            uint256 _fundedUSDValue
        ) = ido.getIDORoundConfigPart2(newIdoRoundId);

        assertEq(_idoPrice, idoPrice, "IDO price mismatch");
        assertEq(_idoSize, idoSize, "IDO size mismatch");
        assertEq(_idoTokensSold, 0, "IDO tokens sold should be 0");
        assertEq(
            _minimumFundingGoal,
            minimumFundingGoal,
            "Minimum funding goal mismatch"
        );
        assertEq(_fundedUSDValue, 0, "Funded USD value should be 0");
    }

    function _verifyMetaIDOCreation(
        uint32 initialIdoRoundId,
        uint32 metaIdoId
    ) internal view {
        // Confirm that round is enabled
        (, , , , , , , bool isEnabled, , ) = ido.getIDORoundClock(
            initialIdoRoundId
        );
        assertTrue(isEnabled, "Round not enabled correctly");

        // Check MetaIDO variables
        (
            uint64 registrationStartTime,
            uint64 initialRegistrationEndTime,
            uint64 registrationEndTime
        ) = ido.getMetaIDOInfo(metaIdoId);

        assertEq(
            registrationStartTime,
            uint64(block.timestamp),
            "Registration start time mismatch"
        );
        assertEq(
            registrationEndTime,
            uint64(block.timestamp + 12 hours),
            "Registration end time mismatch"
        );
        assertEq(
            initialRegistrationEndTime,
            registrationEndTime,
            "Initial registration end time mismatch"
        );

        uint32[] memory metaIDORounds = ido.getMetaIDORoundIds(metaIdoId);
        assertEq(metaIDORounds.length, 1, "MetaIDO should have 1 round");
        assertEq(
            metaIDORounds[0],
            initialIdoRoundId,
            "MetaIDO round ID mismatch"
        );
    }

    function test_CreateNewIDO() public {
        vm.startPrank(deployer);

        uint32 initialIdoRoundId = ido.nextIdoRoundId();

        ido.createIDORound(
            "Test IDO", // IDO name
            address(idoToken),
            address(buyToken),
            address(fyToken),
            idoPrice,
            idoSize,
            minimumFundingGoal,
            fyTokenMaxBasisPoints,
            idoStartTime,
            idoEndTime,
            claimableTime
        );

        vm.stopPrank();

        uint32 newIdoRoundId = initialIdoRoundId;

        // Verify the IDO was created correctly
        assertEq(
            ido.nextIdoRoundId(),
            initialIdoRoundId + 1,
            "IDO Round ID not incremented correctly"
        );

        // Check IDORoundClock
        (
            uint64 _idoStartTime,
            uint64 _claimableTime,
            uint64 _initialClaimableTime,
            uint64 _idoEndTime,
            uint64 _initialIdoEndTime,
            bool _isFinalized,
            bool _isCanceled,
            bool _isEnabled,
            bool _hasNoRegList,

        ) = ido.getIDORoundClock(newIdoRoundId);

        assertEq(_idoStartTime, idoStartTime, "IDO start time mismatch");
        assertEq(_idoEndTime, idoEndTime, "IDO end time mismatch");
        assertEq(_claimableTime, claimableTime, "Claimable time mismatch");
        assertEq(
            _initialClaimableTime,
            claimableTime,
            "Initial claimable time mismatch"
        );
        assertEq(
            _initialIdoEndTime,
            idoEndTime,
            "Initial IDO end time mismatch"
        );
        assertFalse(_isFinalized, "IDO should not be finalized");
        assertFalse(_isCanceled, "IDO should not be cancelled");
        assertFalse(_hasNoRegList, "IDO should not have a reg list");
        assertFalse(_isEnabled, "IDO should not be enabled initially");

        // Check IDORoundConfig
        _verifyIDORoundConfig(newIdoRoundId);

        uint32 metaIdoId = ido.nextMetaIdoId();
        uint32[] memory rounds = new uint32[](1);
        rounds[0] = initialIdoRoundId;

        // Send tokens to IDO contract and enable IDO round
        vm.startPrank(deployer);
        idoToken.mint(address(ido), idoSize);
        ido.enableIDORound(initialIdoRoundId);
        ido.createMetaIDO(
            rounds,
            uint64(block.timestamp),
            uint64(block.timestamp + 12 hours)
        );
        vm.stopPrank();

        _verifyMetaIDOCreation(initialIdoRoundId, metaIdoId);
    }

    function test_Participate() public {
        vm.startPrank(deployer);

        uint32 initialIdoRoundId = ido.nextIdoRoundId();

        ido.createIDORound(
            "Test IDO", // IDO name
            address(idoToken),
            address(buyToken),
            address(fyToken),
            idoPrice,
            idoSize,
            minimumFundingGoal,
            fyTokenMaxBasisPoints,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 7 days),
            uint64(block.timestamp + 8 days)
        );

        // Create META IDO
        uint32[] memory rounds = new uint32[](1);
        rounds[0] = initialIdoRoundId;
        ido.createMetaIDO(
            rounds,
            uint64(block.timestamp),
            uint64(block.timestamp + 12 hours)
        );

        // Mint tokens to IDO
        idoToken.mint(address(ido), idoSize);

        //Enable Round and Whitelist
        ido.enableIDORound(initialIdoRoundId);
        //ido.enableHasNoRegList(initialIdoRoundId);

        // Mint buy token to user
        buyToken.mint(user1, 1_000_000 ether);

        vm.stopPrank();

        uint32 newIdoRoundId = initialIdoRoundId;

        vm.startPrank(user1);
        // Reverts because user isnt registered
        buyToken.approve(address(ido), 1_000_000 ether);
        vm.expectRevert(NotStarted.selector);

        ido.participateInRound(
            newIdoRoundId,
            address(buyToken),
            1_000_000 ether
        );
        // User Registers
        ido.registerForMetaIDO(newIdoRoundId);
        assertTrue(ido.isRegisteredForMetaIDO(newIdoRoundId, user1));

        // Fast forward 1 day to ido start time
        vm.warp(block.timestamp + 1 days);
        // Approve and Participate
        buyToken.approve(address(ido), 1_000_000 ether);
        ido.participateInRound(
            newIdoRoundId,
            address(buyToken),
            1_000_000 ether
        );

        assert(
            ido.getTotalFunded(newIdoRoundId, address(buyToken)) ==
                1000000 ether
        );

        vm.stopPrank();

        vm.warp(block.timestamp + 5 days);

        // ROUND IS FINALIZED
        vm.startPrank(deployer);
        // reverts if finalized attempted before ending
        vm.expectRevert(IDONotEnded.selector);
        ido.finalizeRound(newIdoRoundId);

        // SUCCESSFULL FINALIZATION
        vm.warp(block.timestamp + 2 days);
        ido.finalizeRound(newIdoRoundId);
        vm.stopPrank();

        // USER CLAIMS
        vm.startPrank(user1);
        uint256 idoTokenStart = idoToken.balanceOf(user1);
        ido.claimFromRound(newIdoRoundId, user1);
        uint256 idoTokenEnd = idoToken.balanceOf(user1);
        assertGt(idoTokenEnd, idoTokenStart);
        vm.stopPrank();
    }

    function test_Many_Participate() public {
        vm.startPrank(deployer);

        uint32 initialIdoRoundId = ido.nextIdoRoundId();

        ido.createIDORound(
            "Test IDO", // IDO name
            address(idoToken),
            address(buyToken),
            address(fyToken),
            idoPrice,
            idoSize,
            minimumFundingGoal,
            fyTokenMaxBasisPoints,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 7 days),
            uint64(block.timestamp + 8 days)
        );

        // Create META IDO
        uint32[] memory rounds = new uint32[](1);
        rounds[0] = initialIdoRoundId;
        ido.createMetaIDO(
            rounds,
            uint64(block.timestamp),
            uint64(block.timestamp + 12 hours)
        );

        // Mint tokens to IDO
        idoToken.mint(address(ido), idoSize);

        //Enable Round and Whitelist
        ido.enableIDORound(initialIdoRoundId);
        //ido.enableHasNoRegList(initialIdoRoundId);

        // Mint buy token to user
        buyToken.mint(user1, 2_000_000 ether);
        buyToken.mint(user2, 2_000_000 ether);

        vm.stopPrank();

        uint32 newIdoRoundId = initialIdoRoundId;

        // Users 1 Registers

        vm.startPrank(user1);
        // User Registers
        ido.registerForMetaIDO(newIdoRoundId);
        assertTrue(ido.isRegisteredForMetaIDO(newIdoRoundId, user1));
        vm.stopPrank();

        vm.startPrank(user2);
        // User 2 Registers
        ido.registerForMetaIDO(newIdoRoundId);
        assertTrue(ido.isRegisteredForMetaIDO(newIdoRoundId, user2));
        vm.stopPrank();

        // Fast forward 1 day to ido start time
        vm.warp(block.timestamp + 1 days);
        // Approve and Participate 1
        vm.startPrank(user1);
        buyToken.approve(address(ido), 2_000_000 ether);
        ido.participateInRound(newIdoRoundId, address(buyToken), 300_000 ether);
        vm.stopPrank();
        // Approve and Participate 2
        vm.startPrank(user2);
        buyToken.approve(address(ido), 2_000_000 ether);
        /*---Going over the cap will revert---*/
        vm.expectRevert("Funding cap exceeded");
        ido.participateInRound(
            newIdoRoundId,
            address(buyToken),
            1_000_000 ether
        );

        ido.participateInRound(newIdoRoundId, address(buyToken), 500_000 ether);
        vm.stopPrank();

        // FINALIZATION
        vm.warp(block.timestamp + 7 days);
        vm.startPrank(deployer);
        ido.finalizeRound(newIdoRoundId);
        vm.stopPrank();

        // USER 1 CLAIMS
        vm.startPrank(user1);
        uint256 idoTokenStart1 = idoToken.balanceOf(user1);
        ido.claimFromRound(newIdoRoundId, user1);
        uint256 idoTokenEnd1 = idoToken.balanceOf(user1);
        //console.log("user1 ido token balance:", idoTokenEnd1);
        assertGt(idoTokenEnd1, idoTokenStart1);
        vm.stopPrank();
        // USER 2 CLAIMS
        vm.startPrank(user2);
        uint256 idoTokenStart2 = idoToken.balanceOf(user2);
        ido.claimFromRound(newIdoRoundId, user2);
        uint256 idoTokenEnd2 = idoToken.balanceOf(user2);
        //console.log("user2 ido token balance:", idoTokenEnd2);
        assertGt(idoTokenEnd2, idoTokenStart2);
        vm.stopPrank();
    }

    function test_IDO_Cancelled() public {
        vm.startPrank(deployer);

        uint32 initialIdoRoundId = ido.nextIdoRoundId();

        ido.createIDORound(
            "Test IDO", // IDO name
            address(idoToken),
            address(buyToken),
            address(fyToken),
            idoPrice,
            idoSize,
            minimumFundingGoal,
            fyTokenMaxBasisPoints,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 7 days),
            uint64(block.timestamp + 8 days)
        );

        // Create META IDO
        uint32[] memory rounds = new uint32[](1);
        rounds[0] = initialIdoRoundId;
        ido.createMetaIDO(
            rounds,
            uint64(block.timestamp),
            uint64(block.timestamp + 12 hours)
        );

        // Mint tokens to IDO
        idoToken.mint(address(ido), idoSize);

        //Enable Round and Whitelist
        ido.enableIDORound(initialIdoRoundId);
        //ido.enableHasNoRegList(initialIdoRoundId);

        // Mint buy token to user
        buyToken.mint(user1, 2_000_000 ether);
        buyToken.mint(user2, 2_000_000 ether);

        vm.stopPrank();

        uint32 newIdoRoundId = initialIdoRoundId;

        // Users 1 Registers

        vm.startPrank(user1);
        // User Registers
        ido.registerForMetaIDO(newIdoRoundId);
        assertTrue(ido.isRegisteredForMetaIDO(newIdoRoundId, user1));
        vm.stopPrank();

        vm.startPrank(user2);
        // User 2 Registers
        ido.registerForMetaIDO(newIdoRoundId);
        assertTrue(ido.isRegisteredForMetaIDO(newIdoRoundId, user2));
        vm.stopPrank();

        // Fast forward 1 day to ido start time
        vm.warp(block.timestamp + 1 days);
        // Approve and Participate 1
        vm.startPrank(user1);
        buyToken.approve(address(ido), 2_000_000 ether);
        ido.participateInRound(newIdoRoundId, address(buyToken), 500_000 ether);
        vm.stopPrank();
        // Approve and Participate 2
        vm.startPrank(user2);
        buyToken.approve(address(ido), 2_000_000 ether);
        ido.participateInRound(newIdoRoundId, address(buyToken), 500_000 ether);
        vm.stopPrank();

        // CANCELLATION
        vm.warp(block.timestamp + 2 days);
        vm.startPrank(deployer);
        ido.cancelIDORound(newIdoRoundId);
        vm.stopPrank();

        // USER 1 CLAIMS
        vm.startPrank(user1);
        uint256 buyTokenStart1 = buyToken.balanceOf(user1);
        ido.claimRefund(newIdoRoundId);
        uint256 buyTokenEnd1 = buyToken.balanceOf(user1);
        //console.log("user1 buy token balance:", buyTokenEnd1);
        assertGt(buyTokenEnd1, buyTokenStart1);
        vm.stopPrank();
        // USER 2 CLAIMS
        vm.startPrank(user2);
        uint256 buyTokenStart2 = buyToken.balanceOf(user2);
        ido.claimRefund(newIdoRoundId);
        uint256 buyTokenEnd2 = buyToken.balanceOf(user2);
        //console.log("user2 buy token balance:", buyTokenEnd2);
        assertGt(buyTokenEnd2, buyTokenStart2);
        vm.stopPrank();
    }

    function test_NoReg_Participate() public {
        vm.startPrank(deployer);

        uint32 initialIdoRoundId = ido.nextIdoRoundId();

        ido.createIDORound(
            "Test IDO", // IDO name
            address(idoToken),
            address(buyToken),
            address(fyToken),
            idoPrice,
            idoSize,
            minimumFundingGoal,
            fyTokenMaxBasisPoints,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 7 days),
            uint64(block.timestamp + 8 days)
        );

        // Create META IDO
        uint32[] memory rounds = new uint32[](1);
        rounds[0] = initialIdoRoundId;
        ido.createMetaIDO(
            rounds,
            uint64(block.timestamp),
            uint64(block.timestamp + 12 hours)
        );

        // Mint tokens to IDO
        idoToken.mint(address(ido), idoSize);

        //Enable Round and Whitelist
        ido.enableIDORound(initialIdoRoundId);
        ido.enableHasNoRegList(initialIdoRoundId);

        // Mint buy token to user
        buyToken.mint(user1, 2_000_000 ether);
        buyToken.mint(user2, 2_000_000 ether);

        vm.stopPrank();

        uint32 newIdoRoundId = initialIdoRoundId;

        // Fast forward 1 day to ido start time
        vm.warp(block.timestamp + 1 days);
        // Approve and Participate 1
        vm.startPrank(user1);
        buyToken.approve(address(ido), 2_000_000 ether);
        ido.participateInRound(newIdoRoundId, address(buyToken), 500_000 ether);
        vm.stopPrank();
        // Approve and Participate 2
        vm.startPrank(user2);
        buyToken.approve(address(ido), 2_000_000 ether);
        ido.participateInRound(newIdoRoundId, address(buyToken), 500_000 ether);
        vm.stopPrank();

        // FINALIZATION
        vm.warp(block.timestamp + 6 days);
        vm.startPrank(deployer);
        ido.finalizeRound(newIdoRoundId);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        // USER 1 CLAIMS
        vm.startPrank(user1);
        uint256 idoTokenStart1 = idoToken.balanceOf(user1);
        ido.claimFromRound(newIdoRoundId, user1);
        uint256 idoTokenEnd1 = idoToken.balanceOf(user1);
        //console.log("user1 ido token balance:", idoTokenEnd1);
        assertGt(idoTokenEnd1, idoTokenStart1);
        vm.stopPrank();
        // USER 2 CLAIMS
        vm.startPrank(user2);
        uint256 idoTokenStart2 = idoToken.balanceOf(user2);
        ido.claimFromRound(newIdoRoundId, user2);
        uint256 idoTokenEnd2 = idoToken.balanceOf(user2);
        //console.log("user2 ido token balance:", idoTokenEnd2);
        assertGt(idoTokenEnd2, idoTokenStart2);
        vm.stopPrank();
    }

    function test_Multi_Round_IDO() public {
        vm.startPrank(deployer);

        uint32 roundOne = ido.nextIdoRoundId();

        // THREE ROUNDS OF 1M TOKENS EACH

        ido.createIDORound(
            "One IDO", // IDO name
            address(idoToken),
            address(buyToken),
            address(fyToken),
            idoPrice,
            1000000 * 10 ** 18,
            minimumFundingGoal,
            fyTokenMaxBasisPoints,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            uint64(block.timestamp + 3 days)
        );
        uint32 roundTwo = ido.nextIdoRoundId();

        ido.createIDORound(
            "Two IDO", // IDO name
            address(idoToken),
            address(buyToken),
            address(fyToken),
            idoPrice,
            1000000 * 10 ** 18,
            minimumFundingGoal,
            fyTokenMaxBasisPoints,
            uint64(block.timestamp + 3 days),
            uint64(block.timestamp + 4 days),
            uint64(block.timestamp + 5 days)
        );
        uint32 roundThree = ido.nextIdoRoundId();
        ido.createIDORound(
            "Three IDO", // IDO name
            address(idoToken),
            address(buyToken),
            address(fyToken),
            idoPrice,
            1000000 * 10 ** 18,
            minimumFundingGoal,
            fyTokenMaxBasisPoints,
            uint64(block.timestamp + 6 days),
            uint64(block.timestamp + 7 days),
            uint64(block.timestamp + 8 days)
        );
        // Create META IDO
        uint32[] memory rounds = new uint32[](3);
        rounds[0] = roundOne;
        rounds[1] = roundTwo;
        rounds[2] = roundThree;
       (uint32 metaIdoId)= ido.createMetaIDO(
            rounds,
            uint64(block.timestamp),
            uint64(block.timestamp + 12 hours)
        );
        assertEq(1, metaIdoId);

        // Mint tokens to IDO
        idoToken.mint(address(ido), idoSize);

        //Enable Round and Whitelist
        ido.enableIDORound(roundOne);
        vm.expectRevert("Insufficient tokens in contract for all enabled IDOs");
        ido.enableIDORound(roundTwo);
        idoToken.mint(address(ido), idoSize * 2);
        ido.enableIDORound(roundThree);
        ido.enableHasNoRegList(roundOne);
        ido.enableHasNoRegList(roundTwo);
        ido.enableHasNoRegList(roundThree);

        // Mint buy token to user
        buyToken.mint(user1, 2_000_000 ether);
        buyToken.mint(user2, 2_000_000 ether);

        vm.stopPrank();

        (uint32[] memory metaIDORounds) = ido.getMetaIDORoundIds(metaIdoId);

        assert(metaIDORounds[0]==1);
        assert(metaIDORounds[1]==2);
        assert(metaIDORounds[2]==3);
        


        /* 
        // Fast forward 1 day to ido start time
        vm.warp(block.timestamp + 1 days);
        // Approve and Participate 1
        vm.startPrank(user1);
        buyToken.approve(address(ido), 2_000_000 ether);
        ido.participateInRound(newIdoRoundId, address(buyToken), 500_000 ether);
        vm.stopPrank();
        // Approve and Participate 2
        vm.startPrank(user2);
        buyToken.approve(address(ido), 2_000_000 ether);
        ido.participateInRound(newIdoRoundId, address(buyToken), 500_000 ether);
        vm.stopPrank();

        // FINALIZATION
        vm.warp(block.timestamp + 6 days);
        vm.startPrank(deployer);
        ido.finalizeRound(newIdoRoundId);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        // USER 1 CLAIMS
        vm.startPrank(user1);
        uint256 idoTokenStart1 = idoToken.balanceOf(user1);
        ido.claimFromRound(newIdoRoundId, user1);
        uint256 idoTokenEnd1 = idoToken.balanceOf(user1);
        //console.log("user1 ido token balance:", idoTokenEnd1);
        assertGt(idoTokenEnd1, idoTokenStart1);
        vm.stopPrank();
        // USER 2 CLAIMS
        vm.startPrank(user2);
        uint256 idoTokenStart2 = idoToken.balanceOf(user2);
        ido.claimFromRound(newIdoRoundId, user2);
        uint256 idoTokenEnd2 = idoToken.balanceOf(user2);
        //console.log("user2 ido token balance:", idoTokenEnd2);
        assertGt(idoTokenEnd2, idoTokenStart2);
        vm.stopPrank(); */
    }
}

/*
Issue 1: If the ido price and size arent calculated correctly, or the amount that entered the ido is greater than the ido size,  finalize() will revert with [FAIL. Reason: panic: arithmetic underflow or overflow (0x11)]

Issue 2: If IDO is cancelled it should not be able to be Finalized as well. Although claim and refund cannot be called together.
*/
