// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IHelper {
    function calculateTier(uint256 pointBalance) external view returns (uint8);
    function getTierData(uint8 tierLevel)
        external
        view
        returns (uint256 requiredPoints, uint256 claimPercentage, uint256 cooldownPeriod);
}
