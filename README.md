# Palmcivet Perpetuals

This Perpetuals Protocol allows traders to open, manage and close perpetual positions on Base, utilizing liquidity on Arbitrum.

## Table of Contents

- [Palmcivet Perpetuals](#palmcivet-perpetuals)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Contracts](#contracts)
    - [Positions and Vault](#positions-and-vault)
    - [CCIP Managers](#ccip-managers)
    - [AutomatedLiquidator](#automatedliquidator)
  - [Roles](#roles)
  - [Known Issues](#known-issues)
  - [Deployments](#deployments)
  - [Additional Comments](#additional-comments)
  - [License](#license)

## Overview

This Perpetuals Protocol allows traders to open, manage and close positions on Base, utilizing liquidity provided on Arbitrum via Chainlink CCIP. Traders must deposit collateral in the form of Circle's USDC to open a position. USDC is also the token deposited by liquidity providers.

Managing a position refers to increasing or decreasing the size or collateral of the position.

A profitable position can be kept open in perpetuity, whereas if the position's value drops to such a degree that the trader's collateral no longer sufficiently justifies their position, they will be automatically liquidated via Chainlink Automation. Liquidated collateral is added to the provided liquidity in the `Vault`, incentivising liquidity providers to potentially earn on their deposits.

It is possible for any external address to liquidate an eligible position, receiving a liquidation bonus of 20% of any remaining collateral. However it is unlikely for external liquidators to execute liquidations before the `AutomatedLiquidator`.

Liquidity Providers are unable to withdraw liquidity reserved for profitable positions.

Chainlink and Pyth pricefeeds are combined to get an average price of the asset being speculated on.

Positions can only be opened by users with unique Worldcoin IDs. Open positions are limited to one per WorldID. This is to mitigate manipulation of the system by bots.

## Contracts

The system consists of 5 contracts:

- Positions (Chain A)
- CCIPPositionsManager (Chain A)
- AutomatedLiquidator (Chain A)
- Vault (Chain B)
- CCIPVaultManager (Chain B)

### Positions and Vault

Traders open, manage and close their positions with the `Positions` contract. Liquidity Providers deposit and withdraw with the `Vault` contract, which for now is based on the ERC4626 standard.

Traders are expected to interact with the following functions:

- `Positions::openPosition`
- `Positions::increaseSize`
- `Positions::increaseCollateral`
- `Positions::decreaseSize`
- `Positions::decreaseCollateral`

Liquidity Providers are expected to interact with the following functions:

- `Vault::deposit`
- `Vault::withdraw`

### CCIP Managers

The CCIP Manager contracts on their respective chains handle sending cross chain messages and value. The `CCIPPositionsManager` on Base holds traders' collateral and receives messages from `CCIPVaultManager` with updates to how much liquidity is available for traders to utilize, as well as USDC tokens via CCIP/CCTP for profitable traders. Conversely, `CCIPVaultManager` on Arbitrum receives messages from `CCIPPositionsManager` with updates as to how positions are being managed and therefore how much liquidity is reserved for traders. The Vault Manager also receives liquidated collateral and adds it to the liquidity provided in the vault.

### AutomatedLiquidator

Chainlink's offchain Automation nodes are used to loop through the positions, checking for any that have exceeded the maximum leverage threshold, liquidating the ones that have violated this threshold based on pricefeed data, and the size and collateral of the position.

If the `AutomatedLiquidator` receives a liquidation bonus (20% of any remaining collateral), this value will compound, eventually using Chainlink Automation to swap the USDC for LINK via Uniswap V4 (although I didn't finish this part), and funding the Automation subscription, thus being self-sufficient.

This contract is automatically registered with Automatiom on deployment.

## Roles

- Trader: A unique WorldID user who has a perpetual position and
- Liquidity Provider: Someone who provides liquidity to the system

## Known Issues

- The ERC4626 standard is vulnerable to inflation attacks. A potential mitigation would be to deposit before a malicious user. Another would be to develop a custom vault contract for this system instead.

## Deployments

Base:

```
Positions: 0xAa829eabEC1ec37033c7eFF60C4527Dcf510E28d
CCIPPositionsManager: 0xC72F72Cecf4D00E4Cb7c999215c6EAF4A8e61A30
```

Arbitrum:

```
Vault: 0x88F32280155046f54c24fa0Dd0d176E4e0Ccad7A
CCIPVaultManager: 0x3EBFE1f7D17c8F6B3fC8Dc5424aE9aaECb227EA3
```

Deposit tx: https://sepolia.arbiscan.io/tx/0x24ab9b8d8f5e35f30bc800bc3911a5c045302cae674713bfecad2cb22c3c752c

CCIP tx updating the liquidity across chains: https://ccip.chain.link/msg/0xb5f3351600fabf1bd1632c23f4a50aac39df62fdba933662c451d218de420e31

Base tx: https://sepolia.basescan.org/tx/0xd400c123ee2aad79e8c08073b143b7139b7ba5b44969a6c8dbcab6b4d8b1148a
https://sepolia.basescan.org/tx/0xd400c123ee2aad79e8c08073b143b7139b7ba5b44969a6c8dbcab6b4d8b1148a#eventlog

## Additional Comments

I spent hours trying to verify the contracts through Foundry, Hardhat, Tenderly, Remix and manually on the block explorer and I was unable to due to a slight difference in bytecode. I tried flattening the contracts and using https://abi.hashex.org/ as well as cast abi-encode for the constructor args. For whatever reason I wasn't able to verify and it was extremely frustrating.

## License

This project is licensed under the [MIT License](https://opensource.org/license/mit/).
