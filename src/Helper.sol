// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title Helper Contract for Incentive system
/// @notice This contract manages tiers and provides helper functions for the Supermigrate system
/// @dev This contract is upgradeable and uses OpenZeppelin's upgradeable contracts
contract Helper is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    /// @notice Struct to define tier properties
    /// @param requiredPoints The minimum points required to reach this tier
    /// @param claimPercentage The percentage of points that can be claimed at once in this tier
    /// @param cooldownPeriod The waiting period between claims for this tier
    struct Tier {
        uint256 requiredPoints;
        uint256 claimPercentage;
        uint256 cooldownPeriod;
    }

    /// @notice Mapping to store tier data
    /// @dev Key is the tier level (0 for Bronze, 1 for Silver, 2 for Gold)
    mapping(uint8 => Tier) private _tiers;

    /// @notice Address of the backend service authorized to call certain functions
    address public backendService;

    /// @notice Initializes the contract
    /// @dev Sets up the initial tiers and sets the backend service address
    /// @param _backendService Address of the backend service
    function initialize(address _backendService) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        backendService = _backendService;

        // Initialize default tiers
        _tiers[0] = Tier(0, 50, 1 days);
        _tiers[1] = Tier(1000, 75, 12 hours);
        _tiers[2] = Tier(5000, 100, 0);
    }

    /// @notice Modifier to restrict function access to only the backend service
    modifier onlyBackend() {
        require(msg.sender == backendService, "Only backend can call this function");
        _;
    }

    /// @notice Sets the properties for a specific tier
    /// @dev Can only be called by the backend service
    /// @param tierLevel The level of the tier to be set (0 for Bronze, 1 for Silver, 2 for Gold)
    /// @param newTier The new tier data to be set
    function setTier(uint8 tierLevel, Tier memory newTier) external onlyBackend {
        _tiers[tierLevel] = newTier;
    }

    /// @notice Calculates the tier level based on the point balance
    /// @param pointBalance The current point balance of the user
    /// @return The tier level (0 for Bronze, 1 for Silver, 2 for Gold)
    function calculateTier(uint256 pointBalance) external view returns (uint8) {
        if (pointBalance >= _tiers[2].requiredPoints) {
            return 2; // GOLD
        } else if (pointBalance >= _tiers[1].requiredPoints) {
            return 1; // SILVER
        } else {
            return 0; // BRONZE
        }
    }

    /// @notice Retrieves the data for a specific tier
    /// @param tierLevel The level of the tier to retrieve data for
    /// @return requiredPoints The minimum points required for this tier
    /// @return claimPercentage The percentage of points that can be claimed at once in this tier
    /// @return cooldownPeriod The waiting period between claims for this tier
    function getTierData(uint8 tierLevel)
        external
        view
        returns (uint256 requiredPoints, uint256 claimPercentage, uint256 cooldownPeriod)
    {
        Tier memory tier = _tiers[tierLevel];
        return (tier.requiredPoints, tier.claimPercentage, tier.cooldownPeriod);
    }

    /// @notice Function to authorize an upgrade
    /// @dev Required by the UUPSUpgradeable contract
    /// @param newImplementation Address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
