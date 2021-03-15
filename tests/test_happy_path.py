import brownie
from brownie import Contract, Wei


def test_operation(
    chain,
    gov,
    vault,
    strategy,
    wFTM,
    wFTM_whale,
    alice,
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

    assert strategy.getCurrentRatio() >= strategy.getTargetRatio()
    assert fusdVault.balanceOf(strategy) > 0

    chain.sleep(604800)  # 1 week
    chain.mine(1)

    # Donate some fUSD to the fusdVault to mock earnings
    fUSD.transfer(fusdVault, Wei("10 ether"), {"from": fUSD_whale})

    # Run Harvest
    strategy.harvest({"from": gov})
    chain.sleep(604800)  # 1 week
    chain.mine(1)

    vault.withdraw({"from": alice})

    assert wFTM.balanceOf(alice) > Wei("1000 ether")
    assert strategy.balanceOfCollateral() == 0
    assert strategy.balanceOfDebt() == 0
    assert strategy.balanceOfFusd() == 0
    assert strategy.balanceOfFusdInVault() == 0
    assert fusdVault.totalAssets() == 0
