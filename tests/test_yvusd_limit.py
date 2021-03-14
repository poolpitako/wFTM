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

    # We are not taking into account the minting fee so there will be some
    # space left in the vault
    assert fusdVault.availableDepositLimit() <= Wei("0.51 ether")
    assert strategy.balanceOfFusdInVault() > 0
    assert strategy.balanceOfDebt() / 1e18 == Wei("100 ether") / 1e18
