// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/XpMigrate.sol";
import "../src/Helper.sol";
import "../src/Claim.sol";
import "../src/Points.sol";

// Simple Proxy contract
contract Proxy {
    address public implementation;
    address public admin;

    constructor(address _implementation, address _admin, bytes memory _data) {
        implementation = _implementation;
        admin = _admin;
        (bool success,) = implementation.delegatecall(_data);
        require(success, "Initialization failed");
    }

    fallback() external payable {
        address _impl = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}

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
        Proxy helperProxy = new Proxy(address(helperImpl), msg.sender, helperData);
        Helper helper = Helper(address(helperProxy));
        console.log("Helper deployed to:", address(helper));

        // Deploy Claim
        Claim claimImpl = new Claim();
        bytes memory claimData =
            abi.encodeWithSelector(Claim.initialize.selector, address(0), address(helper), address(xpMigrate));
        Proxy claimProxy = new Proxy(address(claimImpl), msg.sender, claimData);
        Claim claim = Claim(address(claimProxy));
        console.log("Claim deployed to:", address(claim));

        // Deploy Points
        Points pointsImpl = new Points();
        bytes memory pointsData = abi.encodeWithSelector(Points.initialize.selector, backendService, address(claim));
        Proxy pointsProxy = new Proxy(address(pointsImpl), msg.sender, pointsData);
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
