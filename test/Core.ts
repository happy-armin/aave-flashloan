import { expect } from "chai"
import { Signer, accessListify, parseEther } from "ethers"
import { deployments, ethers, getNamedAccounts } from "hardhat"
import { Core, IUniswapV2Factory, IUniswapV2Router02, TestToken } from "typechain-types"

describe("Core", () => {
	const ADDRESS__UNISWAP_V2_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"
	const ADDRESS__UNISWAP_V2_FACTORY = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"
	const ADDRESS__WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

	let deployer: Signer, alice: Signer, bob: Signer
	let token1: TestToken
	let token2: TestToken
	let core: Core
	let v2Router: IUniswapV2Router02
	let v2Factory: IUniswapV2Factory

	before(async () => {
		// Deploy contracts
		;[deployer, alice, bob] = await ethers.getSigners()

		const TestTokenFactory = await ethers.getContractFactory("TestToken")
		token1 = await TestTokenFactory.deploy("TT1", "TT1")
		token2 = await TestTokenFactory.deploy("TT2", "TT2")

		v2Router = await ethers.getContractAt("IUniswapV2Router02", ADDRESS__UNISWAP_V2_ROUTER)
		v2Factory = await ethers.getContractAt("IUniswapV2Factory", ADDRESS__UNISWAP_V2_FACTORY)

		const CoreFactory = await ethers.getContractFactory("Core")
		core = await CoreFactory.deploy(ADDRESS__UNISWAP_V2_ROUTER, ADDRESS__UNISWAP_V2_FACTORY)
	})

	it("test after construction", async () => {
		expect(await core.router()).to.equal(ADDRESS__UNISWAP_V2_ROUTER)
	})

	it("test addLiquidity", async () => {
		// Transfer tokens to Alice and Bob
		await token1.connect(deployer).transfer(await alice.getAddress(), parseEther("51"))
		await token2.connect(deployer).transfer(await alice.getAddress(), parseEther("50"))

		// Approve tokens for the core
		await token1.connect(alice).approve(await core.getAddress(), parseEther("51"))
		await token2.connect(alice).approve(await core.getAddress(), parseEther("50"))

		// Add liquidity
		await core
			.connect(alice)
			.addLiquidity(await token1.getAddress(), await token2.getAddress(), parseEther("51"), parseEther("50"))

		// Get the pair address
		const pairAddress = await v2Factory.getPair(await token1.getAddress(), await token2.getAddress())
		const pairContract = await ethers.getContractAt("IUniswapV2Pair", pairAddress)
		const balance = await pairContract.balanceOf(await alice.getAddress())

		// Check that Alice received LP tokens
		expect(balance).to.be.gt(0)

		// Check the Amount
		console.log("Balance of token1 : ", await token1.balanceOf(alice))
		console.log("Balance of token2 : ", await token2.balanceOf(alice))
	})

	it("test swapToken", async () => {
		// Transfer tokens to Alice
		await token1.connect(deployer).transfer(await alice.getAddress(), parseEther("20"))

		// Approve tokens for the core
		await token1.connect(alice).approve(await core.getAddress(), parseEther("20"))

		// Swap Token
		const amountOut = await core
			.connect(alice)
			.swapTokens(await token1.getAddress(), await token2.getAddress(), parseEther("20"), parseEther("0"))

		// Check the Amount
		console.log("Balance of token1 : ", await token1.balanceOf(alice))
		console.log("Balance of token2 : ", await token2.balanceOf(alice))
	})

	it("test swapTokenWithETH", async () => {
		// Transfer tokens to Alice
		await token1.connect(deployer).transfer(await alice.getAddress(), parseEther("200"))

		// Approve tokens for the core
		await token1.connect(alice).approve(await core.getAddress(), parseEther("100"))

		// Add liquidity
		await core
			.connect(alice)
			.addLiqudityETH(await token1.getAddress(), parseEther("100"), { value: parseEther("20") })

		// Transfer tokens to Alice
		await token1.connect(deployer).transfer(await alice.getAddress(), parseEther("100"))

		// Approve tokens for the core
		await token1.connect(alice).approve(await core.getAddress(), parseEther("100"))

		// Swap Token
		const amountOut = await core
			.connect(alice)
			.swapTokenWithETH(ADDRESS__WETH, await token1.getAddress(), parseEther("100"), parseEther("0"))

		// Check the Amount
		console.log("Balance of token1 : ", await token1.balanceOf(alice))
		console.log("ETH amount out : ", amountOut.value)
	})
})
