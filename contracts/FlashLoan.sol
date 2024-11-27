// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IPoolAddressesProvider } from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import { FlashLoanSimpleReceiverBase } from "@aave/core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Router02 } from "./interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "./interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "./interfaces/IUniswapV2Pair.sol";

contract FlashLoan is FlashLoanSimpleReceiverBase {
	// Instances of the Uniswap V2 Router and Factory contracts
	IUniswapV2Router02 public router;
	IUniswapV2Factory public factory;

	constructor(
		address _addressProvider,
		address _router,
		address _factory
	) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {
		router = IUniswapV2Router02(_router);
		factory = IUniswapV2Factory(_factory);
	}

	function requestFlashLoan(address _token, uint256 _amount) external {
		address receiverAddress = address(this);
		address asset = _token;
		uint256 amount = _amount;
		bytes memory params = "";
		uint16 referralCode = 0;

		POOL.flashLoanSimple(
			receiverAddress,
			asset,
			amount,
			params,
			referralCode
		);
	}

	function executeOperation(
		address asset,
		uint256 amount,
		uint256 premium,
		address initiator,
		bytes calldata params
	) external override returns (bool) {
		// ensure the contract is authorized
		require(msg.sender == address(POOL), "Unauthorized");

		// repay the loan + fee
		uint256 totalAmount = amount + premium;
		IERC20(asset).approve(address(POOL), totalAmount);

		return true;
	}

	function legendaryTrading(
		address asset,
		uint256 amountIn,
		uint256 amountOut
	) internal returns (uint256) {
		// calculate the count of pairs in the uniswap v2
		uint pairCount = factory.allPairsLength();

		// find the pair which starts with asset
		address[] memory startPairs = new address[](pairCount);
		address[] memory endPairs = new address[](pairCount);
		uint startCount = 0;
		uint endCount = 0;

		for (uint i = 0; i < pairCount; ++i) {
			IUniswapV2Pair pair = IUniswapV2Pair(factory.allPairs(i));
			if (pair.token0() == asset) {
				startPairs[startCount++] = address(pair);
			}
			if (pair.token1() == asset) {
				endPairs[endCount++] = address(pair);
			}
		}

		for (uint i = 0; i < startCount; ++i) {
			for (uint j = 0; j < endCount; j++) {
				address token0 = IUniswapV2Pair(startPairs[i]).token1();
				address token1 = IUniswapV2Pair(endPairs[j]).token0();

				if (factory.getPair(token0, token1) != address(0)) {
					if (
						(getPrice(startPairs[i]) *
							getPrice(factory.getPair(token0, token1)) *
							getPrice(endPairs[j])) >
						(amountOut * 10 ** 18) / amountIn
					) {
						// swap immediately
						address[] memory path = new address[](4);
						path[0] = asset;
						path[1] = token0;
						path[2] = token1;
						path[3] = asset;

						IERC20(asset).approve(address(router), amountIn);

						uint256[] memory amounts = router
							.swapExactTokensForTokens(
								amountIn,
								0,
								path,
								address(this),
								block.timestamp
							);

						return amounts[4];
					}
				}
			}
		}

		return 0;
	}

	function getPrice(address pair) internal view returns (uint256) {
		(uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair)
			.getReserves();
		return (reserve1 * 10 ** 6) / reserve0;
	}

	receive() external payable {}
}
