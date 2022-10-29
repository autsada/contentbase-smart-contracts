// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";
import "./ILikeNFT.sol";
import {Constants} from "../../libraries/Constants.sol";
import {Helpers} from "../../libraries/Helpers.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

/**
 * @title Like NFT
 * This NFT will be minted when a profile likes a publish.
 *
 */

contract LikeNFT is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ILikeNFT
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    // Publish contract address.
    address public publishContractAddress;

    // Mapping of like struct by token id.
    mapping(uint256 => DataTypes.Like) private _tokenById;
    // Mapping of (publishId => (profileId => bool)) to track if a specific profile id has liked the publish, (1 => (1 => true)) means publish id 1 has been liked by profile id 1.
    mapping(uint256 => mapping(uint256 => bool)) private _likesList;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("Content Base Publish", "CBPu");
        __ERC721Burnable_init();
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
     * @dev see ILikeNFT - setPublishContractAddress
     */
    function setPublishContractAddress(address publishAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        publishContractAddress = publishAddress;
    }

    /**
     * @dev see ILikeNFT - createLike
     */
    function createLike(address owner, DataTypes.LikeData calldata likeData)
        external
        override
        returns (bool, uint256)
    {
        // Publish contract address must be set.
        require(publishContractAddress != address(0), "Not ready");

        // Only accept a call from the publish contract.
        require(msg.sender == publishContractAddress, "Forbidden");

        uint256 publishId = likeData.publishId;
        uint256 profileId = likeData.profileId;

        // Revert if the profile already liked the publish.
        if (_likesList[publishId][profileId]) revert("Already liked");

        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint an NFT to the caller.
        _safeMint(owner, tokenId);

        // Store the new like in the mapping.
        _tokenById[tokenId] = DataTypes.Like({
            owner: owner,
            profileId: profileId,
            publishId: publishId
        });

        // Update the likes list mapping.
        _likesList[publishId][profileId] = true;

        return (true, tokenId);
    }

    /**
     * @dev see ILikeNFT - burn
     */
    function burn(
        uint256 tokenId,
        address owner,
        uint256 profileId
    ) external override returns (bool) {
        // Publish contract address must be set.
        require(publishContractAddress != address(0), "Not ready");

        // Only accept a call from the publish contract.
        require(msg.sender == publishContractAddress, "Forbidden");

        // Like must exist.
        require(_exists(tokenId), "Like not found");

        // The caller must be the owner of the like.
        require(owner == ownerOf(tokenId), "Forbidden");

        // Get the token.
        DataTypes.Like memory token = _tokenById[tokenId];

        // The like must belong to the profile.
        require(token.profileId == profileId, "Not allow");

        // The profile must have been liked the publish.
        require(_likesList[token.publishId][profileId], "Bad request");

        // Call the parent burn function.
        super.burn(tokenId);

        // Remove the profile from the likes list mapping.
        delete _likesList[token.publishId][profileId];

        // Remove the struct from the mapping.
        delete _tokenById[tokenId];

        return true;
    }

    /**
     * @dev see ILikeNFT - getLike
     */
    function getLike(uint256 tokenId)
        external
        view
        override
        returns (DataTypes.Like memory)
    {
        return _tokenById[tokenId];
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
