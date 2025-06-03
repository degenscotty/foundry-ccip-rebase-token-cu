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

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author @degenScotty
 * @notice This is going to be a cross-chain rebase token that incentivizes users to deposit into the vault.
 * @notice The interest rate in the smart contract can only decrease over time, incentivizing early users.
 * @notice Each user will have their own interest rate, based on the global interest rate at the time of deposit.
 * @dev This contract is for educational purposes only.
 *      Please do not use in production.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 interestRate, uint256 newInterestRate);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}

    /**
     * @notice Grants the MINT_AND_BURN_ROLE to a specified account.
     * @param _account The address of the account to grant the role to.
     */
    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice Sets a new interest rate for the token.
     * @dev The new interest rate must be greater than or equal to the current interest rate.
     * @param _newInterestRate The new interest rate to be set.
     * @notice RebaseToken__InterestRateCanOnlyDecrease if the new interest rate
     *         is less than the current interest rate.
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }

        s_interestRate = _newInterestRate;
    }

    /**
     * @notice Mints a new token to the user.
     * @param _to The address of the user to mint the tokens to.
     * @param _amount The amount of tokens to mint to the user.
     */
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        // Mints any existing interest that has accrued since the last time the user's balance was updated.
        _mintAccruedInterest(_to);
        // Sets the users interest rate to either their bridged value if they are bridging or to the current interest rate if they are depositing.
        s_userInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burns a user's tokens.
     * @param _from The address of the user to burn the tokens from.
     * @param _amount The amount of tokens to burn from the user.
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice Returns the balance of the user.
     * @param _user The address of the user to get the balance for.
     * @return The principle balance of the user + the accrued interest.
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principle balance of the user. The tokens that have been minted to the user.
        // multiply the principle balance by the interest rate.
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /**
     * @notice Transfers tokens to a specified recipient.
     * @dev This function mints accrued interest for both the sender and the recipient
     *      before executing the transfer. If the amount is set to the maximum uint256,
     *      it will transfer the entire balance of the sender. If the recipient has no
     *      previous balance, their interest rate will be set to the current global interest rate.
     * @param _recipient The address of the recipient to receive the tokens.
     * @param _amount The amount of tokens to transfer to the recipient.
     * @return A boolean value indicating whether the transfer was successful.
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        // accumulates the balance of the user so it is up to date with any interest accumulated.
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (balanceOf(_recipient) == 0) {
            // Update the users interest rate only if they have not yet got one (or they tranferred/burned all their tokens). Otherwise people could force others to have lower interest.
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @dev transfers tokens from the sender to the recipient. This function also mints any accrued interest since the last time the user's balance was updated.
     * @param _sender the address of the sender
     * @param _recipient the address of the recipient
     * @param _amount the amount of tokens to transfer
     * @return true if the transfer was successful
     *
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        // accumulates the balance of the user so it is up to date with any interest accumulated.
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (balanceOf(_recipient) == 0) {
            // Update the users interest rate only if they have not yet got one (or they tranferred/burned all their tokens). Otherwise people could force others to have lower interest.
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }
    /**
     * @notice Calculates the accumulated interest for a user since their last update.
     * @param _user The address of the user for whom to calculate the accumulated interest.
     * @return linearInterest The total accumulated interest based on the user's interest rate and time elapsed.
     */

    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

    /**
     * @notice Mints accrued interest to the user.
     * @dev This function calculates the user's current balance including accrued interest,
     *      determines the amount of tokens to mint based on the difference between the
     *      current balance and the previous principle balance, and updates the user's last
     *      update timestamp.
     * @param _user The address of the user to mint accrued interest for.
     */
    function _mintAccruedInterest(address _user) internal {
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        _mint(_user, balanceIncrease);
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns the current global interest rate.
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @notice Returns the interest rate for a given user.
     * @param _user The address of the user to get the interest rate for.
     * @return The interest rate for the user.
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }

    /**
     * @notice Returns the principle balance of a user. Number of tokens that have been minted to the user,
     *         not including any accrued interest since the last time the user interacted with the contract.
     * @param _user The address of the user to get the principle balance for.
     * @return The principle balance of the user.
     */
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }
}
