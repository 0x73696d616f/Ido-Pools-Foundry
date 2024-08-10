// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IDOStorage.sol";
import "../interface/IIDOPool.sol";

abstract contract IDOPoolView is IDOStorage {
    using IDOStructs for *;

    struct UserMetaIDOInfo {
        uint32 metaIdoId;
        uint16 rank;
        uint16 multiplier;
    }

    struct UserParticipationInfo {
        uint32 roundId;
        uint256 fyTokenAmount;
        uint256 buyTokenAmount;
        uint256 idoTokensAllocated;
        uint256 maxAllocation;
        bool isEligible;
    }

    /**
        * @notice Retrieves the total amount funded by a specific participant across multiple IDO rounds, filtered by token type.
        * @param roundIds An array of IDO round identifiers.
        * @param participant The address of the participant.
        * @param tokenType The type of token to filter the amounts (0 for BuyToken, 1 for FyToken, 2 for Both).
        * @return totalAmount The total amount funded by the participant across the specified rounds for the chosen token type.
        */
    function getParticipantFundingByRounds(uint32[] calldata roundIds, address participant, uint8 tokenType) external view returns (uint256 totalAmount) {
        for (uint i = 0; i < roundIds.length; i++) {
            uint32 roundId = roundIds[i];
            require(idoRoundConfigs[roundId].idoToken != address(0), "IDO round does not exist");
            IDOStructs.Position storage position = idoRoundConfigs[roundId].accountPositions[participant];
            if (tokenType == 0) {  // BuyToken
                totalAmount += position.amount - position.fyAmount;
            } else if (tokenType == 1) {  // FyToken
                totalAmount += position.fyAmount;
            } else {  // Both
                totalAmount += position.amount;
            }
        }
        return totalAmount;
    }

    /**
        * @notice Retrieves the total funds raised for specified IDO rounds, filtered by token type.
        * @param roundIds An array of IDO round identifiers.:
        * @param tokenType The type of token to filter the funding amounts (0 for BuyToken, 1 for FyToken, 2 for Both).
        * @return totalRaised The total funds raised in the specified IDO rounds for the chosen token type.
        */
    function getFundsRaisedByRounds(uint32[] calldata roundIds, uint8 tokenType) external view returns (uint256 totalRaised) {
        for (uint i = 0; i < roundIds.length; i++) {
            uint32 roundId = roundIds[i];
            require(idoRoundConfigs[roundId].idoToken != address(0), "IDO round does not exist");
            IDOStructs.IDORoundConfig storage round = idoRoundConfigs[roundId];

            if (tokenType == 0) {  // BuyToken
                totalRaised += round.totalFunded[round.buyToken];
            } else if (tokenType == 1) {  // FyToken
                totalRaised += round.totalFunded[round.fyToken];
            } else {  // Both
                totalRaised += round.fundedUSDValue; 
            }
        }
        return totalRaised;
    }

    /**
     * @notice Retrieves all IDO round IDs associated with a specific MetaIDO.
     * @param metaIdoId The ID of the MetaIDO.
     * @return An array of IDO round IDs associated with the specified MetaIDO.
     */
    function getIDORoundsByMetaIDO(uint32 metaIdoId) external view returns (uint32[] memory) {
        return metaIDOs[metaIdoId].roundIds;
    }

    /**
     * @notice Retrieves the associated MetaIDO ID for a given IDO round.
     * @param idoRoundId The ID of the IDO round.
     * @return The ID of the associated MetaIDO.
     */
    function getMetaIDOByIDORound(uint32 idoRoundId) external view returns (uint32) {
        return idoRoundClocks[idoRoundId].parentMetaIdoId;
    }


    /**
     * @notice Checks if a user is registered for a specific MetaIDO.
     * @param user The address of the user to check.
     * @param metaIdoId The ID of the MetaIDO.
     * @return A boolean indicating whether the user is registered for the specified MetaIDO.
     */
    function getCheckUserRegisteredForMetaIDO(address user, uint32 metaIdoId) external view returns (bool) {
        return metaIDOs[metaIdoId].isRegistered[user];
    }

    /**
     * @notice Retrieves a user's registration information for all MetaIDOs they are registered for.
     * @param user The address of the user.
     * @return An array of UserMetaIDOInfo structs containing the user's registration details for each MetaIDO.
     */
    function getUserMetaIDOInfo(address user) external view returns (UserMetaIDOInfo[] memory) {
        uint32[] memory registeredMetaIDOs = new uint32[](nextMetaIdoId);
        uint32 count = 0;

        // First, count the number of MetaIDOs the user is registered for
        for (uint32 i = 0; i < nextMetaIdoId; i++) {
            if (metaIDOs[i].isRegistered[user]) {
                registeredMetaIDOs[count] = i;
                count++;
            }
        }

        // Create an array of the correct size
        UserMetaIDOInfo[] memory userInfo = new UserMetaIDOInfo[](count);

        // Populate the array with user's rank and multiplier for each registered MetaIDO
        for (uint32 i = 0; i < count; i++) {
            uint32 metaIdoId = registeredMetaIDOs[i];
            userInfo[i] = UserMetaIDOInfo({
                metaIdoId: metaIdoId,
                rank: metaIDOs[metaIdoId].userRank[user],
                multiplier: metaIDOs[metaIdoId].userMaxAllocMult[user]
            });
        }

        return userInfo;
    }

    /**
     * @notice Retrieves participation information for a user across multiple IDO rounds
     * @dev This function aggregates user participation data for specified IDO rounds
     * @param user The address of the user to query
     * @param idoRoundIds An array of IDO round IDs to check for user participation
     * @return An array of UserParticipationInfo structs containing participation details
     */
    function getUserParticipationInfo(address user, uint32[] calldata idoRoundIds) external view returns (UserParticipationInfo[] memory) {
        UserParticipationInfo[] memory participations = new UserParticipationInfo[](idoRoundIds.length);
        uint256 count = 0;

        for (uint256 i = 0; i < idoRoundIds.length; i++) {
            uint32 roundId = idoRoundIds[i];
            IDOStructs.IDORoundConfig storage config = idoRoundConfigs[roundId];
            IDOStructs.Position storage position = config.accountPositions[user];
            IDOStructs.IDORoundSpec storage spec = idoRoundSpecs[roundId];

            if (position.amount > 0 || spec.specsInitialized) {
                uint32 parentMetaIdoId = idoRoundClocks[roundId].parentMetaIdoId;
                uint16 userRank = metaIDOs[parentMetaIdoId].userRank[user];
                uint16 userMultiplier = metaIDOs[parentMetaIdoId].userMaxAllocMult[user];

                bool isEligible = spec.noRank || (userRank >= spec.minRank && userRank <= spec.maxRank);
                uint256 maxAllocation = spec.maxAlloc;

                if (isEligible && !spec.noMultiplier) {
                    maxAllocation = (maxAllocation * userMultiplier * spec.maxAllocMultiplier) / 1e8;
                }

                participations[count] = UserParticipationInfo(
                    roundId,
                    position.fyAmount,
                    position.amount - position.fyAmount,
                    position.tokenAllocation,
                    maxAllocation,
                    isEligible
                );
                count++;
            }
        }

        assembly { mstore(participations, count) }
        return participations;
    }
}

