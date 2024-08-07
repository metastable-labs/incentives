# Supermigrate Incentives

## Overview

This system manages MIGRATE points, which users earn through various actions, and allows users to claim xpMigrate tokens based on their accumulated points.

## Project Structure

The project consists of several smart contracts:

- `ISupermigrate.sol`: Interface containing shared data structures and enums.
- `Points.sol`: Manages the accumulation and tracking of MIGRATE points.
- `Helper.sol`: Handles multipliers, tier calculations, and bonus mechanisms.
- `xpMigrate.sol`: Implements the soulbound ERC20 token (non-upgradeable).
- `Claim.sol`: Manages the claiming process for xpMigrate tokens.
- Proxy contracts: `PointsProxy.sol`, `HelperProxy.sol`, `ClaimProxy.sol`
- `SupermigrateProxyAdmin.sol`: Manages proxy contracts for upgrades.

## Key Features

- Upgradeable contract system (except for xpMigrate)
- Flexible point accumulation with action-specific multipliers
- Tier-based claiming system with cooldown periods
- Non-transferrable xpMigrate tokens
- Backend-only access for certain critical functions

## Prerequisites

- [Foundry](https://github.com/foundry-rs/foundry)
- Solidity 0.8.x

## Installation

1. Clone the repository:
   ```sh
   git clone https://github.com/your-repo/supermigrate.git
   cd supermigrate
   ```

2. Install dependencies:
   ```sh
   forge install
   ```

## Compilation

Compile the smart contracts using Forge:

```sh
forge build
```

## Testing

Run the test suite using Forge:

```sh
forge test
```

For more verbose output, use:

```sh
forge test -vv
```

## Usage

### For Users

Users interact primarily with the Claim contract to claim their xpMigrate tokens:

1. Accumulate MIGRATE points through various actions (handled by backend).
2. Call the `claim` function on the Claim contract to receive xpMigrate tokens.

### For Administrators

1. Use the SupermigrateProxyAdmin contract to manage upgrades.
2. Update multipliers and tier data through the Helper contract.
3. Adjust the dynamic multiplier for token claims through the Claim contract.

## Upgrading Contracts

To upgrade a contract:

1. Deploy a new implementation contract.
2. Call `upgrade` or `upgradeAndCall` on the SupermigrateProxyAdmin contract, specifying the proxy address and the new implementation address.

## Security Considerations

- Ensure only authorized backends can call restricted functions.
- Regularly audit the contracts, especially after upgrades.
- Use multi-sig wallets for admin functions to enhance security.
- Implement emergency stop mechanisms in case of detected vulnerabilities.
