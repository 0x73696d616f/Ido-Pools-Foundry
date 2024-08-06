// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStakingContract {
    /// @notice Retrieves staking details for a given user.
    /// @param user The address of the user to query.
    /// @return amountStaked The amount staked by the user.
    /// @return rewardDebt The debt of the user towards rewards.
    /// @return rewards The total rewards accumulated by the user.
    /// @return unstakeInitTime The timestamp when unstaking was initiated.
    /// @return stakeInitTime The timestamp when staking was initiated.
    function stakers(address user) external view returns (
        uint256 amountStaked, 
        uint256 rewardDebt, 
        uint256 rewards, 
        uint256 unstakeInitTime, 
        uint256 stakeInitTime
    );
}