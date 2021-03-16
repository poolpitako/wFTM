from brownie import Wei


def test_shutdown(wFTM, wFTM_whale, vault, strategy, gov):
    amount = Wei("2000 ether")
    wFTM.transfer(gov, amount, {"from": wFTM_whale})
    wFTM.approve(vault, 2 ** 256 - 1, {"from": gov})
    vault.deposit(amount, {"from": gov})
    strategy.harvest({"from": gov})

    strategy.setEmergencyExit({"from": gov})
    strategy.harvest({"from": gov})

    assert vault.strategies(strategy).dict()["totalDebt"] == 0
    loss = vault.strategies(strategy).dict()["totalLoss"]
    assert loss < Wei("1 ether")
    assert wFTM.balanceOf(vault) == amount - loss
