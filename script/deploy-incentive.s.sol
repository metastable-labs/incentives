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
        bytes memory pointsData = abi.encodeWithSelector(Points(address(0)).initialize.selector, backendService);
        bytes memory helperData = abi.encodeWithSelector(Helper(address(0)).initialize.selector, backendService);
        bytes memory claimData =
            abi.encodeWithSelector(Claim(address(0)).initialize.selector, address(0), address(0), address(xpMigrate));

        // Deploy proxy contracts
        PointsProxy pointsProxy = new PointsProxy(address(pointsImpl), address(proxyAdmin), pointsData);
        HelperProxy helperProxy = new HelperProxy(address(helperImpl), address(proxyAdmin), helperData);
        ClaimProxy claimProxy = new ClaimProxy(address(claimImpl), address(proxyAdmin), claimData);

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
