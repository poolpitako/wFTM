// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

// These are the core Yearn libraries
import {BaseStrategy} from "@yearnvaults/contracts/BaseStrategy.sol";
import {
    SafeERC20,
    SafeMath,
    IERC20,
    Address
} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";

import "../interfaces/IFMint.sol";
import "../interfaces/IFStake.sol";
import "../interfaces/IFantomDeFiTokenStorage.sol";
import "../interfaces/Uni.sol";
import "../interfaces/IVault.sol";

contract Strategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    uint256 public RATIO_DECIMALS = 10000;
    uint256 public MAX_RATIO = uint256(-1);
    uint256 public MIN_MINT = 50 * 1e18;

    IFMint public fMint;
    IFStake public fStake;
    IVault public fusdVault;
    Uni public uni;
    address public fUSD;

    constructor(
        address _vault,
        address _fMint,
        address _fStake,
        address _fUSD,
        address _fusdVault,
        address _uni
    ) public BaseStrategy(_vault) {
        fMint = IFMint(_fMint);
        fStake = IFStake(_fStake);
        fusdVault = IVault(_fusdVault);
        uni = Uni(_uni);
        fUSD = _fUSD;

        // for deposit
        IERC20(want).safeApprove(address(fMint), uint256(-1));
        // for paying back debt
        IERC20(fUSD).safeApprove(address(fMint), uint256(-1));
        // To deposit fUSD in the fusd vault
        IERC20(fUSD).safeApprove(address(fusdVault), uint256(-1));
        // To exchange fUSD for wFTM
        IERC20(fUSD).safeApprove(address(uni), uint256(-1));
        // To exchange wFTM for fUSD
        IERC20(want).safeApprove(address(uni), uint256(-1));
    }

    function name() external view override returns (string memory) {
        return "StrategyWftmFusd";
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        // Want + want deposited as collat + reward generated - debt
        // I am not taking into account possible earnings from the fUSD vault
        return
            balanceOfWant()
                .add(balanceOfCollateral())
                .add(wantFutureProfit())
                .sub(debtInWant());
    }

    function prepareReturn(uint256 _debtOutstanding)
        internal
        override
        returns (
            uint256 _profit,
            uint256 _loss,
            uint256 _debtPayment
        )
    {
        if (_debtOutstanding > 0) {
            uint256 _amountFreed = 0;
            (_amountFreed, _loss) = liquidatePosition(_debtOutstanding);
            _debtPayment = Math.min(_amountFreed, _debtOutstanding);
        }

        uint256 balanceOfWantBefore = balanceOfWant();
        claimWftmProfit();
        claimFusdProfit();
        _profit = balanceOfWant().sub(balanceOfWantBefore);
    }

    function claimWftmProfit() internal {
        // Get profit from wFTM staking contract
        // TODO: Check the diff between rewardStash and rewardEarned
        if (fStake.rewardStash(address(this)) > 0) {
            fStake.mustRewardClaim();
        }
    }

    function claimFusdProfit() internal {
        // Still have more debt than profit, wait
        if (balanceOfDebt() >= balanceOfFusdInVault()) {
            return;
        }

        // Withdraw the diff and sell fUSD for want
        uint256 _valueToWithdraw = balanceOfFusdInVault().sub(balanceOfDebt());
        withdrawFromFusdVault(_valueToWithdraw);
        buyWantWithFusd(balanceOfFusd());
    }

    function withdrawFromFusdVault(uint256 _fusd_amount) internal {
        // Don't leave less than MIN_MINT fUSD in the vault
        if (
            _fusd_amount > balanceOfFusdInVault() ||
            balanceOfFusdInVault().sub(_fusd_amount) < MIN_MINT
        ) {
            fusdVault.withdraw();
        } else {
            uint256 _sharesToWithdraw =
                _fusd_amount.mul(1e18).div(fusdVault.pricePerShare());
            fusdVault.withdraw(_sharesToWithdraw);
        }
    }

    function tendTrigger(uint256 callCost) public view override returns (bool) {
        return getCurrentRatio() < getTargetRatio();
    }

    function adjustPosition(uint256 _debtOutstanding) internal override {
        if (emergencyExit) {
            return;
        }

        // If we have debt, prepareReturn will take care of it
        if (_debtOutstanding > balanceOfWant()) {
            return;
        }

        // If there is want available increase the position, it might not
        // mint more fusd but it might add more collateral
        uint256 _wantAvailable = balanceOfWant().sub(_debtOutstanding);
        if (_wantAvailable > 0) {
            increasePosition(_wantAvailable);
        }

        // we might need to reduce our investments
        // Usually because of a price change
        if (getCurrentRatio() < getTargetRatio()) {
            reduceDebt();
        }
    }

    function liquidatePosition(uint256 _amountNeeded)
        internal
        override
        returns (uint256 _liquidatedAmount, uint256 _loss)
    {
        if (balanceOfWant() < _amountNeeded) {
            reduceCollateral(_amountNeeded.sub(balanceOfWant()));
        }

        uint256 totalAssets = balanceOfWant();
        if (_amountNeeded > totalAssets) {
            _liquidatedAmount = totalAssets;
            _loss = _amountNeeded.sub(totalAssets);
        } else {
            _liquidatedAmount = _amountNeeded;
        }
    }

    function prepareMigration(address _newStrategy) internal override {
        // TODO
    }

    function protectedTokens()
        internal
        view
        override
        returns (address[] memory)
    {
        address[] memory protected = new address[](2);
        protected[0] = fUSD;
        protected[1] = address(fusdVault);
        return protected;
    }

    event BalanceOfWant(uint256 amount);
    event BalanceOfDebt(uint256 amount);

    function reduceCollateral(uint256 _amount) internal {
        require(balanceOfCollateral() >= _amount, "Not enough collateral");

        uint256 _targetCollateral = balanceOfCollateral().sub(_amount);
        uint256 _targetDebt = getTargetFusdDebt(_targetCollateral);

        // if we would endup with a small amount of debt, let's get rid of all of it.
        if (_targetDebt < MIN_MINT) {
            _targetDebt = 0;
        }

        reduceDebt(_targetDebt);

        // Since we have a mint fee, we might have never made enough interest
        // to pay back, at this point we would need to sell wFTM for fUSD to
        // take out the collat.
        if (_targetDebt == 0 && balanceOfDebt() > 0) {
            // Withdraw max possible after reducing debt
            fMint.mustWithdrawMax(
                address(want),
                fMint.getCollateralLowestDebtRatio4dec()
            );
            buyFusdWithWant(balanceOfDebt());
            fMint.mustRepayMax(address(fUSD));
        }

        if (_targetDebt == 0) {
            // Let's withdraw all
            fMint.mustWithdrawMax(
                address(want),
                fMint.getCollateralLowestDebtRatio4dec()
            );
        } else {
            fMint.mustWithdraw(address(want), _amount);
        }
    }

    function reduceDebt() internal {
        reduceDebt(getTargetFusdDebt());
    }

    function reduceDebt(uint256 _target) internal {
        uint256 _actual = balanceOfDebt();

        // Debt is already below target, nothing to do
        if (_actual < _target) {
            return;
        }

        uint256 _toPayback = _actual.sub(_target);
        withdrawFromFusdVault(_toPayback);
        fMint.mustRepayMax(address(fUSD));
    }

    function increasePosition(uint256 _amount) internal {
        // deposit collateral and then decide if we should mint fusd
        fMint.mustDeposit(address(want), _amount);

        uint256 _toMint = getAmountToMint();
        if (_toMint == 0) {
            return;
        }

        // We should only mint what we can deposit
        // Because we are not considering the minting fee, we will
        // leave some space
        uint256 _availableLimit = fusdVault.availableDepositLimit();
        fMint.mustMint(address(fUSD), Math.min(_toMint, _availableLimit));
        fusdVault.deposit();
    }

    function buyWantWithFusd(uint256 _amount) internal {
        if (_amount == 0) {
            return;
        }

        address[] memory path = new address[](2);
        path[0] = address(fUSD);
        path[1] = address(want);

        uni.swapExactTokensForTokens(_amount, 0, path, address(this), now);
    }

    function buyFusdWithWant(uint256 _amount) internal {
        if (_amount == 0) {
            return;
        }

        address[] memory path = new address[](2);
        path[0] = address(want);
        path[1] = address(fUSD);

        uni.swapTokensForExactTokens(
            _amount,
            uint256(-1),
            path,
            address(this),
            now
        );
    }

    function getAmountToMint() public view returns (uint256) {
        if (getCurrentRatio() <= getTargetRatio()) {
            return 0;
        }

        uint256 _targetDebt = getTargetFusdDebt();
        uint256 _debt = balanceOfDebt();
        uint256 _toMint = _targetDebt.sub(_debt);
        uint256 _mintFee =
            _toMint.mul(fMint.getFMintFee4dec()).div(RATIO_DECIMALS);
        uint256 _finalMintAmount = _toMint.sub(_mintFee);

        if (_finalMintAmount > MIN_MINT) {
            return _finalMintAmount;
        } else {
            return 0;
        }
    }

    function getTargetFusdDebt() public view returns (uint256) {
        return getTargetFusdDebt(balanceOfCollateral());
    }

    function getTargetFusdDebt(uint256 _collateral)
        public
        view
        returns (uint256)
    {
        // target fusd debt
        // (wftm_in_collateral * wftm_price) / (target_ratio / 100)
        uint256 collateral = _collateral.mul(fMint.getPrice(address(want)));
        return collateral.div(getTargetRatio().mul(1e18).div(RATIO_DECIMALS));
    }

    function getCurrentRatio() public view returns (uint256) {
        // 100 * (wftm_in_collateral * wftm_price) / debt_in_fusd

        uint256 debt = balanceOfDebt();
        // If we don't have debt, we have unlimited ratio
        if (debt == 0) {
            return MAX_RATIO;
        }

        uint256 collateral =
            balanceOfCollateral().mul(fMint.getPrice(address(want)));
        return uint256(RATIO_DECIMALS).mul(collateral).div(debt).div(1e18);
    }

    function getTargetRatio() public view returns (uint256) {
        // We do 10% above the eligibility for reward ratio
        return
            fMint.getRewardEligibilityRatio4dec().mul(11000).div(
                RATIO_DECIMALS
            );
    }

    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    function balanceOfFusd() public view returns (uint256) {
        return IERC20(fUSD).balanceOf(address(this));
    }

    function balanceOfCollateral() public view returns (uint256) {
        return
            fMint.getCollateralPool().balanceOf(address(this), address(want));
    }

    function balanceOfDebt() public view returns (uint256) {
        return fMint.debtValueOf(address(this), fUSD, 0);
    }

    function balanceOfFusdInVault() public view returns (uint256) {
        return
            fusdVault
                .balanceOf(address(this))
                .mul(fusdVault.pricePerShare())
                .div(1e18);
    }

    function wantFutureProfit() public view returns (uint256) {
        return fStake.rewardStash(address(this));
    }

    function debtInWant() public view returns (uint256) {
        uint256 _debt = balanceOfDebt();
        if (_debt == 0) {
            return 0;
        }

        return _debt.div(fMint.getPrice(address(want))).mul(1e18);
    }
}
