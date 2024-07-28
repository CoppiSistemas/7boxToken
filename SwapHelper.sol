// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// "@openzeppelin/contracts": "5.0.1",
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SwapHelper {
  address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

  address public feeReceiverA = 0xc90F0bD4eBf9E0B7eC114d49e7A0505dD35A243a;
  address public feeReceiverB = 0xD7BcFd1d8B86Ed5F8451eaF10464939EbD5101E8;

  constructor() {}

  function updateReceiverA(address wallet) public {
    require(msg.sender == feeReceiverA, "unauthorized wallet");
    require(wallet != feeReceiverA, "wallet is already set");
    require(wallet != address(0), "invalid wallet");
    feeReceiverA = wallet;
  }

  function updateReceiverB(address wallet) public {
    require(msg.sender == feeReceiverB, "unauthorized wallet");
    require(wallet != feeReceiverB, "wallet is already set");
    require(wallet != address(0), "invalid wallet");
    feeReceiverB = wallet;
  }

  function withdraw() public {
    IERC20 _localWbnb = IERC20(WBNB);
    uint balance = _localWbnb.balanceOf(address(this));
    require(balance > 0, "no balance to be withdrawn");

    uint onePercent = balance / 4;
    uint threePercent = balance - onePercent;

    SafeERC20.safeTransfer(_localWbnb, feeReceiverA, threePercent);
    SafeERC20.safeTransfer(_localWbnb, feeReceiverB, onePercent);
  }
}
