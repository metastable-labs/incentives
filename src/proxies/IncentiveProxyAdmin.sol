// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract IncentiveProxyAdmin is ProxyAdmin {
    constructor() ProxyAdmin(msg.sender) {}
}
