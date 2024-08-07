// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Helper is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    struct MultiplierData {
        uint256 liquidityMigrationMultiplier;
        uint256 bridgingMultiplier;
        uint256 socialMultiplier;
    }

    struct Tier {
        uint256 requiredPoints;
        uint256 claimPercentage;
        uint256 cooldownPeriod;
    }

    MultiplierData private _multipliers;
    mapping(uint8 => Tier) private _tiers;
    address public backendService;

    function initialize(address _backendService) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        backendService = _backendService;

        // Initialize default multipliers and tiers
        _multipliers = MultiplierData(1e18, 1e18, 1e18); // 1x multiplier for all actions
        _tiers[0] = Tier(0, 50, 1 days);
        _tiers[1] = Tier(1000, 75, 12 hours);
        _tiers[2] = Tier(5000, 100, 0);
    }

    modifier onlyBackend() {
        require(msg.sender == backendService, "Only backend can call this function");
        _;
    }

    function setMultipliers(MultiplierData memory newMultipliers) external onlyBackend {
        _multipliers = newMultipliers;
    }

    function setTier(uint8 tierLevel, Tier memory newTier) external onlyBackend {
        _tiers[tierLevel] = newTier;
    }

    function applyMultiplier(uint256 amount, uint8 actionType) external view returns (uint256) {
        uint256 multiplier = 1e18; // Default 1x multiplier
        if (actionType == 0) {
            multiplier = _multipliers.liquidityMigrationMultiplier;
        } else if (actionType == 1) {
            multiplier = _multipliers.bridgingMultiplier;
        } else if (actionType == 2) {
            multiplier = _multipliers.socialMultiplier;
        }
        return (amount * multiplier) / 1e18;
    }

    function calculateTier(uint256 pointBalance) external view returns (uint8) {
        if (pointBalance >= _tiers[2].requiredPoints) {
            return 2; // GOLD
        } else if (pointBalance >= _tiers[1].requiredPoints) {
            return 1; // SILVER
        } else {
            return 0; // BRONZE
        }
    }

    function getTierData(uint8 tierLevel)
        external
        view
        returns (uint256 requiredPoints, uint256 claimPercentage, uint256 cooldownPeriod)
    {
        Tier memory tier = _tiers[tierLevel];
        return (tier.requiredPoints, tier.claimPercentage, tier.cooldownPeriod);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
