import { Signer, parseEther } from "ethers"
import { ethers, network } from "hardhat"
import { expect } from "chai"
import { FlashLoan, IERC20 } from "typechain-types"

describe("FlashLoan", () => {
	const ADDRESS__AAVE_V3_PROVIDER = "0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e"
	const ADDRESS__UNISWAP_V2_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"
	const ADDRESS__UNISWAP_V2_FACTORY = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"
	const ADDRESS__DAI_TOKEN = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
	const DAI_HOLDER = "0xD1668fB5F690C59Ab4B0CAbAd0f8C1617895052B"

	let deployer: Signer, alice: Signer
	let core: FlashLoan
	let daiToken: IERC20

	before(async () => {
		// get signers from the hardhat node
		;[deployer, alice] = await ethers.getSigners()

		// dai token contract
		daiToken = await ethers.getContractAt("IERC20", ADDRESS__DAI_TOKEN)

		// deploy the FlashLoan contract
		const FlashLoanFactory = await ethers.getContractFactory("FlashLoan")
		core = await FlashLoanFactory.connect(deployer).deploy(
			ADDRESS__AAVE_V3_PROVIDER,
			ADDRESS__UNISWAP_V2_ROUTER,
			ADDRESS__UNISWAP_V2_FACTORY
		)

		// send 1000 DAI to alice and bob
		await network.provider.request({
			method: "hardhat_impersonateAccount",
			params: [DAI_HOLDER],
		})
		const daiHolder = await ethers.getSigner(DAI_HOLDER)
		await daiToken.connect(daiHolder).transfer(alice, ethers.parseEther("1000"))
		await network.provider.request({
			method: "hardhat_stopImpersonatingAccount",
			params: [DAI_HOLDER],
		})
	})

	it("test requestFlashLoan function", async () => {
		await daiToken.connect(alice).transfer(core, ethers.parseEther("100"))

		await core.connect(alice).requestFlashLoan(daiToken, ethers.parseEther("100"))

		console.log(await daiToken.balanceOf(core))
	})
})
