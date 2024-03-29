// SPDX-License-Identifier: ISC

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./OwnerPausable.sol";
import "./LPToken.sol";

// A constant-sum swap contract
contract OpenSumSwap is OwnerPausable, ReentrancyGuard {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;
  IERC20[] tokens;
  uint256[] decimals;
  uint256[] balances;

  LPToken lpToken;
  uint256[] precisionMultipliers;
  uint8 constant LP_PRECISION_DECIMALS = 18;

  mapping(address => uint8) private tokenIndexes;

  constructor(
    IERC20[] memory _tokens,
    uint256[] memory _decimals,
    string memory _lpTokenName,
    string memory _lpTokenSymbol
  ) {
    require(_tokens.length > 1, "number of tokens must exceed 1");
    require(
      _tokens.length == _decimals.length,
      "Tokens array must be the same shape as decimals array"
    );

    precisionMultipliers = new uint256[](_decimals.length);

    for (uint8 i = 0; i < _tokens.length; i++) {
      precisionMultipliers[i] =
        10**uint256(LP_PRECISION_DECIMALS).sub(uint256(_decimals[i]));
      tokenIndexes[address(_tokens[i])] = i;
    }

    tokens = _tokens;
    decimals = _decimals;
    balances = new uint256[](_tokens.length);
    lpToken = new LPToken(_lpTokenName, _lpTokenSymbol, LP_PRECISION_DECIMALS);
  }

  /*** EVENTS ***/
  event TokenSwap(
    address indexed buyer,
    uint256 tokensSold,
    uint256 tokensBought,
    uint128 soldId,
    uint128 boughtId
  );

  event AddLiquidity(
    address indexed provider,
    uint256[] tokenAmounts,
    uint256 lpTokenSupply
  );
  event RemoveLiquidity(
    address indexed provider,
    uint256[] tokenAmounts,
    uint256 lpTokenSupply
  );
  event RemoveLiquidityOne(
    address indexed provider,
    uint256 lpTokenAmount,
    uint256 lpTokenSupply,
    uint256 boughtId,
    uint256 tokensBought
  );

  /*** MODIFIERS ***/

  /**
   * @notice Modifier to check deadline against current timestamp
   * @param deadline latest timestamp to accept this transaction
   */
  modifier deadlineCheck(uint256 deadline) {
    require(block.timestamp <= deadline, "Deadline not met");
    _;
  }

  /*** VIEW FUNCTIONS ***/

  /**
   * @notice Return the index of the given token address. Reverts if no matching
   * token is found.
   * @param tokenAddress address of the token
   * @return the index of the given token address
   */
  function _getTokenIndex(address tokenAddress) internal view returns (uint8) {
    uint8 index = tokenIndexes[tokenAddress];
    require(address(getToken(index)) == tokenAddress, "Token does not exist");
    return index;
  }

  /**
   * @notice Return address of the pooled token at given index. Reverts if tokenIndex is out of range.
   * @param index the index of the token
   * @return address of the token at given index
   */
  function getToken(uint8 index) public view returns (IERC20) {
    require(index < tokens.length, "Out of range");
    return tokens[index];
  }

  /**
   * @notice Return the index of the given token address. Reverts if no matching
   * token is found.
   * @param tokenAddress address of the token
   * @return the index of the given token address
   */
  function getTokenIndex(address tokenAddress) external view returns (uint8) {
    return _getTokenIndex(tokenAddress);
  }

  /**
   * @notice Return current balance of the pooled token at given index
   * @param index the index of the token
   * @return current balance of the pooled token at given index with token's native precision
   */
  function getTokenBalance(uint8 index) external view returns (uint256) {
    require(index < tokens.length, "Index out of range");
    return balances[index];
  }

  /**
   * @notice Return balances of pooled tokens
   * @return current balances of all tokens in pool
   */
  function getBalances() external view returns (uint256[] memory) {
    return balances;
  }

  /**
        @notice Returns address of lp token
        @return address of lp token
     */
  function getLpToken() external view returns (address) {
    return address(lpToken);
  }

  function _calculateRemoveLiquidity(uint256 amount)
    internal
    view
    returns (uint256[] memory)
  {
    uint256[] memory expectedOut = new uint256[](tokens.length);
    uint256 lpTotalBalance = lpToken.totalSupply();

    for (uint256 i = 0; i < tokens.length; i++) {
      expectedOut[i] = balances[i].mul(amount).div(lpTotalBalance);
    }
    return expectedOut;
  }

  /**
   * @notice A simple method to calculate amount of each underlying
   * tokens that is returned upon burning given amount of LP tokens
   * @param amount the amount of LP tokens that would be burned on withdrawal
   * @return array of token balances that the user will receive
   */
  function calculateRemoveLiquidity(uint256 amount)
    external
    view
    returns (uint256[] memory)
  {
    return _calculateRemoveLiquidity(amount);
  }

  function _calculateRemoveLiquidityOneToken(
    uint256 tokenAmount,
    address tokenOut
  ) internal view returns (uint256 availableTokenAmount) {
    uint8 tokenIndex = _getTokenIndex(tokenOut);
    uint256 scaledAmount = tokenAmount.div(precisionMultipliers[tokenIndex]);

    if (balances[tokenIndex] < scaledAmount) {
      return balances[tokenIndex];
    }
    return scaledAmount;
  }

  /**
   * @notice Calculate the amount of underlying token available to withdraw
   * when withdrawing via only single token
   * @param tokenAmount the amount of LP token to burn
   * @param tokenOut address of which token will be withdrawn
   * @return availableTokenAmount calculated amount of underlying token
   * available to withdraw
   */
  function calculateRemoveLiquidityOneToken(
    uint256 tokenAmount,
    address tokenOut
  ) external view returns (uint256 availableTokenAmount) {
    return _calculateRemoveLiquidityOneToken(tokenAmount, tokenOut);
  }

  function _calculateSwap(
    address tokenFrom,
    address tokenTo,
    uint256 amountIn
  ) internal view returns (uint256) {
    uint8 tokenIndexFrom = _getTokenIndex(tokenFrom);
    uint8 tokenIndexTo = _getTokenIndex(tokenTo);
    uint256 scaledAmount = amountIn
      .mul(precisionMultipliers[tokenIndexFrom])
      .div(precisionMultipliers[tokenIndexTo]);
    if (scaledAmount > balances[tokenIndexTo]) {
      return balances[tokenIndexTo];
    }
    return scaledAmount;
  }

  /**
   * @notice Calculate amount of tokens you receive on swap
   * @param tokenFrom the token the user wants to sell
   * @param tokenTo the token the user wants to buy
   * @param amountIn the amount of tokens the user wants to sell. If the token charges
   * a fee on transfers, use the amount that gets transferred after the fee.
   * @return amount of tokens the user will receive
   */
  function calculateSwap(
    address tokenFrom,
    address tokenTo,
    uint256 amountIn
  ) internal view returns (uint256) {
    return _calculateSwap(tokenFrom, tokenTo, amountIn);
  }

  /*** STATE MODIFYING FUNCTIONS ***/

  /**
   * @notice Swap two tokens using this pool
   * @param tokenFrom the token the user wants to swap from
   * @param tokenTo the token the user wants to swap to
   * @param amountIn the amount of tokens the user wants to swap from
   * @param minAmountOut the min amount the user would like to receive, or revert.
   * @param deadline latest timestamp to accept this transaction
   */
  function swap(
    address tokenFrom,
    address tokenTo,
    uint256 amountIn,
    uint256 minAmountOut,
    uint256 deadline
  )
    external
    nonReentrant
    whenNotPaused
    deadlineCheck(deadline)
    returns (uint256)
  {
    uint8 tokenIndexFrom = _getTokenIndex(tokenFrom);
    uint8 tokenIndexTo = _getTokenIndex(tokenTo);
    uint256 amountOut = _calculateSwap(tokenFrom, tokenTo, amountIn);
    require(
      amountOut < balances[tokenIndexTo],
      "Not enough liquidity for trade"
    );
    require(amountOut >= minAmountOut, "Minimum amount out was not met");

    balances[tokenIndexFrom] = balances[tokenIndexFrom].add(amountIn);
    balances[tokenIndexTo] = balances[tokenIndexTo].sub(amountOut);

    tokens[tokenIndexFrom].safeTransferFrom(
      msg.sender,
      address(this),
      amountIn
    );
    tokens[tokenIndexTo].safeTransfer(msg.sender, amountOut);

    emit TokenSwap(
      msg.sender,
      amountIn,
      amountOut,
      tokenIndexFrom,
      tokenIndexTo
    );
    return amountOut;
  }

  /**
   * @notice Add liquidity to the pool
   * @param amounts the amounts of each token to add, in their native precision
   * @param minToMint the minimum LP tokens adding this amount of liquidity
   * should mint, otherwise revert. Handy for front-running mitigation
   * @return amount of LP token user received
   */
  function addLiquidity(uint256[] memory amounts, uint256 minToMint)
    external
    returns (uint256)
  {
    uint256 toMint = 0;
    for (uint256 i = 0; i < tokens.length; i++) {
      toMint = toMint.add(amounts[i].mul(precisionMultipliers[i]));
      balances[i] = balances[i].add(amounts[i]);
      tokens[i].safeTransferFrom(msg.sender, address(this), amounts[i]);
    }
    require(toMint >= minToMint, "Not enough lp tokens would have been minted");
    lpToken.mint(msg.sender, toMint);

    emit AddLiquidity(msg.sender, amounts, lpToken.totalSupply() + toMint);
    return toMint;
  }

  /**
   * @notice Burn LP tokens to remove liquidity from the pool.
   * @dev Liquidity can always be removed, even when the pool is paused.
   * @param amount the amount of LP tokens to burn
   * @param minAmounts the minimum amounts of each token in the pool
   *        acceptable for this burn. Useful as a front-running mitigation
   * @param deadline latest timestamp to accept this transaction
   * @return amounts of tokens user received
   */
  function removeLiquidity(
    uint256 amount,
    uint256[] calldata minAmounts,
    uint256 deadline
  ) external nonReentrant deadlineCheck(deadline) returns (uint256[] memory) {
    uint256[] memory amounts = _calculateRemoveLiquidity(amount);

    for (uint8 i = 0; i < tokens.length; i++) {
      require(amounts[i] >= minAmounts[i], "Not enough received!");
      balances[i] = balances[i].sub(amounts[i]);
      tokens[i].safeTransfer(msg.sender, amounts[i]);
    }
    lpToken.burnFrom(msg.sender, amount);
    emit RemoveLiquidity(msg.sender, amounts, lpToken.totalSupply());

    return amounts;
  }

  /**
   * @notice Remove liquidity from the pool all in one token.
   * @param tokenAmount the amount of the lp tokens to burn
   * @param tokenOut the address of the token you want to receive
   * @param minAmount the minimum amount to withdraw, otherwise revert
   * @return amount chosen token that user received
   */
  function removeLiquidityOneToken(
    uint256 tokenAmount,
    address tokenOut,
    uint256 minAmount
  ) external returns (uint256) {
    uint8 tokenIndex = _getTokenIndex(tokenOut);
    uint256 amountOut = _calculateRemoveLiquidityOneToken(
      tokenAmount,
      tokenOut
    );
    require(amountOut >= minAmount, "Not enough liquidity to remove");

    balances[tokenIndex] = balances[tokenIndex].sub(amountOut);
    tokens[tokenIndex].safeTransfer(msg.sender, amountOut);
    lpToken.burnFrom(msg.sender, tokenAmount);

    emit RemoveLiquidityOne(
      msg.sender,
      tokenAmount,
      lpToken.totalSupply(),
      tokenIndex,
      amountOut
    );

    return amountOut;
  }
}
