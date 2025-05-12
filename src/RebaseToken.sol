// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author @degenScotty
 * @notice This is going to be a cross-chain rebase token that incentivizes users to deposit into the vault.
 * @notice The interest rate in the smart contract can only decrease over time, incentivizing early users.
 * @notice Each user will have their own interest rate, based on the global interest rate at the time of deposit.
 * @dev This contract is for educational purposes only.
 *      Please do not use in production.
 */
contract RebaseToken is ERC20 {
    uint256 private s_interestRate = 5e10;

    constructor() ERC20("RebaseToken", "RBT") {}

    function setInterestRate(uint256 _newInterestRate) external {}
}
