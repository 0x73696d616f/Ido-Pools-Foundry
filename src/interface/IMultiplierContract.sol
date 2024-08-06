// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Interface for the Multiplier Contract
/// @notice This interface defines the core functionality for retrieving user multipliers and ranks
interface IMultiplierContract {
    /// @notice Retrieves the multiplier and rank for a given user
    /// @param user The address of the user to query
    /// @return multiplier The multiplier value corresponding to the user's staked amount
    /// @return rank The rank or level that corresponds to the user's staked amount
    function getMultiplier(address user) external view returns (uint256 multiplier, uint256 rank);
}