from brownie import Wei


def test_increasing_ratio(wFTM, wFTM_whale, vault, strategy, gov, fusdVault, fMint):
    amount = Wei("2000 ether")
    wFTM.transfer(gov, amount, {"from": wFTM_whale})
    wFTM.approve(vault, 2 ** 256 - 1, {"from": gov})
    vault.deposit(amount, {"from": gov})

    # start with 50%
    vault.updateStrategyDebtRatio(strategy, 5_000, {"from": gov})

    strategy.harvest({"from": gov})
    assert strategy.balanceOfCollateral() == Wei("1000 ether")
    assert strategy.balanceOfDebt() > 0

    # Move up to 100%
    vault.updateStrategyDebtRatio(strategy, 10_000, {"from": gov})
    strategy.harvest({"from": gov})
    assert strategy.balanceOfCollateral() == Wei("2000 ether")
    assert strategy.balanceOfDebt() > 0

    # Return everything
    vault.updateStrategyDebtRatio(strategy, 0, {"from": gov})
    strategy.harvest({"from": gov})
    assert strategy.balanceOfCollateral() <= Wei("0.0001 ether")
    assert vault.strategies(strategy).dict()["totalDebt"] == 0
