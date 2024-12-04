require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");

module.exports = {
  solidity: "0.8.0",
  networks: {
    arbitrumSepolia: {
      url: "https://arbitrum-sepolia.infura.io/v3/a0b3a1898f1c4fc5b17650f6647cbcd2",
      accounts: ["202576bf6f2a36d746f9dc2907b81f2b1d5e575037758a47a022c192f89c9287"]
    }
  },
  etherscan: {
    apiKey:"Z6ENI8PIMNV4FJ2CX9B5BF7SGWF84PD9DA"
  }
};
