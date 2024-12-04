// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./IERC20.sol";

/**
 * @title MultiSender
 * @dev A contract that supports VIP subscriptions, minimum fees, per transaction fees and allows batch sending of tokens.
 */
contract MultiSender is Ownable {
    IERC20 private tokenContract; // Token interface for interactions with ERC20 tokens.
    address payable public feeReceiver; // Address to receive transaction fees.
    mapping(address => uint) public isVipTill; // Mapping to track VIP status expiration for addresses.
    mapping(uint8 => Pack) public vipPacks; // VIP packs defined by ID, price, and validity duration.
    uint public txFee; // Fee charged per transaction (per address in multisend).
    uint public minTxFee; // Minimum transaction fee for any operation.

    // Events for logging key state changes and actions.
    event NewVipUser(address indexed userAddress, uint indexed price, uint indexed validity);
    event VipPackUpdated(uint8 indexed pid, uint indexed price, uint indexed validity);
    event TxFeeUpdated(uint indexed newTxFee);
    event MinTxFeeUpdated(uint indexed newMinTxFee);

    // Structure defining a VIP Pack with price and validity duration.
    struct Pack {
        uint price; // Price of the VIP pack.
        uint validity; // Validity of the pack in seconds.
    }

    /**
     * @dev Constructor to initialize the MultiSender contract.
     * @param _feeReceiver Address that will receive transaction fees.
     * @param _txFee Fee per address in a multisend transaction.
     * @param _minTxFee Minimum fee charged for a transaction.
     * @param _pack0price Price of the default VIP pack.
     * @param _pack0validity Validity of the default VIP pack in days.
     */
    constructor(address payable _feeReceiver, uint _txFee, uint _minTxFee, uint _pack0price, uint _pack0validity) {
        feeReceiver = _feeReceiver;
        txFee = _txFee;
        emit TxFeeUpdated(_txFee); // Log initial transaction fee.
        minTxFee = _minTxFee;
        emit MinTxFeeUpdated(_minTxFee); 
        
        // Grant the deployer a long-term VIP status.
        isVipTill[msg.sender] = block.timestamp + 100000 days;
        emit NewVipUser(msg.sender, 0, 100000 days);

        // Initialize the default VIP pack.
        vipPacks[0] = Pack(_pack0price, _pack0validity * 1 days);
        emit VipPackUpdated(0, _pack0price, _pack0validity * 1 days);
    }

    /**
     * @dev Owner-only function to define or update VIP packs.
     * @param _pid The ID of the VIP pack.
     * @param _price Price of the pack in wei.
     * @param _validity Validity of the pack in days.
     */
    function setVipPacks(uint8 _pid, uint _price, uint _validity) public onlyOwner {
        vipPacks[_pid] = Pack(_price, _validity * 1 days);
        emit VipPackUpdated(_pid, _price, _validity);
    }

    /**
     * @dev Allows a user to become a VIP by purchasing a VIP pack.
     * @param _pid The ID of the VIP pack to purchase.
     */
    function becomeVip(uint8 _pid) external payable {
        require(msg.value >= vipPacks[_pid].price, "value doesn't cover vip price");
        feeReceiver.transfer(msg.value); // Transfer fees to the fee receiver.
        isVipTill[msg.sender] = block.timestamp + vipPacks[_pid].validity;

        emit NewVipUser(msg.sender, vipPacks[_pid].price, isVipTill[msg.sender]);
    }

    /**
     * @dev Check if an address has VIP status.
     * @param _addressToCheck Address to check for VIP status.
     * @return True if the address has active VIP status, false otherwise.
     */
    function isVip(address _addressToCheck) public view returns (bool) {
        return isVipTill[_addressToCheck] > block.timestamp;
    }

    /**
     * @dev Owner-only function to manually grant VIP status to an address.
     * @param _addressToAdd Address to grant VIP status.
     * @param _isVipTill Timestamp until when the VIP status is valid.
     */
    function addVip(address _addressToAdd, uint _isVipTill) external onlyOwner {
        isVipTill[_addressToAdd] = _isVipTill;
        emit NewVipUser(_addressToAdd, 0, _isVipTill);
    }

    /**
     * @dev Owner-only function to remove VIP status from an address.
     * @param _addressToRemove Address to revoke VIP status.
     */
    function removeVip(address _addressToRemove) external onlyOwner {
        isVipTill[_addressToRemove] = 0;
    }

    /**
     * @dev Calculate the fee for a multisend transaction.
     * @param noOfAddresses Number of recipient addresses in the transaction.
     * @return The fee amount in wei.
     */
    function calculateFee(uint noOfAddresses) public view returns (uint) {
        require(noOfAddresses > 0, "empty input");
        uint fee = txFee * noOfAddresses;
        return fee < minTxFee ? minTxFee : fee;
    }

    /**
     * @dev Owner-only function to set the transaction fee.
     * @param _txFee Fee per address in a multisend transaction.
     */
    function setTxFee(uint _txFee) onlyOwner external {
        txFee = _txFee;
        emit TxFeeUpdated(_txFee);
    }

    /**
     * @dev Owner-only function to set the minimum transaction fee.
     * @param _minTxfee Minimum transaction fee.
     */
    function setMinTxFee(uint _minTxfee) onlyOwner external {
        minTxFee = _minTxfee;
        emit MinTxFeeUpdated(_minTxfee);
    }

    /**
     * @dev Multisend ERC20 tokens to multiple addresses.
     * @param _tokenContractAddress Address of the ERC20 token contract.
     * @param _addressesArray Array of recipient addresses.
     * @param _amountsArray Array of token amounts corresponding to each address.
     */
    function multisendToken(address _tokenContractAddress, address[] calldata _addressesArray, uint[] calldata _amountsArray) external payable {
        require(_tokenContractAddress != address(0), "invalid tokenAddress");
        uint arrLen = _addressesArray.length;
        require(arrLen > 0 && arrLen < 200, "Input exceeds maximum batch size");
        uint fee = isVip(msg.sender) ? 0 : calculateFee(arrLen);
        require(msg.value >= fee && arrLen == _amountsArray.length, "Value<txFee or arrayLength misMatch");
        
        feeReceiver.transfer(msg.value); // Transfer fees to fee receiver.
        tokenContract = IERC20(_tokenContractAddress);
        
        for (uint i = 0; i < arrLen; i++) {
            require(tokenContract.transferFrom(msg.sender, _addressesArray[i], _amountsArray[i]), "token transfer failed");
        }
    }

    /**
     * @dev Owner-only function to recover tokens accidentally sent to the contract.
     * @param _tokenContractAddress Address of the token contract.
     * @param _recipient Address to receive the recovered tokens.
     * @param _amount Amount of tokens to recover.
     */
    function recoverTokens(address _tokenContractAddress, address _recipient, uint _amount) public onlyOwner {
        require(_recipient != address(0), "Invalid recipient address");
        tokenContract = IERC20(_tokenContractAddress);
        require(tokenContract.transfer(_recipient, _amount), "token transfer failed");
    }

    /**
     * @dev Owner-only function to recover ethers accidentally sent to the contract.
     * @param _recipient Address to receive the recovered ethers.
     * @param _amount Amount of ether to recover.
     */
    function recoverEthers(address payable _recipient, uint _amount) public onlyOwner {
        require(_recipient != address(0), "Invalid recipient address");
        _recipient.transfer(_amount);
    }

    /**
     * @dev Owner-only function to change the fee receiver address.
     * @param _newFeeReceiver New fee receiver address.
     */
    function changeFeeReceiver(address payable _newFeeReceiver) public onlyOwner {
        feeReceiver = _newFeeReceiver;
    }
}
