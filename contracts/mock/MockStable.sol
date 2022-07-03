// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockStable is ERC20("MockTether", "USDT") {
    function claim(uint tokens) external {
        require(tokens > 0 && tokens <= 100000, "tokens must be > 0 and <= 100,000");
        _mint(msg.sender, tokens * 10**decimals());
    }
}