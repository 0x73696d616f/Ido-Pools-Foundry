// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IDOStructs.sol";
import "../interface/IIDOPool.sol";
import "../MultiplierContract.sol";
import "../interface/IMultiplierContract.sol";

contract IDOStorage {
    address public treasury;
    address public proposedMultiplierContract;
    uint256 public multiplierContractUpdateUnlockTime;
    uint256 public constant MULTIPLIER_UPDATE_DELAY = 1 days;
    IMultiplierContract public multiplierContract;

    mapping(uint32 => IDOStructs.IDORoundClock) public idoRoundClocks;
    mapping(uint32 => IDOStructs.IDORoundConfig) public idoRoundConfigs;
    mapping(uint32 => IDOStructs.IDORoundSpec) public idoRoundSpecs;

    uint32 public nextIdoRoundId = 1;

    mapping(uint32 => IDOStructs.MetaIDO) public metaIDOs;
    uint32 public nextMetaIdoId = 1;

    mapping(address => uint256) public globalTokenAllocPerIDORound;
}
