from brownie import Wei, accounts


def test_revoke(wFTM, wFTM_whale, vault, strategy, gov, fusdVault, fMint):
    amount = Wei("10000 ether")
    wFTM.transfer(gov, amount, {"from": wFTM_whale})
    wFTM.approve(vault, 2 ** 256 - 1, {"from": gov})
    vault.deposit(amount, {"from": gov})

    # Force the limit to 100 fUSD
    fusd_gov = accounts.at(fusdVault.governance(), force=True)
    fusdVault.setDepositLimit(Wei("100 ether"), {"from": fusd_gov})

    # Invest
    strategy.harvest({"from": gov})

    assert fusdVault.availableDepositLimit() == 0
    assert strategy.balanceOfFusdInVault() > 0
    assert strategy.balanceOfDebt() * (10_000 - fMint.getFMintFee4dec()) / 10_000 == fusdVault.depositLimit()