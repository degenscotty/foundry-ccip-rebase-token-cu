// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";

contract Vault {
    // we need to pass the token address to the constructor
    // create a deposit function that mints tokens to the user equal to the amount of ETH the user deposits
    // create a redeem function that burns tokens from the user and sends the user ETH
    // create a way to add rewards to the vault

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error Vault__RedeemFailed();
    error Vault__NotEnoughETH();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposit(address indexed user, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IRebaseToken private immutable i_rebaseToken;

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice Allows a user to deposit ETH into the vault.
     * @dev Mints an equivalent amount of rebase tokens to the sender based on the ETH sent.
     * Emits a {Deposit} event upon successful deposit.
     * Requirements:
     * - The function must be called with a non-zero ETH value.
     */
    function deposit() external payable {
        if (msg.value < 0) revert Vault__NotEnoughETH();
        i_rebaseToken.mint(msg.sender, msg.value, i_rebaseToken.getInterestRate());
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Redeems a specified amount of tokens for ETH.
     * @dev Burns the specified amount of rebase tokens from the caller and sends the equivalent amount of ETH to the caller.
     *      Reverts with Vault__RedeemFailed if the ETH transfer fails.
     * @param _amount The amount of tokens to redeem for ETH.
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        // 1. burn the tokens from the user
        i_rebaseToken.burn(msg.sender, _amount);
        // 2. send the user ETH
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
