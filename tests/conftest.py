import pytest
from brownie import config, Contract, Wei


@pytest.fixture
def gov(accounts):
    yield accounts[0]


@pytest.fixture
def rewards(accounts):
    yield accounts[1]


@pytest.fixture
def guardian(accounts):
    yield accounts[2]


@pytest.fixture
def management(accounts):
    yield accounts[3]


@pytest.fixture
def strategist(accounts):
    yield accounts[4]


@pytest.fixture
def keeper(accounts):
    yield accounts[5]


@pytest.fixture
def alice(accounts):
    yield accounts[6]


@pytest.fixture
def bob(accounts):
    yield accounts[7]


@pytest.fixture
def vault(pm, gov, rewards, guardian, management, wFTM):
    Vault = pm(config["dependencies"][0]).Vault
    vault = guardian.deploy(Vault)
    vault.initialize(wFTM, gov, rewards, "", "", guardian)
    vault.setDepositLimit(2 ** 256 - 1, {"from": gov})
    vault.setManagement(management, {"from": gov})
    vault.setManagementFee(0, {"from": gov})
    yield vault


@pytest.fixture
def strategy(
    strategist, keeper, vault, Strategy, gov, fMint, fStaking, fUSD, fusdVault, uni
):
    strategy = strategist.deploy(Strategy, vault, fMint, fStaking, fUSD, fusdVault, uni)
    strategy.setKeeper(keeper)
    vault.addStrategy(strategy, 10_000, 0, 2 ** 256 - 1, 1_000, {"from": gov})
    yield strategy


@pytest.fixture
def wFTM():
    yield Contract("0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83")


@pytest.fixture
def token(wFTM):
    yield wFTM


@pytest.fixture
def wFTM_whale(accounts):
    yield accounts.at("0xBB634cafEf389cDD03bB276c82738726079FcF2E", force=True)


@pytest.fixture
def fMint():
    yield Contract("0xBB634cafEf389cDD03bB276c82738726079FcF2E")


@pytest.fixture
def mockMint(gov, MockMint, fMint):
    yield gov.deploy(MockMint, fMint)


@pytest.fixture
def fStaking():
    yield Contract("0x073e408E5897b3358edcf130199Cfd895769D3E4")


@pytest.fixture
def fUSD():
    yield Contract("0xAd84341756Bf337f5a0164515b1f6F993D194E1f")


@pytest.fixture
def fUSD_whale(accounts):
    yield accounts.at("0x3bfC4807c49250b7D966018EE596fd9D5C677e3D", force=True)


@pytest.fixture
def uni():
    yield Contract("0x67A937eA41Cd05ec8c832a044afC0100F30Aa4b5")


@pytest.fixture
def fusdVault(accounts):
    vault = Contract("0x4b2de374d480efa96cb093cefcca23d97903a6ea")
    fusd_gov = accounts.at(vault.governance(), force=True)
    vault.setDepositLimit(Wei("1000 ether"), {"from": fusd_gov})
    yield vault
