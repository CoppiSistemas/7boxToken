// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

contract GasHelper {
  uint internal constant SWAP_FEE = 25;

  function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
    require(amountIn > 0, "Insufficient amount in");
    require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
    uint amountInWithFee = amountIn * (10000 - SWAP_FEE);
    uint numerator = amountInWithFee * reserveOut;
    uint denominator = (reserveIn * 10000) + amountInWithFee;
    amountOut = numerator / denominator;
  }

  function isReversed(address pair, address tokenA) internal view returns (bool) {
    address token0;
    bool failed = false;
    assembly {
      let emptyPointer := mload(0x40)
      mstore(emptyPointer, 0x0dfe168100000000000000000000000000000000000000000000000000000000)
      failed := iszero(staticcall(gas(), pair, emptyPointer, 0x04, emptyPointer, 0x20))
      token0 := mload(emptyPointer)
    }
    if (failed) revert("Unable to check tokens direction");
    return token0 != tokenA;
  }

  // gas optimization on swap operation using a liquidity pool v2
  function swapToken(address pair, uint amount0Out, uint amount1Out, address receiver) internal {
    bool failed = false;
    assembly {
      let emptyPointer := mload(0x40)
      mstore(emptyPointer, 0x022c0d9f00000000000000000000000000000000000000000000000000000000)
      mstore(add(emptyPointer, 0x04), amount0Out)
      mstore(add(emptyPointer, 0x24), amount1Out)
      mstore(add(emptyPointer, 0x44), receiver)
      mstore(add(emptyPointer, 0x64), 0x80)
      mstore(add(emptyPointer, 0x84), 0)
      failed := iszero(call(gas(), pair, 0, emptyPointer, 0xa4, 0, 0))
    }
    if (failed) revert("Unable to swap Pair");
  }

  // gas optimization on get reserves from liquidity pool v2
  function getTokenReserves(address pairAddress) internal view returns (uint112 reserve0, uint112 reserve1) {
    bool failed = false;
    assembly {
      let emptyPointer := mload(0x40)
      mstore(emptyPointer, 0x0902f1ac00000000000000000000000000000000000000000000000000000000)
      failed := iszero(staticcall(gas(), pairAddress, emptyPointer, 0x4, emptyPointer, 0x40))
      reserve0 := mload(emptyPointer)
      reserve1 := mload(add(emptyPointer, 0x20))
    }
    if (failed) revert("Unable to get reserves from pair");
  }
}
