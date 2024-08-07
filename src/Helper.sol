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

    mapping(uint8 => Tier) private _tiers;
    address public backendService;

    function initialize(address _backendService) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        backendService = _backendService;

        // Initialize default tiers
        _tiers[0] = Tier(0, 50, 1 days);
        _tiers[1] = Tier(1000, 75, 12 hours);
        _tiers[2] = Tier(5000, 100, 0);
    }

    modifier onlyBackend() {
        require(msg.sender == backendService, "Only backend can call this function");
        _;
    }

    function setTier(uint8 tierLevel, Tier memory newTier) external onlyBackend {
        _tiers[tierLevel] = newTier;
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
