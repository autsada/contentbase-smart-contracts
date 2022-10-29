// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";
import "./ICommentNFT.sol";
import {Constants} from "../../libraries/Constants.sol";
import {Helpers} from "../../libraries/Helpers.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

/**
 * @title Comment NFT
 * This NFT will be minted when a profile comment on a publish.
 * The "createComment", "updateComment", and "burn" only accept calls from the Publish contract.
 */

contract CommentNFT is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ICommentNFT
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    // Publish contract address.
    address public publishContractAddress;

    // Mapping of comment struct by token id.
    mapping(uint256 => DataTypes.Comment) private _tokenById;

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
     * @dev see ICommentNFT - setPublishContractAddress
     */
    function setPublishContractAddress(address publishAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        publishContractAddress = publishAddress;
    }

    /**
     * @dev see ICommentNFT - createComment
     */
    function createComment(
        address owner,
        DataTypes.CreateCommentData calldata createCommentData
    ) external override returns (bool, uint256) {
        // Publish contract address must be set.
        require(publishContractAddress != address(0), "Not ready");

        // Only accept a call from the publish contract.
        require(msg.sender == publishContractAddress, "Forbidden");

        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint an NFT to the caller.
        _safeMint(owner, tokenId);

        // Store the new comment in the mapping.
        _tokenById[tokenId] = DataTypes.Comment({
            owner: owner,
            profileId: createCommentData.profileId,
            publishId: createCommentData.publishId,
            text: createCommentData.text,
            contentURI: createCommentData.contentURI
        });

        return (true, tokenId);
    }

    /**
     * @dev see ICommentNFT - updateComment
     */
    function updateComment(
        address owner,
        DataTypes.UpdateCommentData calldata updateCommentData
    ) external override returns (bool) {
        // Publish contract address must be set.
        require(publishContractAddress != address(0), "Not ready");

        // Only accept a call from the publish contract.
        require(msg.sender == publishContractAddress, "Forbidden");

        uint256 tokenId = updateCommentData.tokenId;

        // The comment must exist.
        require(_exists(tokenId), "Comment not found");

        // Owner must own the token.
        require(ownerOf(tokenId) == owner, "Forbidden");

        // Revert if no change.
        if (
            keccak256(abi.encodePacked(updateCommentData.text)) ==
            keccak256(abi.encodePacked(_tokenById[tokenId].text)) &&
            keccak256(abi.encodePacked(updateCommentData.contentURI)) ==
            keccak256(abi.encodePacked(_tokenById[tokenId].contentURI))
        ) revert("Nothing change");

        // Update the struct.
        // Only update the value that has changed.
        if (
            keccak256(abi.encodePacked(updateCommentData.text)) !=
            keccak256(abi.encodePacked(_tokenById[tokenId].text))
        ) {
            _tokenById[tokenId].text = updateCommentData.text;
        }
        if (
            keccak256(abi.encodePacked(updateCommentData.contentURI)) !=
            keccak256(abi.encodePacked(_tokenById[tokenId].contentURI))
        ) {
            _tokenById[tokenId].contentURI = updateCommentData.contentURI;
        }

        return true;
    }

    /**
     * @dev see ICommentNFT - burn
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

        // Comment must exist.
        require(_exists(tokenId), "Comment not found");

        // The caller must be the owner of the comment.
        require(owner == ownerOf(tokenId), "Forbidden");

        // The comment must belong to the profile.
        require(_tokenById[tokenId].profileId == profileId, "Not allow");

        // Call the parent burn function.
        super.burn(tokenId);

        // Remove the struct from the mapping.
        delete _tokenById[tokenId];

        return true;
    }

    /**
     * @dev see ICommentNFT - getComment
     */
    function getComment(uint256 tokenId)
        external
        view
        override
        returns (DataTypes.Comment memory)
    {
        return _tokenById[tokenId];
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable)
        returns (string memory)
    {
        // Token must exist.
        require(_exists(tokenId), "Comment not found");

        return _tokenById[tokenId].contentURI;
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
