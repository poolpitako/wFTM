import brownie
from brownie import Contract, Wei


def test_operation(vault, strategy, wFTM, strategist, wFTM_whale, alice, fMint, fUSD, fStaking):
    wFTM.transfer(alice, Wei("100 ether"), {"from": wFTM_whale})
    wFTM.approve(vault, 2 ** 256 -1, {"from": alice})

    #wFTM.approve(fMint, 2 ** 256 -1, {'from': alice})
    #fMint.mustDeposit(wFTM, wFTM.balanceOf(alice), {'from': alice})


    vault.deposit({"from": alice})

    # harvest
    strategy.harvest()
    assert 1==2
    assert token.balanceOf(strategy.address) == amount

    # tend()
    strategy.tend()

    # withdrawal
    vault.withdraw({"from": accounts[0]})
    assert token.balanceOf(accounts[0]) != 0
