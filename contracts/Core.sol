// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import necessary contracts and interfaces
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Router02 } from "./interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "./interfaces/IUniswapV2Factory.sol";

contract Core {
	// Use SafeERC20 for secure token transfers
	using SafeERC20 for IERC20;

	// Instances of the Uniswap V2 Router and Factory contracts
	IUniswapV2Router02 public router;
	IUniswapV2Factory public factory;

	/**
	 * @notice Constructs the Core contract with the necessary Uniswap V2 Router and Factory instances.
	 * @param _router The address of the Uniswap V2 Router contract.
	 * @param _factory The address of the Uniswap V2 Factory contract.
	 */
	constructor(IUniswapV2Router02 _router, IUniswapV2Factory _factory) {
		router = _router;
		factory = _factory;
	}

	error PairDoesNotExist();

	/**
	 * @notice Adds liquidity to a Uniswap V2 pair.
	 * @param token1 The address of the first token in the pair.
	 * @param token2 The address of the second token in the pair.
	 * @param amount1 The amount of token1 to add.
	 * @param amount2 The amount of token2 to add.
	 * @return liquidity The amount of liquidity tokens received.
	 */
	function addLiquidity(
		IERC20 token1,
		IERC20 token2,
		uint256 amount1,
		uint256 amount2
	) external returns (uint256 liquidity) {
		// Transfer specified amounts of tokens from the user to this contract
		token1.safeTransferFrom(msg.sender, address(this), amount1);
		token2.safeTransferFrom(msg.sender, address(this), amount2);

		// Approve the router to spend the tokens on behalf of this contract
		token1.approve(address(router), amount1);
		token2.approve(address(router), amount2);

		// Add liquidity to the Uniswap pair
		(, , uint256 liquidityReceived) = router.addLiquidity(
			address(token1),
			address(token2),
			amount1,
			amount2,
			amount1 / 2, // Minimum amount of token1 to add
			amount2 / 2, // Minimum amount of token2 to add
			msg.sender, // Recipient of the liquidity tokens
			block.timestamp // Current timestamp as deadline
		);

		// Return the amount of liquidity tokens received
		return liquidityReceived;
	}

	/**
	 * Adds liquidity to an ETH-token pair on a decentralized exchange.
	 *
	 * @param token - The ERC20 token to add liquidity for.
	 * @param amountIn - The amount of the token to deposit.
	 * @return liquidity - The amount of liquidity received.
	 */
	function addLiquidityETH(
		IERC20 token,
		uint256 amountIn
	) external payable returns (uint256 liquidity) {
		// Transfer the token amount from the sender to the contract
		token.safeTransferFrom(msg.sender, address(this), amountIn);

		// Approve the router contract to spend the token amount
		token.approve(address(router), amountIn);

		// Add liquidity to the ETH-token pair
		(, , uint256 liquidityReceived) = router.addLiquidityETH{
			value: msg.value
		}(
			address(token),
			amountIn,
			0, // Slippage is set to 0
			0, // Slippage is set to 0
			msg.sender,
			block.timestamp
		);

		// Return the amount of liquidity received
		return liquidityReceived;
	}

	/**
	 * @notice Removes liquidity from a Uniswap V2 pair.
	 * @param token1 The address of the first token in the pair.
	 * @param token2 The address of the second token in the pair.
	 * @param liquidity The amount of liquidity tokens to remove.
	 * @return amountOut1 The amount of token1 received.
	 * @return amountOut2 The amount of token2 received.
	 */
	function removeLiquidity(
		IERC20 token1,
		IERC20 token2,
		uint256 liquidity
	) external returns (uint256 amountOut1, uint256 amountOut2) {
		// Get the address of the liquidity pair for the two tokens
		address pair = factory.getPair(address(token1), address(token2));
		// Revert if the pair does not exist
		if (pair == address(0)) {
			revert PairDoesNotExist();
		}

		// Transfer liquidity tokens from the user to this contract
		token1.safeTransferFrom(msg.sender, address(this), liquidity);

		// Approve the router to spend the liquidity tokens
		token1.approve(address(router), liquidity);

		// Remove liquidity from the pair
		(amountOut1, amountOut2) = router.removeLiquidity(
			address(token1),
			address(token2),
			liquidity,
			1, // Minimum amount of token1 to receive
			1, // Minimum amount of token2 to receive
			msg.sender, // Recipient of the tokens
			block.timestamp // Current timestamp as deadline
		);

		// Return the amounts of tokens received
		return (amountOut1, amountOut2);
	}

	/**
	 * @notice Removes liquidity from the ETH-token pair.
	 * @param token The ERC20 token to remove liquidity for.
	 * @param liquidity The amount of liquidity to remove.
	 * @return amountOut1 The amount of the first token received.
	 * @return amountOut2 The amount of the second token (ETH) received.
	 */
	function removeLiquidityETH(
		IERC20 token,
		uint256 liquidity
	) external returns (uint256 amountOut1, uint256 amountOut2) {
		// Get the address of the token-ETH pair
		address pair = factory.getPair(address(token), router.WETH());
		// Revert if the pair does not exist
		if (pair == address(0)) {
			revert PairDoesNotExist();
		}

		// Transfer the liquidity from the caller to this contract
		token.safeTransferFrom(msg.sender, address(this), liquidity);
		// Approve the router to spend the liquidity
		token.approve(address(router), liquidity);

		// Remove the liquidity from the pair
		(amountOut1, amountOut2) = router.removeLiquidityETH(
			address(token),
			liquidity,
			1,
			1,
			msg.sender,
			block.timestamp
		);

		return (amountOut1, amountOut2);
	}

	/**
	 * @notice Swaps an exact amount of one token for another token.
	 * @param token1 The address of the token to swap from.
	 * @param token2 The address of the token to swap to.
	 * @param amountIn The amount of token1 to swap.
	 * @param amountOutMin The minimum amount of token2 to receive from the swap.
	 * @return amountOut The actual amount of token2 received from the swap.
	 */
	function swapTokens(
		IERC20 token1,
		IERC20 token2,
		uint256 amountIn,
		uint256 amountOutMin
	) external returns (uint256 amountOut) {
		// Transfer the specified amount of token1 from the user to this contract
		token1.safeTransferFrom(msg.sender, address(this), amountIn);

		// Approve the router to spend token1 on behalf of this contract
		token1.approve(address(router), amountIn);

		// Define the path for the swap (token1 -> token2)
		address[] memory path = new address[](2);
		path[0] = address(token1); // From token1
		path[1] = address(token2); // To token2

		// Execute the swap
		uint256[] memory amounts = router.swapExactTokensForTokens(
			amountIn, // Amount of token1 to swap
			amountOutMin, // Minimum amount of token2 to receive
			path, // The path of the swap
			msg.sender, // Recipient of the output tokens
			block.timestamp // Deadline for the swap
		);

		// Return the actual amount of token2 received
		return amounts[1];
	}

	/**
	 * @notice Swaps an exact amount of ERC20 token for ETH.
	 * @param token The ERC20 token to swap.
	 * @param amountIn The amount of token to swap.
	 * @param amountOutMin The minimum amount of ETH to receive from the swap.
	 * @return amountOut The actual amount of ETH received from the swap.
	 */
	function swapTokenWithETH(
		address wethAddress,
		IERC20 token,
		uint256 amountIn,
		uint256 amountOutMin
	) external returns (uint256 amountOut) {
		// Transfer the specified amount of token from the user to this contract
		token.safeTransferFrom(msg.sender, address(this), amountIn);

		// Approve the router to spend the token on behalf of this contract
		token.approve(address(router), amountIn);

		// Define the path for the swap (token -> WETH)
		address[] memory path = new address[](2);
		path[0] = address(token);
		path[1] = wethAddress;

		// Execute the swap
		uint256[] memory amounts = router.swapExactTokensForETH(
			amountIn, // Amount of token to swap
			amountOutMin, // Minimum amount of ETH to receive
			path, // The path of the swap
			msg.sender, // Recipient of the output ETH
			block.timestamp // Deadline for the swap
		);

		// Return the actual amount of ETH received
		return amounts[1];
	}
}
