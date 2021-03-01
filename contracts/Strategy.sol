// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

// These are the core Yearn libraries
import {BaseStrategy, VaultAPI} from "@yearnvaults/contracts/BaseStrategy.sol";
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

contract Strategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    uint256 public BASE = 1000;
    uint256 public MAX_RATIO = uint256(-1);
    uint256 public MIN_MINT = 50 * 1e18;

    IFMint public fMint;
    IFStake public fStake;
    VaultAPI public fusdVault;
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
        fusdVault = VaultAPI(_fusdVault);
        uni = Uni(_uni);
        fUSD = _fUSD;

        IERC20(want).safeApprove(address(fMint), uint256(-1));
        IERC20(fUSD).safeApprove(address(uni), uint256(-1));
        IERC20(fUSD).safeApprove(address(fusdVault), uint256(-1));
    }

    function name() external view override returns (string memory) {
        return "StrategyWFTM";
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        // Want + want deposited as collat + reward generated - debt
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

        // Claim profit only when available
        // uint256 ethProfit = ethFutureProfit();
        // if (ethProfit > 0) {
        //     IHegicStaking(hegicStaking).claimProfit();
        //     _swap(address(this).balance);
        // }

        // Final profit is want generated in the swap if ethProfit > 0
        _profit = balanceOfWant().sub(balanceOfWantBefore);
    }

    function adjustPosition(uint256 _debtOutstanding) internal override {
        if (emergencyExit) {
            return;
        }

        // If we have debt, prepareReturn will take care of it
        if (_debtOutstanding > balanceOfWant()) {
            return;
        }

        // we might need to reduce our investments
        // Usually because of a price change
        if (getCurrentRatio() < getTargetRatio()) {
            reducePosition();
        }

        uint256 _wantAvailable = balanceOfWant().sub(_debtOutstanding);
        if (_wantAvailable > 0) {
            increasePosition(_wantAvailable);
        }
    }

    function liquidatePosition(uint256 _amountNeeded)
        internal
        override
        returns (uint256 _liquidatedAmount, uint256 _loss)
    {
        if (balanceOfWant() < _amountNeeded) {
            // TODO: figure this out
            reducePosition();
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
        address[] memory protected = new address[](1);
        protected[0] = fUSD;
        return protected;
    }

    function reducePosition() internal {
        uint256 _target = targetFusdDebt();
        uint256 _actual = balanceOfDebt();
        uint256 _toPayback = _actual.sub(_target);

        // TODO: get back from fusdVault
        if (balanceOfFusd() < _toPayback) {
            // TODO: This means we don't have enough fusd to payback
            // we will need to withdraw and sell wftm
        }

        fMint.mustRepay(address(fUSD), Math.min(balanceOfFusd(), _toPayback));
    }

    function increasePosition(uint256 _amount) internal {
        // deposit collateral and then decide if we should mint fusd
        fMint.mustDeposit(address(want), _amount);

        uint256 _toMint = getAmountToMint();
        if (_toMint == 0) {
            return;
        }

        fMint.mustMint(address(fUSD), _toMint);
        // TODO deposit fUSD into fusdVault
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

        uni.swapExactTokensForTokens(_amount, 0, path, address(this), now);
    }

    function getAmountToMint() public view returns (uint256) {
        if (getCurrentRatio() <= getTargetRatio()) {
            return 0;
        }

        uint256 _targetDebt = targetFusdDebt();
        uint256 _debt = balanceOfDebt();
        uint256 _toMint = _targetDebt.sub(_debt);

        if (_toMint > MIN_MINT) {
            return _toMint;
        } else {
            return 0;
        }
    }

    function targetFusdDebt() public view returns (uint256) {
        // target fusd debt
        // (wftm_in_collateral * wftm_price) / (target_ratio / 100)
        uint256 collateral =
            balanceOfCollateral().mul(fMint.getPrice(address(want)));
        return collateral.div(getTargetRatio().div(100));
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
        return uint256(100).mul(collateral).div(debt);
    }

    function getTargetRatio() public view returns (uint256) {
        // We do 10% above the eligibility for reward ratio
        return fMint.getRewardEligibilityRatio4dec().mul(1100).div(BASE);
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
