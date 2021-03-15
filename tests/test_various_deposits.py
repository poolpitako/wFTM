import brownie
from brownie import Contract, Wei


def test_happy_path(
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
    fMint,
    fStaking,
):
    wFTM.transfer(alice, Wei("1000 ether"), {"from": wFTM_whale})
    wFTM.approve(vault, 2 ** 256 - 1, {"from": alice})
    vault.deposit({"from": alice})

    # harvest
    strategy.harvest({"from": gov})
    chain.sleep(604800)  # 1 week
    chain.mine(1)

    # Donate some fUSD to the fusdVault to mock earnings
    fUSD.transfer(fusdVault, Wei("10 ether"), {"from": fUSD_whale})


    wFTM.transfer(bob, Wei("2000 ether"), {"from": wFTM_whale})
    wFTM.approve(vault, 2 ** 256 - 1, {"from": bob})
    vault.deposit({"from": bob})

    # Run Harvest
    strategy.harvest({"from": gov})
    chain.sleep(604800)  # 1 week
    chain.mine(1)
    vault.withdraw({"from": alice})

    # Donate some fUSD to the fusdVault to mock earnings
    fUSD.transfer(fusdVault, Wei("100 ether"), {"from": fUSD_whale})
    # Run Harvest
    strategy.harvest({"from": gov})
    chain.sleep(604800)  # 1 week
    chain.mine(1)
    vault.withdraw({"from": bob})

    assert wFTM.balanceOf(alice) > Wei("1000 ether")
    assert wFTM.balanceOf(bob) > Wei("1000 ether")
    assert strategy.balanceOfCollateral() == 0
    assert strategy.balanceOfDebt() == 0
    assert strategy.balanceOfFusd() == 0
    assert strategy.balanceOfFusdInVault() == 0
    assert fusdVault.totalAssets() == 0
