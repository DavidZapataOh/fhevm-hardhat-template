// SPDX-License-Identifier: BSD-3-Clause-Clear

pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import { SepoliaZamaFHEVMConfig } from "fhevm/config/ZamaFHEVMConfig.sol";
import { SepoliaZamaGatewayConfig } from "fhevm/config/ZamaGatewayConfig.sol";
import "fhevm-contracts/contracts/token/ERC20/extensions/ConfidentialERC20Mintable.sol";
import "fhevm/gateway/GatewayCaller.sol";

/// @notice This contract implements an encrypted ERC20-like token with confidential balances using Zama's FHE library.
/// @dev It supports typical ERC20 functionality such as transferring tokens, minting, and setting allowances,
/// @dev but uses encrypted data types.
contract MyConfidentialERC20 is SepoliaZamaFHEVMConfig, ConfidentialERC20Mintable, SepoliaZamaGatewayConfig, GatewayCaller {
    /// @notice Constructor to initialize the token's name and symbol, and set up the owner
    /// @param name_ The name of the token
    /// @param symbol_ The symbol of the token
    constructor(string memory name_, string memory symbol_) ConfidentialERC20Mintable(name_, symbol_, msg.sender) {
}

    mapping(address => bool) public isPublicBalance;
    mapping(address => uint256) public exposedBalance;

    event BalanceExposed(uint256 indexed timestamp, address indexed owner, uint256 indexed balance);
    event BalancePublicStatusChanged(address indexed account, bool isPublic);

    function setPublicBalance(bool isPublic) public {
        require(isPublicBalance[msg.sender] != isPublic, "Balance already set");

        isPublicBalance[msg.sender] = isPublic;
        
        if (!isPublic) {
            exposedBalance[msg.sender] = 0;
        } else{
            requestExposeBalance(msg.sender);
        } 
        emit BalancePublicStatusChanged(msg.sender, isPublic);
    }

    function requestExposeBalance(address account) internal {
        require(isPublicBalance[account], "Private balance");
        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(_balances[account]);
        Gateway.requestDecryption(cts, this.callbackBalance.selector, uint256(uint160(account)), block.timestamp + 100, false);
    }

    function callbackBalance(uint256 requestId, uint32 exposedBalance_) public onlyGateway returns (uint32) {
        address user = address(uint160(requestId));
        exposedBalance[user] = exposedBalance_;
        emit BalanceExposed(block.timestamp, user, exposedBalance[user]);
        return exposedBalance_;
    }

    function exposeBalance(address account) public view returns (uint256) {
        require(
            isPublicBalance[account],
            "Private balance"
        );
        return exposedBalance[account];
    }
}
