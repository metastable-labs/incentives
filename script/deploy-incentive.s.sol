// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import "../src/Points.sol";
import "../src/Helper.sol";
import "../src/Claim.sol";
import "../src/XpMigrate.sol";
import "../src/proxies/PointsProxy.sol";
import "../src/proxies/HelperProxy.sol";
import "../src/proxies/ClaimProxy.sol";
import "../src/proxies/IncentiveProxyAdmin.sol";

contract DeployIncentiveScript is Script {
    using stdJson for string;

    function setUp() public {}

    function run() public returns (address, address, address, address, address) {
        // get pvt key from env file, log associated address
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        string memory deployConfigJson = getDeployConfigJson();

        address backendService = deployConfigJson.readAddress(".backendService");

        // Deploy implementation contracts
        Points pointsImpl = new Points();
        Helper helperImpl = new Helper();
        Claim claimImpl = new Claim();
        XpMigrate xpMigrate = new XpMigrate();

        // Deploy ProxyAdmin
        IncentiveProxyAdmin proxyAdmin = new IncentiveProxyAdmin();

        // Prepare initialization data
        // Deploy proxy for Claim first (we need its address for Points initialization)
        bytes memory claimData =
            abi.encodeWithSelector(Claim.initialize.selector, address(0), address(0), address(xpMigrate));
        TransparentUpgradeableProxy claimProxy =
            new TransparentUpgradeableProxy(address(claimImpl), address(proxyAdmin), claimData);

        // Deploy proxy for Points
        bytes memory pointsData =
            abi.encodeWithSelector(Points.initialize.selector, backendService, address(claimProxy));
        TransparentUpgradeableProxy pointsProxy =
            new TransparentUpgradeableProxy(address(pointsImpl), address(proxyAdmin), pointsData);

        // Deploy proxy for Helper
        bytes memory helperData = abi.encodeWithSelector(Helper.initialize.selector, backendService);
        TransparentUpgradeableProxy helperProxy =
            new TransparentUpgradeableProxy(address(helperImpl), address(proxyAdmin), helperData);

        // Set up contract interactions
        Points(address(pointsProxy)).setHelperContract(address(helperProxy));
        Claim(address(claimProxy)).initialize(address(pointsProxy), address(helperProxy), address(xpMigrate));
        xpMigrate.setClaimContract(address(claimProxy));

        vm.stopBroadcast();

        return
            (address(pointsProxy), address(helperProxy), address(claimProxy), address(xpMigrate), address(proxyAdmin));
    }

    function getDeployConfigJson() internal view returns (string memory json) {
        json = vm.readFile(string.concat(vm.projectRoot(), "/script/config.json"));
    }
}
