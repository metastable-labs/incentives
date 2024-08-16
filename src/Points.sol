// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "./interfaces/IHelper.sol";
import "./interfaces/IXpMigrate.sol";

/// @title Points Contract for Incentive system
/// @notice This contract manages the point system for users in the Supermigrate ecosystem
contract Points is Initializable, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    /// @notice Struct to store user-specific data
    /// @param pointBalance The current point balance of the user
    /// @param lastClaimTimestamp The timestamp of the user's last claim
    /// @param tier The current tier of the user
    /// @param consecutiveWeeksClaimed The number of consecutive weeks the user has claimed
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

    /// @notice Enum representing different types of actions that can earn points
    enum ActionType {
        LIQUIDITY_MIGRATION,
        BRIDGING,
        SOCIAL_INTERACTION,
        NFT_MINT,
        REFERRAL
    }

    /// @notice Mapping to store user data
    mapping(address => UserData) private _userData;

    /// @notice Address of the backend service authorized to call certain functions
    address public backendService;

    /// @notice interface of the helper contract
    IHelper public helperContract;
    /// @notice Interface for the XpMigrate token contract
    IXpMigrate public xpMigrateContract;

    /// @notice Base conversion rate from points to tokens
    /// @dev 100 points = 1 xpMigrate token
    uint256 public baseConversionRate;

    /// @notice Emitted when a user earns points
    /// @param user The address of the user earning points
    /// @param amount The amount of points earned
    /// @param actionType The type of action that earned the points
    event PointsEarned(address indexed user, uint256 amount, ActionType actionType);

    /// @notice Emitted when points are deducted from a user
    /// @param user The address of the user losing points
    /// @param amount The amount of points deducted
    event PointsDeducted(address indexed user, uint256 amount);

    /// @notice Emitted when a user successfully claims tokens
    /// @param user Address of the user who claimed
    /// @param pointsUsed Amount of points used for the claim
    /// @param tokensMinted Amount of XpMigrate tokens minted
    event Claimed(address indexed user, uint256 pointsUsed, uint256 tokensMinted);

    function initialize(address _backendService, address _helperContract, address _xpMigrateContract)
        public
        initializer
    {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();
        backendService = _backendService;
        helperContract = IHelper(_helperContract);
        xpMigrateContract = IXpMigrate(_xpMigrateContract);
        baseConversionRate = 100; // 100 points = 1 xpMigrate token
    }

    /// @notice Modifier to restrict function access to only the backend service
    modifier onlyBackend() {
        require(msg.sender == backendService, "Only backend can call this function");
        _;
    }

    /// @notice Allows backend service to record points for users
    /// @dev Can only be called by the backend service when the contract is not paused
    /// @param user The address of the user earning points
    /// @param pointsAmount The number of points to record for user
    /// @param actionType The type of action performed to earn points
    function recordPoints(address user, uint256 pointsAmount, ActionType actionType)
        external
        onlyBackend
        whenNotPaused
    {
        _userData[user].pointBalance += pointsAmount;
        _userData[user].tier = helperContract.calculateTier(_userData[user].pointBalance);
        emit PointsEarned(user, pointsAmount, actionType);
    }

    /// @notice Deducts points from a user
    /// @dev Can only be called by the backend service when the contract is not paused
    /// @param user The address of the user to deduct points from
    /// @param amount The amount of points to deduct
    function _deductPoints(address user, uint256 amount) internal onlyBackend whenNotPaused {
        require(_userData[user].pointBalance >= amount, "Insufficient points");
        _userData[user].pointBalance -= amount;
        _userData[user].tier = helperContract.calculateTier(_userData[user].pointBalance);
        emit PointsDeducted(user, amount);
    }

    /// @notice Allows users to claim XpMigrate tokens based on their points
    /// @dev Checks user's tier, cooldown period, and claimable amount before minting tokens
    /// @param pointAmount The amount of points the user wants to convert to tokens
    function claim(uint256 pointAmount) external whenNotPaused {
        (uint256 pointBalance, uint256 lastClaimTimestamp, uint8 tier, uint8 consecutiveWeeksClaimed) =
            _getUserData(msg.sender);
        UserData memory userData = UserData(pointBalance, lastClaimTimestamp, tier, consecutiveWeeksClaimed);

        require(pointAmount > 0 && pointAmount <= userData.pointBalance, "Invalid point amount");

        uint8 userTier = helperContract.calculateTier(userData.pointBalance);
        (uint256 requiredPoints, uint256 claimPercentage, uint256 cooldownPeriod) = helperContract.getTierData(userTier);
        Tier memory tierData = Tier(requiredPoints, claimPercentage, cooldownPeriod);

        require(block.timestamp >= userData.lastClaimTimestamp + tierData.cooldownPeriod, "Cooldown period not elapsed");
        require(pointAmount <= (userData.pointBalance * tierData.claimPercentage) / 100, "Exceeds claimable amount");

        uint256 tokenAmount = pointAmount / baseConversionRate; // Remove the division by 1e18

        _deductPoints(msg.sender, pointAmount);
        xpMigrateContract.mint(msg.sender, tokenAmount);

        emit Claimed(msg.sender, pointAmount, tokenAmount);
    }

    /// @notice Retrieves the data for a specific user
    /// @param user The address of the user to retrieve data for
    /// @return pointBalance The current point balance of the user
    /// @return lastClaimTimestamp The timestamp of the user's last claim
    /// @return tier The current tier of the user
    /// @return consecutiveWeeksClaimed The number of consecutive weeks the user has claimed
    function _getUserData(address user)
        internal
        view
        returns (uint256 pointBalance, uint256 lastClaimTimestamp, uint8 tier, uint8 consecutiveWeeksClaimed)
    {
        UserData memory userData = _userData[user];
        return (userData.pointBalance, userData.lastClaimTimestamp, userData.tier, userData.consecutiveWeeksClaimed);
    }

    function getUserData(address user)
        external
        view
        returns (uint256 pointBalance, uint256 lastClaimTimestamp, uint8 tier, uint8 consecutiveWeeksClaimed)
    {
        return _getUserData(user);
    }

    function getClaimableAmount(address user) public view returns (uint256) {
        (uint256 pointBalance, uint256 lastClaimTimestamp, uint8 tier,) = _getUserData(user);

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
    /// @dev Required by the UUPSUpgradeable contract, can only be called by the owner
    /// @param newImplementation Address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
