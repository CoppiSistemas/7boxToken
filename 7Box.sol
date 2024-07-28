// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// "@openzeppelin/contracts": "5.0.1",
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Errors.sol";
import "./Events.sol";
import "./IPancake.sol";
import "./GasHelper.sol";
import "./SwapHelper.sol";

contract SevenBoxToken is ERC20Burnable, GasHelper, TokenErrors, TokenEvents, Ownable {
  uint public constant MAX_SUPPLY = 100_000_000e18;
  uint public constant MIN_AMOUNT_TO_SWAP = 75e18;
  uint public constant FEE = 400;

  address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
  address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
  address constant WBNB_USDT_POOL_V2 = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;

  mapping(address => bool) public exceptFeeWallets;
  mapping(address => bool) public liquidityWallets;

  address public immutable swapHelper;
  address public immutable mainLiquidityPool;

  bool _reentrance;

  constructor() ERC20("7BOX", "7BOX") Ownable(_msgSender()) {
    PancakeRouter router = PancakeRouter(PANCAKE_ROUTER);
    address liquidityPool = address(PancakeFactory(router.factory()).createPair(WBNB, address(this)));

    mainLiquidityPool = liquidityPool;
    liquidityWallets[liquidityPool] = true;

    SwapHelper swapHelperContract = new SwapHelper();
    swapHelper = address(swapHelperContract);
    exceptFeeWallets[swapHelper] = true;

    _mint(_msgSender(), MAX_SUPPLY);
  }

  receive() external payable {
    revert NotAllowedSendGasToToken();
  }

  function updateExceptFeeWallet(address target, bool status) external onlyOwner {
    if (exceptFeeWallets[target] == status) return;
    exceptFeeWallets[target] = status;
    emit ExceptFeeWalletsUpdated(target, status);
  }

  function updateLiquidityWallet(address target, bool status) external onlyOwner {
    if (liquidityWallets[target] == status) return;
    liquidityWallets[target] = status;
    emit LiquidityWalletsUpdated(target, status);
  }

  function _update(address from, address to, uint256 value) internal override {
    bool isLiquiditySender = liquidityWallets[from]; // Buying
    bool isLiquidityReceiver = liquidityWallets[to]; // Selling

    if ((isLiquidityReceiver || isLiquiditySender) && !_reentrance && !exceptFeeWallets[from] && !exceptFeeWallets[to]) {
      _reentrance = true;

      address swapHelperLocal = swapHelper;
      uint fee = (value * FEE) / 10000;
      super._update(from, swapHelperLocal, fee);

      uint swapHelperBalance = balanceOf(swapHelperLocal);
      if (isLiquidityReceiver) {
        _operateAutoSwap(swapHelperLocal, swapHelperBalance);
      }

      super._update(from, to, value - fee);
      _reentrance = false;
    } else {
      super._update(from, to, value);
    }
  }

  function _operateAutoSwap(address swapHelperLocal, uint swapHelperBalance) private {
    address liquidityPoolLocal = mainLiquidityPool;

    (uint112 reserve0, uint112 reserve1) = getTokenReserves(liquidityPoolLocal);
    bool reversed = isReversed(liquidityPoolLocal, WBNB);

    if (reversed) {
      uint112 temp = reserve0;
      reserve0 = reserve1;
      reserve1 = temp;
    }

    uint wbnbAmount = getAmountOut(swapHelperBalance, reserve1, reserve0);

    if (_checkMinValueToSwap(wbnbAmount)) {
      _update(swapHelperLocal, liquidityPoolLocal, swapHelperBalance);

      if (!reversed) {
        swapToken(liquidityPoolLocal, wbnbAmount, 0, swapHelper);
      } else {
        swapToken(liquidityPoolLocal, 0, wbnbAmount, swapHelper);
      }
    }
  }

  function _checkMinValueToSwap(uint wbnbAmount) private view returns (bool) {
    address liquidityPool = WBNB_USDT_POOL_V2;

    (uint112 reserve0, uint112 reserve1) = getTokenReserves(liquidityPool);
    bool reversed = !(isReversed(liquidityPool, WBNB));

    if (reversed) {
      uint112 temp = reserve0;
      reserve0 = reserve1;
      reserve1 = temp;
    }

    uint usdtAmount = getAmountOut(wbnbAmount, reserve1, reserve0);
    return usdtAmount >= MIN_AMOUNT_TO_SWAP;
  }
}
