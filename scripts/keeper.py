import click
import time
from brownie import Contract, accounts, Wei


def main():
    dev = accounts.load(click.prompt("Account", type=click.Choice(accounts.load())))
    print(f"You are using: 'dev' [{dev.address}]")

    s2 = Contract("0x0b1AF58fC47d48dc4E59106B8Ee0e296b73D4565")
    fStaking = Contract("0x073e408E5897b3358edcf130199Cfd895769D3E4")

    while True:
        earned = fStaking.rewardEarned(s2)
        current_ratio = s2.getCurrentRatio()
        print(f"earned: {earned/1e18} ratio: {current_ratio}")

        if earned > Wei("1 ether"):
            s2.harvest({"from": dev, "gas_price": "1 gwei", "gas_limit": "8500000"})
        elif current_ratio < 53000:
            s2.tend({"from": dev, "gas_price": "1 gwei"})

        time.sleep(120)
