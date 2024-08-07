// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IHelper {
    function applyMultiplier(uint256 amount, uint8 actionType) external view returns (uint256);
    function calculateTier(uint256 pointBalance) external view returns (uint8);
    function getTierData(uint8 tierLevel)
        external
        view
        returns (uint256 requiredPoints, uint256 claimPercentage, uint256 cooldownPeriod);
}
