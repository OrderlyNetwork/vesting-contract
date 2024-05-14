// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "contracts/LockedTokenVault.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test", "TEST") {
        _mint(msg.sender, 10000 * 10 ** decimals());
    }
}

contract LockedTokenVaultTest is Test {
    using Math for uint256;

    LockedTokenVault vault;
    TestToken token;
    address constant ADMIN = address(0x1234567890);
    address constant ALICE = address(0xA11ce);
    address constant BOB = address(0xB0b);
    uint256 constant ONE_MONTH = 2628000;
    uint256 constant START_TIME = 1719763200; // 2024-07-01 00:00:00
    uint256 constant CLIFF_TIME = START_TIME + 12 * ONE_MONTH;
    uint256 constant START_TIME_PLUS_6_MONTH = START_TIME + 6 * ONE_MONTH;
    uint256 constant CLIFF_TIME_PLUS_12_MONTH = CLIFF_TIME + 12 * ONE_MONTH;
    uint256 constant FINISH_TIME = START_TIME + 48 * ONE_MONTH;
    uint256 constant DURATION = 48 * ONE_MONTH; // 4 years
    uint256 constant BASE_AMOUNT = 1 ether; // 1 ether token
    uint256 constant AMOUNT = 48 * BASE_AMOUNT; // 48 month, so one month 1 BASE_AMOUNT
    uint256 constant ONE = 10 ** 18;

    function setUp() public {
        vm.startPrank(ADMIN);
        token = new TestToken();
        vault = new LockedTokenVault(ADMIN, address(token));
        vm.stopPrank();
    }

    function test_depositWithdraw() public {
        vm.startPrank(ADMIN);
        token.approve(address(vault), 1000);
        vault.deposit(1000);
        assertEq(token.balanceOf(address(vault)), 1000);
        assertEq(vault._UNDISTRIBUTED_AMOUNT_(), 1000);
        vault.withdraw(500);
        assertEq(token.balanceOf(address(vault)), 500);
        assertEq(vault._UNDISTRIBUTED_AMOUNT_(), 500);
        vm.stopPrank();
    }

    function test_grant() public {
        vm.startPrank(ADMIN);
        token.approve(address(vault), AMOUNT);
        vault.deposit(AMOUNT);
        _grant();
        vm.stopPrank();
        assertEq(vault.getStartReleaseTime(ALICE), START_TIME);
        assertEq(vault.getReleaseDuration(ALICE), DURATION);
        assertEq(vault.getOriginBalance(ALICE), AMOUNT);
        assertEq(vault.getClaimedBalance(ALICE), 0);
        assertEq(vault.getCliffTime(ALICE), CLIFF_TIME);
        vm.warp(START_TIME);
        assertEq(vault.getClaimableBalance(ALICE), 0);
        assertEq(vault.getRemainingBalance(ALICE), AMOUNT);
        assertEq(vault.getRemainingRatio(START_TIME, ALICE), ONE);
        vm.warp(START_TIME_PLUS_6_MONTH);
        assertEq(vault.getClaimableBalance(ALICE), 0);
        assertEq(vault.getRemainingBalance(ALICE), AMOUNT.mulDiv(42, 48));
        assertEq(
            vault.getRemainingRatio(START_TIME_PLUS_6_MONTH, ALICE),
            ONE.mulDiv(42, 48)
        );
        vm.warp(CLIFF_TIME);
        assertEq(vault.getClaimableBalance(ALICE), AMOUNT.mulDiv(12, 48));
        assertEq(vault.getRemainingBalance(ALICE), AMOUNT.mulDiv(36, 48));
        assertEq(
            vault.getRemainingRatio(CLIFF_TIME, ALICE),
            ONE.mulDiv(36, 48)
        );
        vm.warp(CLIFF_TIME_PLUS_12_MONTH);
        assertEq(vault.getClaimableBalance(ALICE), AMOUNT.mulDiv(24, 48));
        assertEq(vault.getRemainingBalance(ALICE), AMOUNT.mulDiv(24, 48));
        assertEq(
            vault.getRemainingRatio(CLIFF_TIME_PLUS_12_MONTH, ALICE),
            ONE.mulDiv(24, 48)
        );
        vm.warp(FINISH_TIME);
        assertEq(vault.getClaimableBalance(ALICE), AMOUNT);
        assertEq(vault.getRemainingBalance(ALICE), 0);
        assertEq(vault.getRemainingRatio(FINISH_TIME, ALICE), 0);
    }

    function test_claim() public {
        vm.startPrank(ADMIN);
        token.approve(address(vault), AMOUNT);
        vault.deposit(AMOUNT);
        _grant();
        vm.stopPrank();
        // === CLIFF_TIME_PLUS_12_MONTH ===
        vm.warp(CLIFF_TIME_PLUS_12_MONTH);
        // before claim
        assertEq(token.balanceOf(ALICE), 0);
        assertEq(vault.getClaimableBalance(ALICE), AMOUNT.mulDiv(24, 48));
        // claim
        vm.prank(ALICE);
        vault.claim();
        // after claim
        assertEq(token.balanceOf(ALICE), AMOUNT.mulDiv(24, 48));
        assertEq(vault.getClaimableBalance(ALICE), 0);
        assertEq(vault.getClaimedBalance(ALICE), AMOUNT.mulDiv(24, 48));
        assertEq(vault.getRemainingBalance(ALICE), AMOUNT.mulDiv(24, 48));
        assertEq(
            vault.getRemainingRatio(CLIFF_TIME_PLUS_12_MONTH, ALICE),
            ONE.mulDiv(24, 48)
        );
        // === FINISH_TIME ===
        vm.warp(FINISH_TIME);
        // before claim
        assertEq(token.balanceOf(ALICE), AMOUNT.mulDiv(24, 48));
        assertEq(vault.getClaimableBalance(ALICE), AMOUNT.mulDiv(24, 48));
        assertEq(vault.getClaimedBalance(ALICE), AMOUNT.mulDiv(24, 48));
        // claim
        vm.prank(ALICE);
        vault.claim();
        // after claim
        assertEq(token.balanceOf(ALICE), AMOUNT);
        assertEq(vault.getClaimableBalance(ALICE), 0);
        assertEq(vault.getClaimedBalance(ALICE), AMOUNT);
        assertEq(vault.getRemainingBalance(ALICE), 0);
        assertEq(vault.getRemainingRatio(FINISH_TIME, ALICE), 0);
    }

    function test_recall() public {
        vm.startPrank(ADMIN);
        token.approve(address(vault), AMOUNT);
        vault.deposit(AMOUNT);
        _grant();
        vm.stopPrank();
        // === CLIFF_TIME_PLUS_12_MONTH & claim ===
        vm.warp(CLIFF_TIME_PLUS_12_MONTH);
        // claim
        vm.prank(ALICE);
        vault.claim();
        // recall here
        vm.prank(ADMIN);
        vault.recall(ALICE);
        // after recall
        assertEq(vault.getClaimableBalance(ALICE), 0);
        assertEq(vault.getClaimedBalance(ALICE), 0);
        assertEq(vault.getRemainingBalance(ALICE), 0);
        assertEq(vault.getRemainingRatio(CLIFF_TIME_PLUS_12_MONTH, ALICE), 0);
        assertEq(vault._UNDISTRIBUTED_AMOUNT_(), AMOUNT.mulDiv(24, 48));
    }

    function test_regrantSame() public {
        vm.startPrank(ADMIN);
        token.approve(address(vault), 2 * AMOUNT);
        vault.deposit(2 * AMOUNT);
        _grant();
        vm.stopPrank();
        // === CLIFF_TIME_PLUS_12_MONTH ===
        vm.warp(CLIFF_TIME_PLUS_12_MONTH);
        vm.prank(ALICE);
        vault.claim();
        // regrant here
        vm.prank(ADMIN);
        _grant();
        // after regrant
        assertEq(vault.getOriginBalance(ALICE), AMOUNT * 2);
        assertEq(vault.getClaimedBalance(ALICE), AMOUNT.mulDiv(24, 48));
        assertEq(vault.getClaimableBalance(ALICE), AMOUNT.mulDiv(24, 48));
        assertEq(vault.getRemainingBalance(ALICE), AMOUNT);
    }

    function test_regrantDifferent() public {
        vm.startPrank(ADMIN);
        token.approve(address(vault), 2 * AMOUNT);
        vault.deposit(2 * AMOUNT);
        _grant();
        vm.stopPrank();
        // === CLIFF_TIME_PLUS_12_MONTH ===
        vm.warp(CLIFF_TIME_PLUS_12_MONTH);
        vm.prank(ALICE);
        vault.claim();
        // regrant here
        vm.prank(ADMIN);
        _regrant();
        // after regrant
        assertEq(vault.getOriginBalance(ALICE), AMOUNT * 2);
        assertEq(vault.getClaimedBalance(ALICE), AMOUNT.mulDiv(24, 48));
        assertEq(vault.getClaimableBalance(ALICE), 0);
        assertEq(vault.getRemainingBalance(ALICE), AMOUNT * 2);
        // === CLIFF_TIME_PLUS_12_MONTH + 12 * ONE_MONTH ===
        vm.warp(CLIFF_TIME_PLUS_12_MONTH + 12 * ONE_MONTH);
        assertEq(vault.getOriginBalance(ALICE), AMOUNT * 2);
        assertEq(vault.getClaimedBalance(ALICE), AMOUNT.mulDiv(24, 48));
        assertEq(vault.getClaimableBalance(ALICE), AMOUNT.mulDiv(24, 48));
        assertEq(vault.getRemainingBalance(ALICE), AMOUNT);
    }

    function _grant() public {
        address[] memory holderList = new address[](1);
        holderList[0] = ALICE;
        uint256[] memory amountList = new uint256[](1);
        amountList[0] = AMOUNT;
        uint256[] memory startList = new uint256[](1);
        startList[0] = START_TIME;
        uint256[] memory durationList = new uint256[](1);
        durationList[0] = DURATION;
        uint256[] memory cliffList = new uint256[](1);
        cliffList[0] = CLIFF_TIME;
        vault.grant(holderList, amountList, startList, durationList, cliffList);
    }

    function _regrant() public {
        address[] memory holderList = new address[](1);
        holderList[0] = ALICE;
        uint256[] memory amountList = new uint256[](1);
        amountList[0] = AMOUNT;
        uint256[] memory startList = new uint256[](1);
        startList[0] = CLIFF_TIME_PLUS_12_MONTH;
        uint256[] memory durationList = new uint256[](1);
        durationList[0] = 24 * ONE_MONTH;
        uint256[] memory cliffList = new uint256[](1);
        cliffList[0] = CLIFF_TIME_PLUS_12_MONTH + 12 * ONE_MONTH;
        vault.grant(holderList, amountList, startList, durationList, cliffList);
    }
}
