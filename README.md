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

Perpetuals are essentially just a way for a trader to bet on the price of a certain index token without actually buying the token while enabling the trader to employ leverage.

This Perpetuals Protocol allows traders to open, manage and close positions on Base, utilizing liquidity provided on Arbitrum via Chainlink CCIP. Traders must deposit collateral in the form of Circle's USDC to open a position. USDC is also the token deposited by liquidity providers.

Managing a position refers to increasing or decreasing the size or collateral of the position.

The entire protocol revolves around “positions” that belong to traders, a position is made up of the following:

- Size - This is how much “virtual” capital a trader is commanding, the size of a BTC perpetual position might be 1.5 BTC. If the price of BTC goes up, the trader is able to realize the profits earned on the 1.5 BTC in their position.
- Collateral - An amount of assets used to “back” a trader’s position, when trader’s lose money, their losses come out of the collateral. If the amount of collateral is deemed insufficient for the size of a position, the position is _liquidated_ or force closed.

The `size / collateral` is the _leverage_ of a position. E.g. if I open a position with $10,000 of USDC as collateral and a size of $20,000 of BTC, my leverage is 2x.

A profitable position can be kept open in perpetuity, whereas if the position's value drops to such a degree that the trader's collateral no longer sufficiently justifies their position, they will be automatically liquidated via Chainlink Automation. Liquidated collateral is added to the provided liquidity in the `Vault`, incentivising liquidity providers to potentially earn on their deposits.

There are two different _directions_ a perpetual position can take.

- Long → The trader profits when the price of the _index token_ goes up, and loses when the price of the _index token_ go down.
- Short → The trader profits when the price of the _index token_ goes down, and loses when the price of the _index token_ goes up.

It is possible for any external address to liquidate an eligible position, receiving a liquidation bonus of 20% of any remaining collateral. However it is unlikely for external liquidators to execute liquidations before the `AutomatedLiquidator`.

Chainlink pricefeeds are used to get the price of the asset being speculated on.

Open interest is the measure of the aggregate size of all open positions.

Liquidity Providers are unable to withdraw liquidity reserved for profitable positions.

Liquidity reserves are necessary such that at all times there are enough assets in the liquidity pool (provided by liquidity providers) to pay out the profits for positions.

If there is only 10 USDC of liquidity deposited by liquidity providers, then allowing a trader to open a perpetual contract with $10,000 of size would be irresponsible. If the price moves even a little bit in the trader’s direction they will be more than $10 in profit, yet there will not be enough USDC to pay them out.

## Contracts

The system consists of 5 contracts:

- Positions (Base)
- CCIPPositionsManager (Base)
- AutomatedLiquidator (Base)
- Vault (Arbitrum)
- CCIPVaultManager (Arbitrum)

### Positions and Vault

Traders open, manage and close their positions with the `Positions` contract. Liquidity Providers deposit and withdraw with the `Vault` contract, which for now is based on the ERC4626 standard.

Traders are expected to interact with the following functions:

- `Positions::openPosition`
- `Positions::increaseSize`
- `Positions::increaseCollateral`
- `Positions::decreaseSize`
- `Positions::decreaseCollateral`

Similarly to increasing the size of a position, traders have the ability to decrease the size of their position, this includes closing their position (decreasing the size to 0).

However, decreasing a position is slightly more involved, we need to consider the PnL of the trader’s position when we are decreasing it.

If we don’t account for a trader’s PnL and allow them to decrease their size, they could manipulate their PnL and avoid paying losses! Additionally, decreasing the PnL this way reduces the probability that a trader will unexpectedly change the leverage of their remaining position drastically.

The `realizedPnL` is deducted from the position’s USDC collateral if it is a loss, and paid out to the trader in Circle's USDC token if it is a profit.

This way, if a trader decreases their position’s size by 50%, they realize 50% of their PnL.

And if a trader closes their position (e.g. decreases by 100% of the size), they realize 100% of their PnL.

If a trader decreases the size of their position to 0, the position is considered closed and the remaining collateral (after losses) is sent back to the trader.

Liquidity Providers are expected to interact with the following functions:

- `Vault::deposit`
- `Vault::withdraw`

### CCIP Managers

The CCIP Manager contracts on their respective chains handle sending cross chain messages and value. The `CCIPPositionsManager` on Base holds traders' collateral and receives messages from `CCIPVaultManager` with updates to how much liquidity is available for traders to utilize, as well as USDC tokens via CCIP/CCTP for profitable traders. Conversely, `CCIPVaultManager` on Arbitrum receives messages from `CCIPPositionsManager` with updates as to how positions are being managed and therefore how much liquidity is reserved for traders. The Vault Manager also receives liquidated collateral and adds it to the liquidity provided in the vault.

### AutomatedLiquidator

Chainlink's offchain Automation nodes are used to loop through the positions, checking for any that have exceeded the maximum leverage threshold, liquidating the ones that have violated this threshold based on pricefeed data, and the size and collateral of the position.

If the `AutomatedLiquidator` receives a liquidation bonus (20% of any remaining collateral), this value will compound, eventually using Chainlink Automation to swap the USDC for LINK via Uniswap V4 (although I didn't finish this part), and funding the Automation subscription, thus being self-sufficient.

This contract is automatically registered with Automation on deployment.

**What makes a position liquidatable?**

A position becomes liquidatable when its collateral is deemed insufficient to support the size of position that is open.

For our implementations we will use a _leverage_ check to define whether a position is liquidatable or not:

```
leverage = size / collateral
```

Leverage is simply the ratio of the position’s size to the position’s collateral. The `MAXIMUM_LEVERAGE` is the cutoff point for the maximum leverage a position can have before it is considered liquidatable.

During liquidation, a position is force closed so that the protocol can remain solvent.

## Roles

- Trader: A user who has a perpetual position
- Liquidity Provider: Someone who provides liquidity to the system

Traders are the actors opening perpetual positions and betting on the price of the _index token_.

Traders profit when the price of the _index token_ moves in the direction they predict, and lose when it moves in the direction opposite to what they predict.

Traders must provide collateral for their _position,_ the collateral is used to cover their losses in the event that price moves in the opposite direction of what they predicted.

Liquidity providers take the opposite side of traders, they stand to profit when traders lose money or are liquidated.

Liquidity providers provide the assets that are used to pay out profit for traders. When a trader profits they get tokens from the liquidity providers. When a trader loses, they pay tokens to the liquidity providers out of their position’s collateral.

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
