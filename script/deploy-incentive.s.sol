// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/XpMigrate.sol";
import "../src/Helper.sol";
import "../src/Claim.sol";
import "../src/Points.sol";

contract DeployIncentiveScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address backendService = vm.envAddress("BACKEND_SERVICE");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy XpMigrate (non-upgradeable)
        XpMigrate xpMigrate = new XpMigrate();
        console.log("XpMigrate deployed to:", address(xpMigrate));

        // Deploy Helper
        Helper helperImpl = new Helper();
        bytes memory helperData = abi.encodeWithSelector(Helper.initialize.selector, backendService);
        ERC1967Proxy helperProxy = new ERC1967Proxy(address(helperImpl), helperData);
        Helper helper = Helper(address(helperProxy));
        console.log("Helper deployed to:", address(helper));

        // Deploy Claim
        Claim claimImpl = new Claim();
        bytes memory claimData =
            abi.encodeWithSelector(Claim.initialize.selector, address(0), address(helper), address(xpMigrate));
        ERC1967Proxy claimProxy = new ERC1967Proxy(address(claimImpl), claimData);
        Claim claim = Claim(address(claimProxy));
        console.log("Claim deployed to:", address(claim));

        // Deploy Points
        Points pointsImpl = new Points();
        bytes memory pointsData = abi.encodeWithSelector(Points.initialize.selector, backendService, address(claim));
        ERC1967Proxy pointsProxy = new ERC1967Proxy(address(pointsImpl), pointsData);
        Points points = Points(address(pointsProxy));
        console.log("Points deployed to:", address(points));

        // Set up contract interactions
        points.setHelperContract(address(helper));
        claim.setPointsContract(address(points));
        xpMigrate.setClaimContract(address(claim));

        console.log("Contract setup complete!");

        vm.stopBroadcast();
    }
}
