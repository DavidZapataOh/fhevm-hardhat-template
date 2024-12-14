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
contract MyConfidentialERC20 is
    SepoliaZamaFHEVMConfig,
    ConfidentialERC20Mintable,
    SepoliaZamaGatewayConfig,
    GatewayCaller
{
    /// @notice Constructor to initialize the token's name and symbol, and set up the owner
    /// @param name_ The name of the token
    /// @param symbol_ The symbol of the token
    constructor(string memory name_, string memory symbol_) ConfidentialERC20Mintable(name_, symbol_, msg.sender) {}

    mapping(address => bool) public isPublicBalance;
    mapping(address => uint256) public exposedBalance;

    event BalanceExposed(uint256 indexed timestamp, address indexed owner, uint256 indexed balance);
    event BalancePublicStatusChanged(address indexed account, bool isPublic);

    function requestExposeBalance() external {
        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(_balances[msg.sender]);

        uint256 requestID = Gateway.requestDecryption(
            cts,
            this.callbackBalance.selector,
            0,
            block.timestamp + 100,
            false
        );

        addParamsUint256(requestID, uint256(uint160(msg.sender)));
    }

    function callbackBalance(uint256 requestID, uint32 exposedBalance_) public onlyGateway returns (uint32) {
        uint256[] memory params = getParamsUint256(requestID);

        address user = address(uint160(params[0]));

        exposedBalance[user] = exposedBalance_;
        emit BalanceExposed(block.timestamp, user, exposedBalance_);
        return exposedBalance_;
    }
}
