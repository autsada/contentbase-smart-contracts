// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";

import "./IComment.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

/**
 * @title ContentBase Comment
 * Comment NFT will be minted when a profile comment on a publish, the minted NFT will be given to the profile that performs the comment.
 * The "createComment", "updateComment", and "burn" only accept calls from the publish contract.
 */

contract ContentBaseComment is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IContentBaseComment
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    // Publish contract address.
    address public publishContract;

    // Mapping of comment struct by token id.
    mapping(uint256 => DataTypes.Comment) private _tokenById;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("ContentBase Comment Module", "CCM");
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
     * The modifier to check if the caller is the publish contract.
     */
    modifier onlyPublishContract() {
        // Publish contract address must be set.
        require(publishContract != address(0), "Not ready");

        // Only accept a call from the publish contract.
        require(msg.sender == publishContract, "Forbidden");

        _;
    }

    /**
     * @inheritdoc IContentBaseComment
     */
    function updatePublishContract(address publishAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        publishContract = publishAddress;
    }

    /**
     * @inheritdoc IContentBaseComment
     */
    /**
     * @dev Since we only allow calls from the publish contract and we check the original caller and a given profile there so we don't need to check the owner and profile here again.
     */
    function createComment(
        address owner,
        DataTypes.CreateCommentData calldata createCommentData
    ) external override onlyPublishContract returns (bool, uint256) {
        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint an NFT to the caller.
        _safeMint(owner, tokenId);

        // Store the new comment in the mapping.
        _tokenById[tokenId] = DataTypes.Comment({
            owner: owner,
            profileAddress: createCommentData.profileAddress,
            publishId: createCommentData.publishId,
            text: createCommentData.text,
            contentURI: createCommentData.contentURI
        });

        return (true, tokenId);
    }

    /**
     * @inheritdoc IContentBaseComment
     */
    /**
     * @dev Since we only allow calls from the publish contract and we check the original caller and a given profile there so we don't need to check the owner and profile here again.
     */
    function updateComment(
        address owner,
        DataTypes.UpdateCommentData calldata updateCommentData
    ) external override onlyPublishContract returns (bool) {
        uint256 tokenId = updateCommentData.tokenId;
        uint256 publishId = updateCommentData.publishId;

        // The comment must exist.
        require(_exists(tokenId), "Comment not found");

        // Owner must own the token.
        require(ownerOf(tokenId) == owner, "Forbidden");

        // The given publish id must match the publish id in the comment struct.
        require(publishId == _tokenById[tokenId].publishId);

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
     * @inheritdoc IContentBaseComment
     */
    /**
     * @dev Since we only allow calls from the publish contract and we check the original caller and a given profile there so we don't need to check the owner and profile here again.
     */
    function burn(
        uint256 tokenId,
        uint256 publishId,
        address owner,
        address profileAddress
    ) external override onlyPublishContract returns (bool) {
        // Comment must exist.
        require(_exists(tokenId), "Comment not found");

        // The caller must be the owner of the comment.
        require(owner == ownerOf(tokenId), "Forbidden");

        // the given publish id must match the publish id on the token struct.
        require(_tokenById[tokenId].publishId == publishId, "Bad input");

        // The given profile address must be the creator of the comment.
        require(
            _tokenById[tokenId].profileAddress == profileAddress,
            "Not allow"
        );

        // Call the parent burn function.
        super.burn(tokenId);

        // Remove the struct from the mapping.
        delete _tokenById[tokenId];

        return true;
    }

    /**
     * @dev see IContentBaseCommentNFT - getComment
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
