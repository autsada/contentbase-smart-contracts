// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";

import "./ILike.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

/**
 * @title ContentBase Like
 * @notice Like NFT will be minted when when a porifle likes a publish, the minted NFT will be given to the profile that performs the like.
 * @notice Like operation must be performed in the publish Contract, and this contract will only accept calls from the publish contract.
 */

contract ContentBaseLike is
    Initializable,
    ERC721Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IContentBaseLike
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    // Publish contract.
    address public publishContract;

    // Mapping of like struct by token id.
    mapping(uint256 => DataTypes.Like) private _tokenById;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * Initialize function
     */
    function initialize() public initializer {
        __ERC721_init("ContentBase Like Module", "CLM");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(UPGRADER_ROLE, ADMIN_ROLE);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    /**
     * The modifer to check if the like contract is properly initialized.
     */
    modifier onlyReady() {
        require(publishContract != address(0), "Not ready");
        _;
    }

    /**
     * The modifier to check if the caller is the publish contract.
     */
    modifier onlyPublishContract() {
        require(msg.sender == publishContract, "Not allow");
        _;
    }

    /**
     * @inheritdoc IContentBaseLike
     */
    function updatePublishContract(address contractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        publishContract = contractAddress;
    }

    /**
     * @inheritdoc IContentBaseLike
     * @dev only allow calls from the Publish contract
     */
    function like(
        address owner,
        address profile,
        uint256 publishId
    ) external override onlyReady onlyPublishContract returns (bool, uint256) {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint an NFT to the caller.
        _safeMint(owner, tokenId);

        // Create and store a new Like struct.
        _tokenById[tokenId] = DataTypes.Like({
            owner: owner,
            profileAddress: profile,
            publishId: publishId
        });

        return (true, tokenId);
    }

    // The following functions are overrides required by Solidity.

    /**
     * @notice If it's not the first creation or burn token, the token is non-transferable.
     * @param from {address}
     * @param to {address}
     * @param tokenId {uint256}
     *
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721Upgradeable) {
        if (from != address(0) && to != address(0)) {
            require(
                (msg.sender == ownerOf(tokenId)) &&
                    (msg.sender == from) &&
                    (msg.sender == to),
                "Token is non-transferable"
            );
        }

        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
