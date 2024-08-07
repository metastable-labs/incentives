// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPoints {
    function getUserData(address user)
        external
        view
        returns (uint256 pointBalance, uint256 lastClaimTimestamp, uint8 tier, uint8 consecutiveWeeksClaimed);
    function deductPoints(address user, uint256 amount, string calldata reason) external;
}
