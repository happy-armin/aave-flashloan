pragma solidity >=0.8.0;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/IUniswapV2Router02.sol";

import "./TestToken.sol";

contract Core {
	using SafeERC20 for IERC20;

	IUniswapV2Router02 public router;

	constructor(IUniswapV2Router02 _router) {
		router = _router;
	}

	function addLiquidity(
		IERC20 token1,
		IERC20 token2,
		uint256 amount1,
		uint256 amount2
	) external {
		token1.safeTransferFrom(msg.sender, address(this), amount1);
		token2.safeTransferFrom(msg.sender, address(this), amount2);

		token1.approve(address(router), amount1);
		token2.approve(address(router), amount2);

		(uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
			address(token1),
			address(token2),
			amount1,
			amount2,
			amount1 / 2,
			amount2 / 2,
			msg.sender,
			block.timestamp
		);
	}

	function swapTokens(
		IERC20 token1,
		IERC20 token2,
		uint256 amountIn,
		uint256 amountOutMin
	) external returns (uint256 amountOut) {
		token1.safeTransferFrom(msg.sender, address(this), amountIn);
		token1.approve(address(router), amountIn);

		address[] memory path = new address[](2);
		path[0] = address(token1);
		path[1] = address(token2);

		uint[] memory amounts = router.swapExactTokensForTokens(
			amountIn,
			amountOutMin,
			path,
			msg.sender,
			block.timestamp
		);

		return amounts[1];
	}
}
