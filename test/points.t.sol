// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Points.sol";
import "../src/interfaces/IHelper.sol";
import "../src/interfaces/IXpMigrate.sol";

contract MockHelper is IHelper {
    function calculateTier(uint256 pointBalance) external pure returns (uint8) {
        if (pointBalance >= 5000) return 2; // Gold
        if (pointBalance >= 1000) return 1; // Silver
        return 0; // Bronze
    }

    function getTierData(uint8 tier) external pure returns (uint256, uint256, uint256) {
        if (tier == 2) return (5000, 100, 0); // Gold: 5000 points, 100% claim, 0 cooldown
        if (tier == 1) return (1000, 75, 12 hours); // Silver: 1000 points, 75% claim, 12 hours cooldown
        return (0, 50, 24 hours); // Bronze: 0 points, 50% claim, 24 hours cooldown
    }
}

contract MockXpMigrate is IXpMigrate {
    mapping(address => uint256) public balances;

    function mint(address to, uint256 amount) external {
        balances[to] += amount;
    }
}

contract PointsTest is Test {
    Points public points;
    MockHelper public helper;
    MockXpMigrate public xpMigrate;
    address public backendService;

    function setUp() public {
        backendService = address(this);
        helper = new MockHelper();
        xpMigrate = new MockXpMigrate();

        points = new Points();
        points.initialize(backendService, address(helper), address(xpMigrate));
    }

    function testInitialize() public {
        assertEq(points.backendService(), backendService);
        assertEq(address(points.helperContract()), address(helper));
        assertEq(address(points.xpMigrateContract()), address(xpMigrate));
        assertEq(points.baseConversionRate(), 100);
    }

    function testRecordPoints() public {
        points.recordPoints(address(1), 1000, Points.ActionType.LIQUIDITY_MIGRATION);
        (uint256 balance,, uint8 tier,) = points.getUserData(address(1));
        assertEq(balance, 1000);
        assertEq(tier, 1); // Silver tier
    }

    function testRecordPointsOnlyBackend() public {
        vm.prank(address(0xdead));
        vm.expectRevert("Only backend can call this function");
        points.recordPoints(address(1), 1000, Points.ActionType.LIQUIDITY_MIGRATION);
    }

    function testClaim() public {
        points.recordPoints(address(this), 1000, Points.ActionType.LIQUIDITY_MIGRATION);
        vm.warp(block.timestamp + 13 hours); // Wait for cooldown
        points.claim(500);
        (uint256 balance,,,) = points.getUserData(address(this));
        assertEq(balance, 500);
        assertEq(xpMigrate.balances(address(this)), 5); // 500 / 100
    }

    function testClaimExceedsBalance() public {
        points.recordPoints(address(this), 1000, Points.ActionType.LIQUIDITY_MIGRATION);
        vm.warp(block.timestamp + 13 hours); // Wait for cooldown
        vm.expectRevert("Invalid point amount");
        points.claim(1001);
    }

    function testClaimExceedsClaimablePercentage() public {
        points.recordPoints(address(this), 1000, Points.ActionType.LIQUIDITY_MIGRATION);
        vm.warp(block.timestamp + 13 hours); // Wait for cooldown
        vm.expectRevert("Exceeds claimable amount");
        points.claim(800); // Silver tier can only claim 75%
    }

    function testClaimBeforeCooldown() public {
        points.recordPoints(address(this), 1000, Points.ActionType.LIQUIDITY_MIGRATION);
        vm.expectRevert("Cooldown period not elapsed");
        points.claim(500);
    }

    function testGetClaimableAmount() public {
        points.recordPoints(address(this), 1000, Points.ActionType.LIQUIDITY_MIGRATION);
        vm.warp(block.timestamp + 13 hours); // Wait for cooldown
        uint256 claimable = points.getClaimableAmount(address(this));
        assertEq(claimable, 750); // 75% of 1000
    }

    function testGetClaimableAmountDuringCooldown() public {
        points.recordPoints(address(this), 1000, Points.ActionType.LIQUIDITY_MIGRATION);
        uint256 claimable = points.getClaimableAmount(address(this));
        assertEq(claimable, 0); // During cooldown
    }

    function testMultipleClaims() public {
        points.recordPoints(address(this), 10_000, Points.ActionType.LIQUIDITY_MIGRATION);
        vm.warp(block.timestamp + 1 hours);
        points.claim(5000);
        (uint256 balance,,,) = points.getUserData(address(this));
        assertEq(balance, 5000);
        assertEq(xpMigrate.balances(address(this)), 50);

        vm.warp(block.timestamp + 1 hours);
        points.claim(5000);
        (balance,,,) = points.getUserData(address(this));
        assertEq(balance, 0);
        assertEq(xpMigrate.balances(address(this)), 100);
    }

    function testGetAllUsersData() public {
        address[] memory testUsers = new address[](3);
        testUsers[0] = address(0x1);
        testUsers[1] = address(0x2);
        testUsers[2] = address(0x3);

        for (uint256 i = 0; i < testUsers.length; i++) {
            points.recordPoints(testUsers[i], (i + 1) * 1000, Points.ActionType.LIQUIDITY_MIGRATION);
        }

        (address[] memory users, Points.UserData[] memory userData) = points.getAllUsersData(0, 3);

        assertEq(users.length, 3);
        assertEq(userData.length, 3);

        for (uint256 i = 0; i < users.length; i++) {
            assertEq(users[i], testUsers[i]);
            assertEq(userData[i].pointBalance, (i + 1) * 1000);
            assertEq(userData[i].tier, i == 0 ? 1 : 2); // 1000 points is Silver, 2000+ is Gold
        }
    }

    function testGetAllUsersDataPagination() public {
        for (uint256 i = 0; i < 5; i++) {
            points.recordPoints(address(uint160(i + 1)), (i + 1) * 1000, Points.ActionType.LIQUIDITY_MIGRATION);
        }

        (address[] memory users1, Points.UserData[] memory userData1) = points.getAllUsersData(0, 3);
        (address[] memory users2, Points.UserData[] memory userData2) = points.getAllUsersData(3, 5);

        assertEq(users1.length, 3);
        assertEq(userData1.length, 3);
        assertEq(users2.length, 2);
        assertEq(userData2.length, 2);

        assertEq(users1[0], address(0x1));
        assertEq(users2[0], address(0x4));
    }

    function testGetTotalUsers() public {
        for (uint256 i = 0; i < 5; i++) {
            points.recordPoints(address(uint160(i + 1)), 1000, Points.ActionType.LIQUIDITY_MIGRATION);
        }

        uint256 totalUsers = points.getTotalUsers();
        assertEq(totalUsers, 5);

        // Record points for an existing user
        points.recordPoints(address(0x1), 1000, Points.ActionType.BRIDGING);
        totalUsers = points.getTotalUsers();
        assertEq(totalUsers, 5, "Total users should not increase for existing user");
    }
}
