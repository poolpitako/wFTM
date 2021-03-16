// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface IFStake {
    function mustRewardClaim() external;

    // claimable
    function rewardStash(address) external view returns (uint256);

    // not claimable
    function rewardEarned(address) external view returns (uint256);
}
