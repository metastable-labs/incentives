// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "./interfaces/IHelper.sol";
import "./interfaces/IPoints.sol";
import "./interfaces/IXpMigrate.sol";

/// @title Claim Contract for XpMigrate Tokens
/// @notice This contract manages the claiming process for XpMigrate tokens based on user points
/// @dev This contract is upgradeable, ownable, and pausable
contract Claim is Initializable, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    /// @notice Struct to hold user data
    /// @dev Used to store and manage user-specific information
    struct UserData {
        uint256 pointBalance;
        uint256 lastClaimTimestamp;
        uint8 tier;
        uint8 consecutiveWeeksClaimed;
    }

    /// @notice Struct to hold tier data
    /// @dev Used to store and manage tier-specific information
    struct Tier {
        uint256 requiredPoints;
        uint256 claimPercentage;
        uint256 cooldownPeriod;
    }

    /// @notice Interface for the Points contract
    IPoints public pointsContract;

    /// @notice Interface for the Helper contract
    IHelper public helperContract;

    /// @notice Interface for the XpMigrate token contract
    IXpMigrate public xpMigrateContract;

    /// @notice Base conversion rate from points to tokens
    /// @dev 100 points = 1 xpMigrate token
    uint256 public baseConversionRate;

    /// @notice Dynamic multiplier for token conversion
    /// @dev Uses 1e18 as base unit, so 1e18 = 1x multiplier
    uint256 public dynamicMultiplier;

    /// @notice Emitted when a user successfully claims tokens
    /// @param user Address of the user who claimed
    /// @param pointsUsed Amount of points used for the claim
    /// @param tokensMinted Amount of XpMigrate tokens minted
    event Claimed(address indexed user, uint256 pointsUsed, uint256 tokensMinted);

    /// @notice Initializes the contract
    /// @dev This function replaces the constructor for upgradeable contracts
    /// @param _helperContract Address of the Helper contract
    /// @param _xpMigrateContract Address of the XpMigrate token contract
    function initialize(address _helperContract, address _xpMigrateContract) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();
        helperContract = IHelper(_helperContract);
        xpMigrateContract = IXpMigrate(_xpMigrateContract);
        baseConversionRate = 100; // 100 points = 1 xpMigrate token
        dynamicMultiplier = 1e18; // 1x multiplier
    }

    function setPointsContract(address _pointsContract) external onlyOwner {
        pointsContract = IPoints(_pointsContract);
    }

    /// @notice Allows users to claim XpMigrate tokens based on their points
    /// @dev Checks user's tier, cooldown period, and claimable amount before minting tokens
    /// @param pointAmount The amount of points the user wants to convert to tokens
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

    /// @notice Sets a new dynamic multiplier for token conversion
    /// @dev Only callable by the contract owner
    /// @param newMultiplier The new multiplier value (5e17 to 5e18, representing 0.5x to 5x)
    function setDynamicMultiplier(uint256 newMultiplier) external onlyOwner {
        require(newMultiplier >= 5e17 && newMultiplier <= 5e18, "Multiplier out of range"); // 0.5x to 5x
        dynamicMultiplier = newMultiplier;
    }

    function getClaimableAmount(address user) public view returns (uint256) {
        (uint256 pointBalance, uint256 lastClaimTimestamp, uint8 tier,) = pointsContract.getUserData(user);

        // Get tier data
        (uint256 requiredPoints, uint256 claimPercentage, uint256 cooldownPeriod) = helperContract.getTierData(tier);

        // Check if the cooldown period has passed
        if (block.timestamp < lastClaimTimestamp + cooldownPeriod) {
            return 0;
        }

        // Calculate the maximum claimable amount based on the tier's claim percentage
        uint256 maxClaimable = (pointBalance * claimPercentage) / 100;

        return maxClaimable;
    }

    /// @notice Function to authorize an upgrade
    /// @dev Required by the UUPSUpgradeable contract
    /// @param newImplementation Address of the new implementation contract
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
