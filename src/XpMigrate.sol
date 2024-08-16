// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract XpMigrate is ERC20, Ownable {
    address public pointContract;
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18; // 1 billion tokens with 18 decimals

    constructor() ERC20("xpMigrate", "XPM") Ownable(msg.sender) {
        // Do not mint any tokens in the constructor
    }

    function setPointContract(address _pointContract) external onlyOwner {
        pointContract = _pointContract;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == pointContract, "XpMigrate: only Points contract can mint");
        require(totalSupply() + amount <= MAX_SUPPLY, "XpMigrate: minting would exceed max supply");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(msg.sender == pointContract, "XpMigrate: only Points contract can burn");
        _burn(from, amount);
    }
}
