// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Points.sol";
import "../src/Helper.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// Mock Claim contract for testing
contract MockClaim {
    function initialize(address, address, address) external {}
}

contract PointsTest is Test {
    Points public points;
    Helper public helper;
    MockClaim public mockClaim;
    address public owner;
    address public backend;

    function setUp() public {
        owner = address(this);
        backend = address(0x1);

        // Deploy implementation contracts
        Points pointsImpl = new Points();
        Helper helperImpl = new Helper();
        mockClaim = new MockClaim();

        // Deploy proxies
        TransparentUpgradeableProxy pointsProxy = new TransparentUpgradeableProxy(
            address(pointsImpl), owner, abi.encodeWithSelector(Points.initialize.selector, backend, address(mockClaim))
        );

        TransparentUpgradeableProxy helperProxy = new TransparentUpgradeableProxy(
            address(helperImpl), owner, abi.encodeWithSelector(Helper.initialize.selector, backend)
        );

        // Get proxied contracts
        points = Points(address(pointsProxy));
        helper = Helper(address(helperProxy));

        // Set helper contract in Points
        points.setHelperContract(address(helper));
    }

    function testEarnPoints() public {
        vm.prank(backend);
        points.earnPoints(address(0x2), 10, Points.ActionType.LIQUIDITY_MIGRATION, true, false, false);

        (uint256 balance,,,) = points.getUserData(address(0x2));
        assertEq(balance, 25000); // 10 * 1000 * 2.5
    }

    function testDeductPoints() public {
        vm.startPrank(backend);
        points.earnPoints(address(0x2), 10, Points.ActionType.LIQUIDITY_MIGRATION, true, false, false);
        vm.stopPrank();

        vm.prank(address(mockClaim));
        points.deductPoints(address(0x2), 10000, "Test deduction");

        (uint256 balance,,,) = points.getUserData(address(0x2));
        assertEq(balance, 15000);
    }

    // Add more tests as needed...
}
