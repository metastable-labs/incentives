// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "./interfaces/IHelper.sol";

/// @title Points Contract for Incentive system
/// @notice This contract manages the point system for users in the Supermigrate ecosystem
/// @dev This contract is upgradeable and uses OpenZeppelin's upgradeable contracts
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

    /// @notice Address of the helper contract
    address public helperContract;

    /// @notice Address of the backend service authorized to call certain functions
    address public backendService;

    /// @notice Emitted when a user earns points
    /// @param user The address of the user earning points
    /// @param amount The amount of points earned
    /// @param actionType The type of action that earned the points
    event PointsEarned(address indexed user, uint256 amount, ActionType actionType);

    /// @notice Emitted when points are deducted from a user
    /// @param user The address of the user losing points
    /// @param amount The amount of points deducted
    /// @param reason The reason for the point deduction
    event PointsDeducted(address indexed user, uint256 amount, string reason);

    /// @notice Initializes the contract
    /// @dev Sets up the initial state and sets the backend service address
    /// @param _backendService Address of the backend service
    function initialize(address _backendService) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();
        backendService = _backendService;
    }

    /// @notice Modifier to restrict function access to only the backend service
    modifier onlyBackend() {
        require(msg.sender == backendService, "Only backend can call this function");
        _;
    }

    /// @notice Sets the address of the helper contract
    /// @dev Can only be called by the contract owner
    /// @param _helperContract The address of the new helper contract
    function setHelperContract(address _helperContract) external onlyOwner {
        helperContract = _helperContract;
    }

    /// @notice Allows users to earn points for various actions
    /// @dev Can only be called by the backend service when the contract is not paused
    /// @param user The address of the user earning points
    /// @param amount The base amount of points to be earned
    /// @param actionType The type of action performed to earn points
    /// @param isStaked Boolean indicating if the action involves staked tokens
    /// @param isFeaturedToken Boolean indicating if the action involves featured tokens
    /// @param isMigratedToken Boolean indicating if the action involves migrated tokens
    function earnPoints(
        address user,
        uint256 amount,
        ActionType actionType,
        bool isStaked,
        bool isFeaturedToken,
        bool isMigratedToken
    ) external onlyBackend whenNotPaused {
        uint256 basePoints;
        uint256 multiplier;

        if (actionType == ActionType.LIQUIDITY_MIGRATION) {
            basePoints = (amount * 1000) / 10; // 1000 points per $10
            multiplier = isStaked ? 250 : 100; // 2.5x for staked, 1x for non-staked
        } else if (actionType == ActionType.BRIDGING) {
            basePoints = amount * 500; // 500 points per $1
            if (isMigratedToken) {
                multiplier = 300; // 3x for migrated tokens
            } else if (isFeaturedToken) {
                multiplier = 150; // 1.5x for featured tokens
            } else {
                multiplier = 100; // 1x for normal tokens
            }
        } else {
            basePoints = amount;
            multiplier = 100; // 1x for other actions
        }

        uint256 totalPoints = (basePoints * multiplier) / 100;
        _userData[user].pointBalance += totalPoints;
        _userData[user].tier = IHelper(helperContract).calculateTier(_userData[user].pointBalance);
        emit PointsEarned(user, totalPoints, actionType);
    }

    /// @notice Deducts points from a user
    /// @dev Can only be called by the backend service when the contract is not paused
    /// @param user The address of the user to deduct points from
    /// @param amount The amount of points to deduct
    /// @param reason The reason for deducting points
    function deductPoints(address user, uint256 amount, string calldata reason) external onlyBackend whenNotPaused {
        require(_userData[user].pointBalance >= amount, "Insufficient points");
        _userData[user].pointBalance -= amount;
        _userData[user].tier = IHelper(helperContract).calculateTier(_userData[user].pointBalance);
        emit PointsDeducted(user, amount, reason);
    }

    /// @notice Retrieves the data for a specific user
    /// @param user The address of the user to retrieve data for
    /// @return pointBalance The current point balance of the user
    /// @return lastClaimTimestamp The timestamp of the user's last claim
    /// @return tier The current tier of the user
    /// @return consecutiveWeeksClaimed The number of consecutive weeks the user has claimed
    function getUserData(address user)
        external
        view
        returns (uint256 pointBalance, uint256 lastClaimTimestamp, uint8 tier, uint8 consecutiveWeeksClaimed)
    {
        UserData memory userData = _userData[user];
        return (userData.pointBalance, userData.lastClaimTimestamp, userData.tier, userData.consecutiveWeeksClaimed);
    }

    /// @notice Function to authorize an upgrade
    /// @dev Required by the UUPSUpgradeable contract, can only be called by the owner
    /// @param newImplementation Address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
