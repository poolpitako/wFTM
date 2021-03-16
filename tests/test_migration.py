from brownie import Wei


def test_migration(
    wFTM,
    wFTM_whale,
    alice,
    vault,
    strategy,
    fusdVault,
    Strategy,
    strategist,
    gov,
    fMint,
    fStaking,
    fUSD,
    uni,
):
    # Deposit to the vault and harvest
    wFTM.transfer(alice, Wei("1000 ether"), {"from": wFTM_whale})
    wFTM.approve(vault, 2 ** 256 - 1, {"from": alice})
    vault.deposit({"from": alice})

    strategy.harvest({"from": gov})
    assert fusdVault.balanceOf(strategy) > 0

    # migrate to a new strategy
    new_strategy = strategist.deploy(
        Strategy, vault, fMint, fStaking, fUSD, fusdVault, uni
    )
    vault.migrateStrategy(strategy, new_strategy, {"from": gov})
    new_strategy.harvest({"from": strategist})

    assert strategy.balanceOfFusdInVault() == 0
    assert strategy.balanceOfCollateral() == 0
    assert strategy.balanceOfFusd() == 0
    assert new_strategy.balanceOfFusdInVault() > 0
