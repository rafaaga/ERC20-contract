// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.3.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.3.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.3.0/contracts/security/Pausable.sol";

contract TaxedERC20 is ERC20, Ownable, Pausable {
    uint256 private _taxFee;
    address private _treasury;
    mapping(address => bool) public isFeeExempt;

    event TaxFeeChanged(uint256 oldFee, uint256 newFee);
    event TreasuryChanged(address indexed oldTreasury, address indexed newTreasury);
    event FeeExemptUpdated(address indexed account, bool isExempt);
    event TransferWithFee(address indexed from, address indexed to, uint256 amount, uint256 taxAmount, address indexed treasury);

    constructor(
        string memory name_,
        string memory symbol_,
        address treasury_,
        uint256 taxFee_,
        uint256 initialSupply_
    ) ERC20(name_, symbol_) {
        require(treasury_ != address(0), "Treasury: zero address");
        require(taxFee_ <= 100, "Tax fee must be <= 100");

        _treasury = treasury_;
        _taxFee = taxFee_;

        isFeeExempt[_msgSender()] = true;
        isFeeExempt[_treasury] = true;

        _mint(_msgSender(), initialSupply_ * (10 ** decimals()));
    }

    function taxFee() external view returns (uint256) { return _taxFee; }
    function treasury() external view returns (address) { return _treasury; }

    function setTaxFee(uint256 newFee) external onlyOwner {
        require(newFee <= 100, "Tax fee must be <= 100");
        uint256 old = _taxFee;
        _taxFee = newFee;
        emit TaxFeeChanged(old, newFee);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Treasury: zero address");
        address old = _treasury;
        isFeeExempt[old] = false;
        isFeeExempt[newTreasury] = true;
        _treasury = newTreasury;
        emit TreasuryChanged(old, newTreasury);
    }

    function setFeeExempt(address account, bool exempt) external onlyOwner {
        isFeeExempt[account] = exempt;
        emit FeeExemptUpdated(account, exempt);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function _transfer(address sender, address recipient, uint256 amount)
        internal virtual override whenNotPaused
    {
        if (_taxFee == 0 || isFeeExempt[sender] || isFeeExempt[recipient]) {
            super._transfer(sender, recipient, amount);
            return;
        }

        uint256 taxAmount = (amount * _taxFee) / 100;
        uint256 netAmount = amount - taxAmount;

        if (taxAmount > 0) {
            super._transfer(sender, _treasury, taxAmount);
        }
        super._transfer(sender, recipient, netAmount);

        emit TransferWithFee(sender, recipient, amount, taxAmount, _treasury);
    }
}
