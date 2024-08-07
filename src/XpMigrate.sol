// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract XpMigrate is ERC20, Ownable {
    address public claimContract;

    constructor() ERC20("xpMigrate", "XPM") Ownable(msg.sender) {}

    function setClaimContract(address _claimContract) external onlyOwner {
        claimContract = _claimContract;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == claimContract, "Only claim contract can mint");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(msg.sender == claimContract, "Only claim contract can burn");
        _burn(from, amount);
    }

    // function _transfer(address, address, uint256) internal pure override {
    //     revert("XpMigrate tokens are non-transferrable");
    // }
}
