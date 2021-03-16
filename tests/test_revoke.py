from brownie import Wei


def test_revoke(wFTM, wFTM_whale, vault, strategy, gov):
    amount = Wei("2000 ether")
    wFTM.transfer(gov, amount, {"from": wFTM_whale})
    wFTM.approve(vault, 2 ** 256 - 1, {"from": gov})
    vault.deposit(amount, {"from": gov})
    strategy.harvest({"from": gov})

    vault.revokeStrategy(strategy, {"from": gov})
    t = strategy.harvest({"from": gov})
    assert wFTM.balanceOf(vault) < amount
    assert wFTM.balanceOf(vault) > amount * 0.95
