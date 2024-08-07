// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "./interfaces/IHelper.sol";
import "./interfaces/IPoints.sol";
import "./interfaces/IXpMigrate.sol";

contract Claim is Initializable, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    struct UserData {
        uint256 pointBalance;
        uint256 lastClaimTimestamp;
        uint8 tier;
        uint8 consecutiveWeeksClaimed;
    }

    struct Tier {
        uint256 requiredPoints;
        uint256 claimPercentage;
        uint256 cooldownPeriod;
    }

    IPoints public pointsContract;
    IHelper public helperContract;
    IXpMigrate public xpMigrateContract;

    uint256 public baseConversionRate;
    uint256 public dynamicMultiplier;

    event Claimed(address indexed user, uint256 pointsUsed, uint256 tokensMinted);

    function initialize(address _pointsContract, address _helperContract, address _xpMigrateContract)
        public
        initializer
    {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();
        pointsContract = IPoints(_pointsContract);
        helperContract = IHelper(_helperContract);
        xpMigrateContract = IXpMigrate(_xpMigrateContract);
        baseConversionRate = 100; // 100 points = 1 xpMigrate token
        dynamicMultiplier = 1e18; // 1x multiplier
    }

    function claim(uint256 pointAmount) external whenNotPaused {
        (uint256 pointBalance, uint256 lastClaimTimestamp, uint8 tier, uint8 consecutiveWeeksClaimed) =
            pointsContract.getUserData(msg.sender);
        UserData memory userData = UserData(pointBalance, lastClaimTimestamp, tier, consecutiveWeeksClaimed);

        require(pointAmount > 0 && pointAmount <= userData.pointBalance, "Invalid point amount");

        uint8 userTier = helperContract.calculateTier(userData.pointBalance);
        (uint256 requiredPoints, uint256 claimPercentage, uint256 cooldownPeriod) = helperContract.getTierData(userTier);
        Tier memory tierData = Tier(requiredPoints, claimPercentage, cooldownPeriod);

        require(block.timestamp >= userData.lastClaimTimestamp + tierData.cooldownPeriod, "Cooldown period not elapsed");
        require(pointAmount <= (userData.pointBalance * tierData.claimPercentage) / 100, "Exceeds claimable amount");

        uint256 tokenAmount = (pointAmount * dynamicMultiplier) / baseConversionRate / 1e18;

        pointsContract.deductPoints(msg.sender, pointAmount, "Claim xpMigrate");
        xpMigrateContract.mint(msg.sender, tokenAmount);

        emit Claimed(msg.sender, pointAmount, tokenAmount);
    }

    function setDynamicMultiplier(uint256 newMultiplier) external onlyOwner {
        require(newMultiplier >= 5e17 && newMultiplier <= 5e18, "Multiplier out of range"); // 0.5x to 5x
        dynamicMultiplier = newMultiplier;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
