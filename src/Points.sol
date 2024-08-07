// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "./interfaces/IHelper.sol";

contract Points is Initializable, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    struct UserData {
        uint256 pointBalance;
        uint256 lastClaimTimestamp;
        uint8 tier;
        uint8 consecutiveWeeksClaimed;
    }

    enum ActionType {
        LIQUIDITY_MIGRATION,
        BRIDGING,
        SOCIAL_INTERACTION,
        NFT_MINT,
        REFERRAL
    }

    mapping(address => UserData) private _userData;
    address public helperContract;
    address public backendService;

    event PointsEarned(address indexed user, uint256 amount, ActionType actionType);
    event PointsDeducted(address indexed user, uint256 amount, string reason);

    function initialize(address _backendService) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();
        backendService = _backendService;
    }

    modifier onlyBackend() {
        require(msg.sender == backendService, "Only backend can call this function");
        _;
    }

    function setHelperContract(address _helperContract) external onlyOwner {
        helperContract = _helperContract;
    }

    function earnPoints(address user, uint256 amount, ActionType actionType) external onlyBackend whenNotPaused {
        uint256 multipliedAmount = IHelper(helperContract).applyMultiplier(amount, uint8(actionType));
        _userData[user].pointBalance += multipliedAmount;
        _userData[user].tier = IHelper(helperContract).calculateTier(_userData[user].pointBalance);
        emit PointsEarned(user, multipliedAmount, actionType);
    }

    function deductPoints(address user, uint256 amount, string calldata reason) external onlyBackend whenNotPaused {
        require(_userData[user].pointBalance >= amount, "Insufficient points");
        _userData[user].pointBalance -= amount;
        _userData[user].tier = IHelper(helperContract).calculateTier(_userData[user].pointBalance);
        emit PointsDeducted(user, amount, reason);
    }

    function getUserData(address user)
        external
        view
        returns (uint256 pointBalance, uint256 lastClaimTimestamp, uint8 tier, uint8 consecutiveWeeksClaimed)
    {
        UserData memory userData = _userData[user];
        return (userData.pointBalance, userData.lastClaimTimestamp, userData.tier, userData.consecutiveWeeksClaimed);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
