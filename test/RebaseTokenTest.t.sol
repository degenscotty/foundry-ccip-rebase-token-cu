// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {Vault} from "src/Vault.sol";
import {console2} from "forge-std/console2.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function addRewardsToVault(uint256 amount) public {
        // send some rewards to the vault using the receive function
        (bool success,) = payable(address(vault)).call{value: amount}("");
        if (!success) revert("Failed to fund vault");
    }

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();

        // 2. check our rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        console2.log("startBalance", startBalance);
        assertEq(startBalance, amount, "Balance should match the deposited amount");

        // 3. warp the time and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        console2.log("middleBalance", middleBalance);
        assertGt(middleBalance, startBalance, "Balance should increase after time warp");

        // 4. warp the time again by the same amount and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, middleBalance, "Balance should increase after second time warp");
        console2.log("endBalance", endBalance);

        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);
        vm.stopPrank();
    }
}
