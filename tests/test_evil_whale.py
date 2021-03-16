import brownie
from brownie import Wei, accounts


def test_evil_whale(
    chain,
    gov,
    vault,
    rewards,
    strategist,
    strategy,
    wFTM,
    wFTM_whale,
    alice,
    bob,
    fUSD,
    fusdVault,
    fUSD_whale,
):
    # First we need to make the fUSD vault unlimited
    fusd_gov = accounts.at(fusdVault.governance(), force=True)
    fusdVault.setDepositLimit(2 ** 256 - 1, {"from": fusd_gov})

    # Alice is going to be the pleb
    wFTM.transfer(alice, Wei("1000 ether"), {"from": wFTM_whale})
    wFTM.approve(vault, 2 ** 256 - 1, {"from": alice})
    vault.deposit({"from": alice})

    # Bob is going to play the evil whale!
    wFTM.transfer(bob, Wei("10000000 ether"), {"from": wFTM_whale})
    wFTM.approve(vault, 2 ** 256 - 1, {"from": bob})
    vault.deposit({"from": bob})

    # harvest
    strategy.harvest({"from": gov})
    chain.sleep(604800)  # 1 week
    chain.mine(1)

    # if he wants to withdraw he needs to take a loss
    tx = vault.withdraw(vault.balanceOf(bob), bob, 10_000, {"from": bob})
    assert wFTM.balanceOf(bob) < Wei("10000000 ether")
    assert strategy.getCurrentRatio() == strategy.getTargetRatio()
