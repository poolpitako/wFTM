import brownie
from brownie import Wei, accounts


def test_allow_list(gov, alice, fusdVault, allow_list, bob, fUSD, fUSD_whale):

    # Update the fusd vault
    fusd_gov = accounts.at(fusdVault.governance(), force=True)
    fusdVault.setGuestList(allow_list, {"from": fusd_gov})
    fusdVault.setDepositLimit(2 ** 256 - 1, {"from": fusd_gov})

    # Approve Alice and whale on the fusdVault
    fUSD.approve(fusdVault, 2 ** 256 - 1, {"from": alice})
    fUSD.approve(fusdVault, 2 ** 256 - 1, {"from": fUSD_whale})

    # Transfer some money to alice and test if she can deposit
    fUSD.transfer(alice, Wei("100 ether"), {"from": fUSD_whale})
    assert allow_list.authorized(alice, 1) == False
    with brownie.reverts():
        fusdVault.deposit({"from": alice})

    # Afer being invited she should be able to deposit!
    tx = allow_list.invite_guest(alice, {"from": gov})
    assert tx.events["GuestInvited"]["guest"] == alice
    fusdVault.deposit({"from": alice})

    # Whale is not allowed to join the party...
    assert allow_list.authorized(fUSD_whale, 1) == False
    with brownie.reverts():
        fusdVault.deposit({"from": fUSD_whale})

    # Until Bob is added as bouncer and invites the whale
    tx = allow_list.add_bouncer(bob, {"from": gov})
    assert tx.events["BouncerAdded"]["bouncer"] == bob
    allow_list.invite_guest(fUSD_whale, {"from": bob})

    # Whale does whale things
    fusdVault.deposit({"from": fUSD_whale})
