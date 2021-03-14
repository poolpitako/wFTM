// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./IFantomDeFiTokenStorage.sol";

interface IFMint {
    function collateralValueOf(
        address _account,
        address _token,
        uint256 _sub
    ) external view returns (uint256);

    function debtValueOf(
        address _account,
        address _token,
        uint256 _add
    ) external view returns (uint256);

    function getPrice(address _token) external view returns (uint256);

    function getCollateralPool()
        external
        view
        returns (IFantomDeFiTokenStorage);

    function getCollateralLowestDebtRatio4dec() external view returns (uint256);

    function getRewardEligibilityRatio4dec() external view returns (uint256);

    function getFMintFee4dec() external view returns (uint256);

    function fMintFeeDigitsCorrection() external view returns (uint256);

    function mustDeposit(address _token, uint256 _amount) external;

    function mustWithdraw(address _token, uint256 _amount) external;

    function mustWithdrawMax(address _token, uint256 _ratio) external;

    function mustMint(address _token, uint256 _amount) external;

    function mustRepayMax(address _token) external;
}
