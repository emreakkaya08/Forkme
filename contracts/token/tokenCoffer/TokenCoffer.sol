//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../../core/contract-upgradeable/VersionUpgradeable.sol";

contract TokenCoffer is
Initializable,
AccessControlEnumerableUpgradeable,
ReentrancyGuardUpgradeable,
PausableUpgradeable,
UUPSUpgradeable,
VersionUpgradeable
{
    event TokenReceived(address from, uint256 amount);
    event Withdraw(address to, uint256 amount);
    event WithdrawERC20(
        IERC20Upgradeable indexed token,
        address indexed to,
        uint256 amount
    );
    
    bytes32 public constant WITHDRAW = keccak256("WITHDRAW");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}
    
    function _version() internal pure virtual override returns (uint256) {
        return 1;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __AccessControlEnumerable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __VersionUpgradeable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }
    
    receive() external payable virtual {
        emit TokenReceived(_msgSender(), msg.value);
    }
    
    function withdraw(
        address payable to,
        uint256 amount
    ) public whenNotPaused nonReentrant onlyRole(WITHDRAW) {
        AddressUpgradeable.sendValue(to, amount);
        emit Withdraw(to, amount);
    }
    
    function withdrawERC20(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) public whenNotPaused nonReentrant onlyRole(WITHDRAW) {
        SafeERC20Upgradeable.safeTransfer(token, to, value);
        emit WithdrawERC20(token, to, value);
    }
    
    function refreshApprove(
        IERC20Upgradeable token,
        address spender
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 remainingAllowance = token.allowance(address(this), spender);
        if (remainingAllowance > 0) {
            SafeERC20Upgradeable.safeApprove(
                token,
                spender,
                0
            );
        }
        
        // TODO
        // transfer the remaining ZOIC that players didn't claim to the vault
        // SafeERC20Upgradeable.safeTransfer(token, vault, token.balance(this));
        
        SafeERC20Upgradeable.safeApprove(token, spender, 10 ** 18);
    }
}
