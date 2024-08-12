// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Points.sol";
import "../src/Helper.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// Updated MockClaim contract
contract MockClaim {
    address public pointsContract;

    function initialize(address, address, address) external {}

    function setPointsContract(address _pointsContract) external {
        pointsContract = _pointsContract;
    }
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

        // Set points contract in MockClaim
        mockClaim.setPointsContract(address(points));
    }

    function testEarnPoints() public {
        vm.prank(backend);
        points.earnPoints(address(0x2), 10, Points.ActionType.LIQUIDITY_MIGRATION, true, false, false);

        (uint256 balance,,,) = points.getUserData(address(0x2));
        assertEq(balance, 25_000); // 10 * 1000 * 2.5
    }

    function testDeductPoints() public {
        vm.startPrank(backend);
        points.earnPoints(address(0x2), 10, Points.ActionType.LIQUIDITY_MIGRATION, true, false, false);
        vm.stopPrank();

        vm.prank(address(mockClaim));
        points.deductPoints(address(0x2), 10_000, "Test deduction");

        (uint256 balance,,,) = points.getUserData(address(0x2));
        assertEq(balance, 15_000);
    }

    function testOnlyClaimContractCanDeductPoints() public {
        vm.prank(backend);
        points.earnPoints(address(0x2), 10, Points.ActionType.LIQUIDITY_MIGRATION, true, false, false);

        vm.expectRevert("Only Claim Contract can call this function");
        points.deductPoints(address(0x2), 10_000, "Test deduction");
    }

    function testSetHelperContract() public {
        address newHelper = address(0x3);

        vm.prank(owner);
        points.setHelperContract(newHelper);

        assertEq(address(points.helperContract()), newHelper);
    }

    function testOnlyOwnerCanSetHelperContract() public {
        address newHelper = address(0x3);

        vm.prank(address(0x4));
        vm.expectRevert("Ownable: caller is not the owner");
        points.setHelperContract(newHelper);
    }
}
