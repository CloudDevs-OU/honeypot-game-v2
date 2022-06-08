// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./HoneyToken.sol";
import "./interface/IHoneyBank.sol";

contract HoneyBank is IHoneyBank, AccessControl {
    // State variables
    HoneyToken public token;
    IERC20 public stable;
    uint public rate;
    uint public swapFee;

    // Constants
    uint public constant MIN_SWAP_TOKENS_AMOUNT = 100 ether;
    uint public constant FEE_DIVISOR = 10000;
    uint public constant RATE_DIVISOR = 10000;
    bytes32 public constant BANKER_ROLE = keccak256("BANKER_ROLE");

    // Events
    event BuyTokens(address account, uint tokensAmount, uint stableAmount, uint rate, uint fee);
    event SellTokens(address account, uint tokensAmount, uint stableAmount, uint rate, uint fee);
    event RateUpdate(uint newRate);
    event SwapFeeUpdate(uint newSwapFee);

    constructor(IERC20 _stable) {
        token = new HoneyToken();
        stable = _stable;
        rate = 42; // Stable Amount = Tokens Amount * rate / 10,000
        swapFee = 200; // 2 %
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(BANKER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /**
     * @dev Swap stable to tokens
     *
     * @param tokensAmount tokens amount that will be added to balance
     */
    function buyTokens(uint tokensAmount) external {
        require(tokensAmount >= MIN_SWAP_TOKENS_AMOUNT, "Buy tokens amount too small");

        uint stableAmount = tokensAmount * rate / RATE_DIVISOR;
        uint stableFee = stableAmount * swapFee / FEE_DIVISOR;
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
    function sellTokens(uint tokensAmount) external {
        require(tokensAmount >= MIN_SWAP_TOKENS_AMOUNT, "Sell tokens amount is too small");
        require(token.balanceOf(msg.sender) >= tokensAmount, "Not enough tokens on balance");

        token.burnTokens(msg.sender, tokensAmount);

        uint tokensFee = tokensAmount * swapFee / FEE_DIVISOR ;
        uint stableAmount = (tokensAmount - tokensFee) * rate / RATE_DIVISOR;
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
    function add(address to, uint amount) external onlyRole(BANKER_ROLE) {
        token.mintTokens(to, amount);
    }

    /**
     * @dev Subtract tokens from account balance
     * @notice Can be accessed only by BANKER_ROLE
     *
     * @param from account from burn tokens
     * @param amount tokens amount that needs to be debited
     */
    function subtract(address from, uint amount) external onlyRole(BANKER_ROLE) {
        require(token.balanceOf(from) >= amount, "Not enough tokens");
        token.burnTokens(from, amount);
    }

    /**
     * @dev Update swap rate (stable = tokens / rate)
     * @notice Can be accessed only by contract admin
     *
     * @param newRate new rate that must be used for swap calc
     */
    function setRate(uint newRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rate = newRate;
        emit RateUpdate(newRate);
    }

    /**
     * @dev Update swap fee (10,000 = 100%)
     * @notice Can be accessed only by contract admin
     *
     * @param newSwapFee new swap fee that must be applied to all swaps
     */
    function setSwapFee(uint newSwapFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        swapFee = newSwapFee;
        emit SwapFeeUpdate(newSwapFee);
    }

    /**
     * @dev Get tokens balance of account
     * @notice Can be accessed only by contract admin
     *
     * @param account balance owner
     */
    function balanceOf(address account) external view returns(uint) {
        return token.balanceOf(account);
    }
}