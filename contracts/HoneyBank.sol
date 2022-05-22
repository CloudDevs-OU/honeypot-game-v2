// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./HoneyToken.sol";
import "./IHoneyBank.sol";

contract HoneyBank is IHoneyBank, AccessControl {
    // State variables
    HoneyToken public token;
    IERC20 public stable;
    uint public rate;
    uint public swapFee;

    // Constants
    uint public constant MIN_SWAP_TOKENS_AMOUNT = 100 ether;
    bytes32 public constant BANKER_ROLE = keccak256("BANKER_ROLE");

    // Events
    event BuyTokens(address userAddress, uint tokensAmount, uint stableAmount, uint rate, uint fee);
    event SellTokens(address userAddress, uint tokensAmount, uint stableAmount, uint rate, uint fee);
    event RateUpdate(uint oldRate, uint newRate);
    event SwapFeeUpdate(uint oldSwapFee, uint newSwapFee);

    constructor(IERC20 _stable) {
        token = new HoneyToken();
        stable = _stable;
        rate = 100; // 1 stable = 1 token / 10000 * rate => 1 token = 1 stable * 10000 / rate
        swapFee = 200; // 2 %
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(BANKER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /**
     * @dev Swap stable to tokens
     *
     * @param tokensAmount tokens amount that will be added to balance
     */
    function buyTokens(uint tokensAmount) public {
        require(tokensAmount >= MIN_SWAP_TOKENS_AMOUNT, "Buy tokens amount too small");

        uint stableAmount = tokensAmount * rate / 10000;
        uint stableFee = stableAmount * swapFee / 10000;
        uint stableAmountWithFee = stableAmount + stableFee;
        uint stableAllowance = stable.allowance(msg.sender, address(this));
        require(stableAllowance >= stableAmountWithFee, "Allowance is not enough");

        stable.transferFrom(msg.sender, address(this), stableAmountWithFee);
        token.mintTokens(msg.sender, tokensAmount);

        emit BuyTokens(msg.sender, tokensAmount, stableAmount, rate, stableFee);
    }

    /**
     * @dev Swap tokens to stable
     *
     * @param tokensAmount tokens amount that will be subtracted from balance
     */
    function sellTokens(uint tokensAmount) public {
        require(tokensAmount >= MIN_SWAP_TOKENS_AMOUNT, "Sell tokens amount is too small");
        require(token.balanceOf(msg.sender) >= tokensAmount, "Not enough tokens on balance");

        token.burnTokens(msg.sender, tokensAmount);

        uint tokensFee = tokensAmount * swapFee / 10000 ;
        uint stableAmount = (tokensAmount - tokensFee) * rate / 10000;
        stable.transfer(msg.sender, stableAmount);

        emit SellTokens(msg.sender, tokensAmount, stableAmount, rate, tokensFee);
    }

    /**
     * @dev Add tokens to account balance
     * @notice Can be accessed only by BANKER_ROLE
     *
     * @param to account for getting tokens
     * @param amount tokens amount that will be credited
     */
    function add(address to, uint amount) public onlyRole(BANKER_ROLE) {
        token.mintTokens(to, amount);
    }

    /**
     * @dev Subtract tokens from account balance
     * @notice Can be accessed only by BANKER_ROLE
     *
     * @param from account from burn tokens
     * @param amount tokens amount that needs to be debited
     */
    function subtract(address from, uint amount) public onlyRole(BANKER_ROLE) {
        require(token.balanceOf(from) >= amount, "Not enough tokens");
        token.burnTokens(from, amount);
    }

    /**
     * @dev Update swap rate (1 stable = tokens / rate)
     * @notice Can be accessed only by contract admin
     *
     * @param newRate new rate that must be used for swap calc
     */
    function setRate(uint newRate) public onlyRole(DEFAULT_ADMIN_ROLE) {
        emit RateUpdate(rate, newRate);
        rate = newRate;
    }

    /**
     * @dev Update swap fee (10,000 = 100%)
     * @notice Can be accessed only by contract admin
     *
     * @param newSwapFee new swap fee that must be applied to all swaps
     */
    function setSwapFee(uint newSwapFee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        emit SwapFeeUpdate(swapFee, newSwapFee);
        swapFee = newSwapFee;
    }

    /**
 * @dev Get tokens balance of account
     * @notice Can be accessed only by contract admin
     *
     * @param account balance owner
     */
    function balanceOf(address account) public view returns(uint) {
        return token.balanceOf(account);
    }
}