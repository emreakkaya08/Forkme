//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../core/contract-upgradeable/VersionUpgradeable.sol";
import "../core/contract-upgradeable/interface/IERCMINTExt20.sol";

contract TokenDeposit is
    Initializable,
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    VersionUpgradeable
{
    // the role that can pause the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    // the role that used for upgrading the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    // admin role
    bytes32 public constant ADMIN = keccak256("ADMIN");
    // deposit role, special game account
    bytes32 public constant DEPOSIT_ROLE = keccak256("DEPOSIT_ROLE");

    IERCMINTExt20 public cenoToken;

    address public treasuryAddress;

    mapping(address => uint256) private exchangeRates;

    event DepositERC20(
        address indexed caller,
        address indexed receiver,
        uint256 amount,
        uint256 cenoTokenAmount
    );

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

    function initialize(
        address _cenoToken,
        address _treasuryAddress
    ) public initializer {
        __AccessControlEnumerable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __VersionUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(ADMIN, msg.sender);

        cenoToken = IERCMINTExt20(_cenoToken);
        treasuryAddress = _treasuryAddress;
    }

    function addExchangeRate(
        address tokenAddress,
        uint256 rate
    ) public whenNotPaused nonReentrant onlyRole(ADMIN) {
        require(tokenAddress != address(0), "Token address cannot be zero");
        require(rate > 0, "Exchange rate must be greater than 0");
        require(exchangeRates[tokenAddress] == 0, "Token already exists");

        exchangeRates[tokenAddress] = rate;
    }

    function getExchangeRate(
        address tokenAddress
    ) public view returns (uint256) {
        require(tokenAddress != address(0), "Token address cannot be zero");
        require(exchangeRates[tokenAddress] != 0, "Token not supported");

        return exchangeRates[tokenAddress];
    }

    function depositERC20(
        address tokenAddress,
        address to,
        uint256 amount
    ) public nonReentrant whenNotPaused onlyRole(DEPOSIT_ROLE) {
        uint256 rate = exchangeRates[tokenAddress];

        require(rate != 0, "Token not supported");

        IERC20Upgradeable erc20Token = IERC20Upgradeable(tokenAddress);

        // make sure the user has approved the transfer of USDT to this contract
        require(
            erc20Token.allowance(to, address(this)) >= amount,
            "Must approve ERC20Token first"
        );

        // transfer the USDT from the user to treasury contract
        SafeERC20Upgradeable.safeTransferFrom(
            erc20Token,
            to,
            treasuryAddress,
            amount
        );

        uint256 mintValue = amount * rate;

        // mint the equivalent amount of cenoToken to the user
        cenoToken.mint(to, mintValue);

        emit DepositERC20(_msgSender(), to, amount, mintValue);
    }
}
