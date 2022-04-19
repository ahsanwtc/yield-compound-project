// SPDX-License-Identifier: MIT
pragma solidity ^0.5.7;
pragma experimental ABIEncoderV2;

import '@studydefi/money-legos/dydx/contracts/DydxFlashloanBase.sol';
import '@studydefi/money-legos/dydx/contracts/ICallee.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract YieldFarmer is ICallee, DydxFlashloanBase {
  /* Direction is only used by Compound */
  enum Direction { Deposit, Withdraw }
  struct Operation {
    address token;
    address cToken;
    Direction direction;
    uint amountProvided;
    uint amountBorrowed;
  }
  address public admin;
  constructor() public {
    admin = msg.sender;
  }
  
  
  /**
   * 
   * @param {address} _solo Address of the dydx exchange
   * @param {address} _token Address of the token which is to be borrowed
   * @param {address} _cToken Address of the associated cToken in compound
   * @param {Direction} _direction Enum specifying either borrow or reimburse to compound
   * @param {uint} _amountProvided Amount already provided
   * @param {uint} _amountBorrowed Amount needed to be borrowed from the flash loan
  */
  function _initiateFlashloan(address _solo, address _token, address _cToken, Direction _direction, uint _amountProvided, uint _amountBorrowed) internal {
    ISoloMargin solo = ISoloMargin(_solo);

    /* Get marketId from token address */
    uint256 marketId = _getMarketIdFromTokenAddress(_solo, _token);

    /* Calculate repay amount (_amount + (2 wei)), 2 wei is the cost of flash loan */
    /* Approve transfer from */
    uint256 repayAmount = _getRepaymentAmountInternal(_amountBorrowed);
    IERC20(_token).approve(_solo, repayAmount);

    /* 1. Withdraw $ */
    /* 2. Call callFunction(...) */
    /* 3. Deposit back $ */
    Actions.ActionArgs[] memory operations = new Actions.ActionArgs[](3);

    operations[0] = _getWithdrawAction(marketId, _amountBorrowed);
    operations[1] = _getCallAction(
        /* Encode MyCustomData for callFunction */
        abi.encode(Operation({
          token: _token, 
          cToken: _cToken, 
          direction: _direction,
          amountProvided: _amountProvided, 
          amountBorrowed: _amountBorrowed
        }))
    );
    operations[2] = _getDepositAction(marketId, repayAmount);

    Account.Info[] memory accountInfos = new Account.Info[](1);
    accountInfos[0] = _getAccountInfo();

    solo.operate(accountInfos, operations);
  }
}
