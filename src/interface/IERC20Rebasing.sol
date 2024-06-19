// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC20Mintable.sol";

enum RebaseYieldMode {
  AUTOMATIC,
  VOID,
  CLAIMABLE
}

interface IERC20Rebasing is IERC20Mintable {
  // changes the yield mode of the caller and update the balance
  // to reflect the configuration
  function configure(RebaseYieldMode) external returns (uint256);

  // "claimable" yield mode accounts can call this this claim their yield
  // to another address
  function claim(address recipient, uint256 amount) external returns (uint256);

  // read the claimable amount for an account
  function getClaimableAmount(address account) external view returns (uint256);
}
