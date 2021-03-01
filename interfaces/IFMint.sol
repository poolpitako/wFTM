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

    function getRewardEligibilityRatio4dec() external view returns (uint256);

    function maxToMint(
        address _account,
        address _token,
        uint256 _ratio
    ) external view returns (uint256);

    function mustDeposit(address _token, uint256 _amount) external;

    function mustWithdraw(address _token, uint256 _amount) external;

    function mustMint(address _token, uint256 _amount) external;

    function mustRepay(address _token, uint256 _amount) external;
}
