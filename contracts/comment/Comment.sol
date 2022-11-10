// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";

import "./IComment.sol";
import "../IProfileFactory.sol";
import "../publish/IPublish.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";
import {Events} from "../../libraries/Events.sol";

/**
 * @title ContentBase Comment
 * Comment NFT will be minted when a profile comment on a publish.
 * @dev all write functions must me guarded with `onlyProfileOwner` to make sure the given profile address is a valid ContentBase profile.
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

    // Profile factory address for use to validate profiles.
    address public factoryContract;
    // Publish contract address.
    address public publishContract;

    // Mapping of comment struct by token id.
    mapping(uint256 => DataTypes.Comment) private _tokenById;
    // Mapping of (commentId => (profileAddress => bool)) to track if a specific profile id liked the comment.
    mapping(uint256 => mapping(address => bool)) private _commentToLikedProfile;
    // Mapping of (commentId => (profileAddress => bool)) to track if a specific profile disliked the comment.
    mapping(uint256 => mapping(address => bool))
        private _commentToDislikedProfile;

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
     * The modifer to check the publish contract is properly initialized.
     */
    modifier onlyReady() {
        require(factoryContract != address(0), "Not ready");
        require(publishContract != address(0), "Not ready");
        _;
    }

    /**
     * The modifier to check if the caller owns the profile, and it will also check if the given profile address is a ContentBase profile.
     */
    modifier onlyProfileOwner(address profileAddress) {
        address profileOwner = IContentBaseProfileFactory(factoryContract)
            .getProfileOwner(profileAddress);

        require(msg.sender == profileOwner, "Forbidden");

        _;
    }

    /**
     * @inheritdoc IContentBaseComment
     */
    function updateFactoryContract(address factoryAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        factoryContract = factoryAddress;
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
     * @dev This function is used for both the `main` comment where the comment is made on a publish and the `sub` comment where the comment is made on other comment.
     */
    function createComment(
        DataTypes.CreateCommentData calldata createCommentData
    )
        external
        override
        onlyReady
        onlyProfileOwner(createCommentData.profileAddress)
    {
        uint256 publishId = createCommentData.publishId;

        // The publish to be commented on must exist.
        require(
            IContentBasePublish(publishContract).publishExist(publishId),
            "Publish not found"
        );

        // If the call is for `sub` comment, the given comment id must exist.
        if (createCommentData.commentId != 0) {
            require(_exists(createCommentData.commentId), "Comment not found");
        }

        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint an NFT to the caller.
        _safeMint(msg.sender, tokenId);

        // Store the new comment in the mapping.
        _tokenById[tokenId] = DataTypes.Comment({
            owner: msg.sender,
            profileAddress: createCommentData.profileAddress,
            publishId: createCommentData.publishId,
            commentId: createCommentData.commentId,
            likes: 0,
            disLikes: 0,
            text: createCommentData.text,
            contentURI: createCommentData.contentURI
        });

        // Emit comment created event.
        emit Events.CommentCreated(
            tokenId,
            createCommentData.publishId,
            createCommentData.profileAddress,
            msg.sender,
            createCommentData.text,
            createCommentData.contentURI,
            createCommentData.commentId,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBaseComment
     */
    function updateComment(
        DataTypes.UpdateCommentData calldata updateCommentData
    )
        external
        override
        onlyReady
        onlyProfileOwner(updateCommentData.profileAddress)
    {
        uint256 tokenId = updateCommentData.tokenId;
        uint256 publishId = updateCommentData.publishId;

        // The comment must exist.
        require(_exists(tokenId), "Comment not found");

        // Caller must own the token.
        require(ownerOf(tokenId) == msg.sender, "Forbidden");

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

        emit Events.CommentUpdated(
            updateCommentData.tokenId,
            publishId,
            updateCommentData.profileAddress,
            msg.sender,
            updateCommentData.text,
            updateCommentData.contentURI,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBaseComment
     */
    /**
     * @dev Since we only allow calls from the publish contract and we check the original caller and a given profile there so we don't need to check the owner and profile here again.
     */
    function deleteComment(
        uint256 tokenId,
        uint256 publishId,
        address profileAddress
    ) external override onlyReady onlyProfileOwner(profileAddress) {
        // Comment must exist.
        require(_exists(tokenId), "Comment not found");

        // The caller must be the owner of the comment.
        require(msg.sender == ownerOf(tokenId), "Forbidden");

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

        emit Events.CommentDeleted(tokenId, publishId, block.timestamp);
    }

    /**
     * @inheritdoc IContentBaseComment
     * @dev No Like NFT minted for like comment.
     */
    function likeComment(DataTypes.LikeData calldata likeData)
        external
        override
        onlyReady
        onlyProfileOwner(likeData.profileAddress)
    {
        uint256 commentId = likeData.publishId; // This is the comment id
        address profileAddress = likeData.profileAddress;

        // The comment must exist.
        require(_exists(commentId), "Comment not found");

        // Get the Comment's owner address.
        address commentOwner = ownerOf(commentId);

        // Identify if the call is for `like` or `unlike`.
        bool isLiked = _commentToLikedProfile[commentId][profileAddress];

        if (!isLiked) {
            // LIKE

            // Update the liked mapping.
            _commentToLikedProfile[commentId][profileAddress] = true;

            // Increase the comment struct likes.
            _tokenById[commentId].likes++;

            // If the profile disliked the comment before, we need to update the disliked mapping and decrease the comment's dislikes count as well.
            if (_commentToDislikedProfile[commentId][profileAddress]) {
                _commentToDislikedProfile[commentId][profileAddress] = false;

                if (_tokenById[commentId].disLikes > 0) {
                    _tokenById[commentId].disLikes--;
                }
            }

            // Emit like event.
            emit Events.CommentLiked(
                commentId,
                commentOwner,
                profileAddress,
                msg.sender,
                _tokenById[commentId].likes,
                _tokenById[commentId].disLikes,
                block.timestamp
            );
        } else {
            // UNLIKE

            // Make sure the profile liked the comment before.
            require(
                _commentToLikedProfile[commentId][profileAddress],
                "Undo like failed"
            );

            // Update the liked mapping.
            _commentToLikedProfile[commentId][profileAddress] = false;

            // Decrease the comment struct likes.
            // Make sure the count is greater than 0.
            if (_tokenById[commentId].likes > 0) {
                _tokenById[commentId].likes--;
            }

            // emit unlike even.
            emit Events.CommentUnLiked(
                commentId,
                profileAddress,
                msg.sender,
                _tokenById[commentId].likes,
                _tokenById[commentId].disLikes,
                block.timestamp
            );
        }
    }

    /**
     * @inheritdoc IContentBaseComment
     * @dev use this function for both `dislike` and `undo dislike`
     */
    function disLikeComment(DataTypes.LikeData calldata likeData)
        external
        override
        onlyReady
        onlyProfileOwner(likeData.profileAddress)
    {
        uint256 commentId = likeData.publishId; // `likeData.publishId` is a comment id.
        address profileAddress = likeData.profileAddress;

        // The comment must exist.
        require(_exists(commentId), "Comment not found");

        // Identify if the call is for `dislike` or `undo dislike`.
        bool isDisLiked = _commentToDislikedProfile[commentId][profileAddress];

        if (!isDisLiked) {
            // DISLIKE

            // Update the disliked mapping.
            _commentToDislikedProfile[commentId][profileAddress] = true;

            // Increase the comment struct disLikes.
            _tokenById[commentId].disLikes++;

            // If the profile liked the comment before, we need to update the liked mapping and decrease the comment's likes count as well.
            if (_commentToLikedProfile[commentId][profileAddress]) {
                _commentToLikedProfile[commentId][profileAddress] = false;

                if (_tokenById[commentId].likes > 0) {
                    _tokenById[commentId].likes--;
                }
            }

            // Emit dislike event.
            emit Events.CommentDisLiked(
                commentId,
                profileAddress,
                msg.sender,
                _tokenById[commentId].likes,
                _tokenById[commentId].disLikes,
                block.timestamp
            );
        } else {
            // UNDO DISLIKE

            // Make sure the profile has disliked the comment before.
            require(
                _commentToDislikedProfile[commentId][profileAddress],
                "Undo failed"
            );

            // Update the disliked mapping.
            _commentToDislikedProfile[commentId][profileAddress] = false;

            // Decrease dislikes count.
            // Make sure the count is greater than 0.
            if (_tokenById[commentId].disLikes > 0) {
                _tokenById[commentId].disLikes--;
            }

            // emit unlike even.
            emit Events.CommentUndoDisLiked(
                commentId,
                profileAddress,
                msg.sender,
                _tokenById[commentId].likes,
                _tokenById[commentId].disLikes,
                block.timestamp
            );
        }
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
