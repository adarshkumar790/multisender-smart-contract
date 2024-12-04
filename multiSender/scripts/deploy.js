const { ethers } = require("hardhat");

async function main() {
    console.log("Compiling contracts...");
    await hre.run('compile');
    const [deployer] = await ethers.getSigners();
    console.log(`Deploying contracts with the account: ${deployer.address}`);
    console.log(`Account balance: ${(await deployer.getBalance()).toString()}`);

    const MultiSender = await ethers.getContractFactory("MultiSender");
    const feeReceiver = "0x27AAC726F6E5124FC567Fb78F80a44BFa33D8e2C"; 
    const txFee = ethers.utils.parseEther("0.01"); 
    const minTxFee = ethers.utils.parseEther("0.005"); 
    const pack0price = ethers.utils.parseEther("0.1"); 
    const pack0validity = 30; 

    console.log("Deploying MultiSender contract...");
    const multiSender = await MultiSender.deploy(
        feeReceiver,
        txFee,
        minTxFee,
        pack0price,
        pack0validity
    );

    await multiSender.deployed();

    console.log(`MultiSender deployed to: ${multiSender.address}`);
    console.log("Verify the contract on a block explorer if needed, using the following details:");
    console.log(`
        Fee Receiver: ${feeReceiver}
        Tx Fee: ${txFee.toString()}
        Min Tx Fee: ${minTxFee.toString()}
        Default VIP Pack Price: ${pack0price.toString()}
        Default VIP Pack Validity: ${pack0validity} days
    `);
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
