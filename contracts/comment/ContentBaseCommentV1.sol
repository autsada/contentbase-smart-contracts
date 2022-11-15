// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";

import {IContentBaseCommentV1} from "./IContentBaseCommentV1.sol";
import {IContentBaseProfileV1} from "../profile/IContentBaseProfileV1.sol";
import {IContentBasePublishV1} from "../publish/IContentBasePublishV1.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Helpers} from "../libraries/Helpers.sol";
import {Events} from "../libraries/Events.sol";

/**
 * @title ContentBaseCommentV1
 * @author Autsada
 *
 * @notice This contract contain 1 ERC721 NFT collection - `COMMENT`.
 * @notice Comment NFTs are burnable.
 * @notice A Comment NFT will be minted upon a profile comments on a publish or a comment.
 */

contract ContentBaseCommentV1 is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IContentBaseCommentV1
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Profile contract address.
    address public profileContract;
    // Publish contract address.
    address public publishContract;

    // Mapping (tokenId => publish struct).
    mapping(uint256 => DataTypes.Comment) private _tokenIdToComment;
    // Mapping of (commentId => (profileId => bool)) to track if a specific profile liked a comment.
    mapping(uint256 => mapping(uint256 => bool))
        internal _commentIdToProfileIdToLikeStatus;
    // Mapping of (commentId => (profileId => bool)) to track if a specific profile disliked the comment.
    mapping(uint256 => mapping(uint256 => bool))
        internal _commentIdToProfileIdToDislikeStatus;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * Initialize function.
     */
    function initialize() public initializer {
        __ERC721_init("ContentBase Comment Module", "CCM");
        __ERC721Burnable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    /**
     * A modifier to check if the contract is ready for use.
     * @dev Extract code inside the modifier to a private function to reduce contract size.
     */
    function _onlyReady() private view {
        require(profileContract != address(0), "Not ready");
        require(publishContract != address(0), "Not ready");
    }

    modifier onlyReady() {
        _onlyReady();
        _;
    }

    /**
     * A modifier to check if the caller own the token.
     * @dev Extract code inside the modifier to a private function to reduce contract size.
     */
    function _onlyTokenOwner(uint256 tokenId) private view {
        require(_exists(tokenId), "Token not found");
        require(ownerOf(tokenId) == msg.sender, "Forbidden");
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        _onlyTokenOwner(tokenId);
        _;
    }

    /**
     * A modifier to check if the given profile id is a ContentBase profile and the caller is the owner.
     * @dev Extract code inside the modifier to a private function to reduce contract size.
     */
    function _onlyProfileOwner(uint256 profileId) private view {
        require(profileContract != address(0), "Not ready");
        address profileOwner = IContentBaseProfileV1(profileContract)
            .profileOwner(profileId);
        require(msg.sender == profileOwner, "Forbidden");
    }

    modifier onlyProfileOwner(uint256 profileId) {
        _onlyProfileOwner(profileId);
        _;
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function updateProfileContract(address contractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        profileContract = contractAddress;
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function updatePublishContract(address contractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        publishContract = contractAddress;
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function createComment(
        DataTypes.CreateCommentData calldata createCommentData
    )
        external
        override
        onlyReady
        onlyProfileOwner(createCommentData.creatorId)
    {
        uint256 targetId = createCommentData.targetId;
        DataTypes.CommentTarget targetType = createCommentData.targetType;

        // Check if the call is for commenting on a Publish or a Comment.
        if (targetType == DataTypes.CommentTarget.PUBLISH) {
            // Comment on a Publish
            // The target publish must exist.
            require(publishContract != address(0), "Not ready");
            require(
                IContentBasePublishV1(publishContract).publishExists(targetId),
                "Publish not found"
            );
        } else {
            // Comment on a Comment
            // The target comment must exist.
            require(_exists(targetId), "Comment not found");
        }

        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint a Comment NFT to the caller.
        _safeMint(msg.sender, tokenId);

        // Create and store a new comment struct in the mapping.
        _tokenIdToComment[tokenId] = DataTypes.Comment({
            owner: msg.sender,
            creatorId: createCommentData.creatorId,
            targetId: createCommentData.targetId,
            targetType: targetType,
            likes: 0,
            disLikes: 0,
            contentURI: createCommentData.contentURI
        });

        // Emit comment created event.
        emit Events.CommentCreated(
            tokenId,
            createCommentData.targetId,
            createCommentData.creatorId,
            targetType,
            msg.sender,
            createCommentData.contentURI,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function updateComment(
        DataTypes.UpdateCommentData calldata updateCommentData
    )
        external
        override
        onlyReady
        onlyProfileOwner(updateCommentData.creatorId)
        onlyTokenOwner(updateCommentData.tokenId)
    {
        uint256 tokenId = updateCommentData.tokenId;

        // The given creatorId must be the profile id that created the comment.
        require(
            _tokenIdToComment[tokenId].creatorId == updateCommentData.creatorId,
            "Not allow"
        );

        // Check if there is any change.
        require(
            keccak256(abi.encodePacked(updateCommentData.newContentURI)) !=
                keccak256(
                    abi.encodePacked(_tokenIdToComment[tokenId].contentURI)
                ),
            "Nothing change"
        );

        // Update the comment struct.
        _tokenIdToComment[tokenId].contentURI = updateCommentData.newContentURI;

        emit Events.CommentUpdated(
            updateCommentData.tokenId,
            updateCommentData.creatorId,
            msg.sender,
            updateCommentData.newContentURI,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function deleteComment(uint256 tokenId, uint256 creatorId)
        external
        override
        onlyReady
        onlyTokenOwner(tokenId)
        onlyProfileOwner(creatorId)
    {
        // The given profile id must be the creator of the comment.
        require(_tokenIdToComment[tokenId].creatorId == creatorId, "Not allow");

        // Call the parent burn function.
        super.burn(tokenId);

        // Remove the struct from the mapping.
        delete _tokenIdToComment[tokenId];

        emit Events.CommentDeleted(
            tokenId,
            creatorId,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function likeComment(uint256 commentId, uint256 profileId)
        external
        override
        onlyReady
        onlyProfileOwner(profileId)
    {
        // The comment must exist.
        require(_exists(commentId), "Comment not found");

        // Check if the call is for `like` or `unlike`.
        bool isLiked = _commentIdToProfileIdToLikeStatus[commentId][profileId];

        if (!isLiked) {
            // LIKE

            // Update the comment to profile to like status mapping.
            _commentIdToProfileIdToLikeStatus[commentId][profileId] = true;

            // Update the comment struct `likes` count.
            _tokenIdToComment[commentId].likes++;

            // If the profile `dislike` the comment before, update the dislike states.
            if (_commentIdToProfileIdToDislikeStatus[commentId][profileId]) {
                _commentIdToProfileIdToDislikeStatus[commentId][
                    profileId
                ] = false;

                // Update the comment `dislikes` count.
                if (_tokenIdToComment[commentId].disLikes > 0) {
                    _tokenIdToComment[commentId].disLikes--;
                }
            }

            // Emit comment liked event.
            emit Events.CommentLiked(
                commentId,
                profileId,
                ownerOf(commentId),
                msg.sender,
                _tokenIdToComment[commentId].likes,
                _tokenIdToComment[commentId].disLikes,
                block.timestamp
            );
        } else {
            // UNLIKE

            // Update the comment to profile to like mapping.
            _commentIdToProfileIdToLikeStatus[commentId][profileId] = false;

            // Update the comment struct `likes` count.
            if (_tokenIdToComment[commentId].likes > 0) {
                _tokenIdToComment[commentId].likes--;
            }

            // Emit comment unliked event.
            emit Events.CommentUnLiked(
                commentId,
                profileId,
                msg.sender,
                _tokenIdToComment[commentId].likes,
                _tokenIdToComment[commentId].disLikes,
                block.timestamp
            );
        }
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function disLikeComment(uint256 commentId, uint256 profileId)
        external
        override
        onlyReady
        onlyProfileOwner(profileId)
    {
        // The comment must exist.
        require(_exists(commentId), "Comment not found");

        // Check if the call is for `dislike` or `undoDislike`.
        bool isDisLiked = _commentIdToProfileIdToDislikeStatus[commentId][
            profileId
        ];

        if (!isDisLiked) {
            // DISLIKE

            // Update the comment to profile to dislike status mapping.
            _commentIdToProfileIdToDislikeStatus[commentId][profileId] = true;

            // Update the comment struct `disLikes` count.
            _tokenIdToComment[commentId].disLikes++;

            // If the profile `like` the comment before, update the like states.
            if (_commentIdToProfileIdToLikeStatus[commentId][profileId]) {
                _commentIdToProfileIdToLikeStatus[commentId][profileId] = false;

                // Update the comment `likes` count.
                if (_tokenIdToComment[commentId].likes > 0) {
                    _tokenIdToComment[commentId].likes--;
                }
            }

            // Emit comment disliked event.
            emit Events.CommentDisLiked(
                commentId,
                profileId,
                msg.sender,
                _tokenIdToComment[commentId].likes,
                _tokenIdToComment[commentId].disLikes,
                block.timestamp
            );
        } else {
            // UNDO DISLIKE

            // Update the comment to profile to dislike status mapping.
            _commentIdToProfileIdToDislikeStatus[commentId][profileId] = false;

            // Update the comment struct `disLikes` count.
            if (_tokenIdToComment[commentId].disLikes > 0) {
                _tokenIdToComment[commentId].disLikes--;
            }

            // Emit comment disliked event.
            emit Events.CommentUndoDisLiked(
                commentId,
                profileId,
                msg.sender,
                _tokenIdToComment[commentId].likes,
                _tokenIdToComment[commentId].disLikes,
                block.timestamp
            );
        }
    }

    /**
     * Override the parent burn function.
     * @dev Force `burn` function to use `deleteComment` function so we can update the related states.
     */
    function burn(uint256 tokenId) public view override {
        if (ownerOf(tokenId) != msg.sender) {
            revert("Forbidden");
        } else {
            revert("Use `deleteComment` function instead");
        }
    }

    /**
     * Return a content uri of the comment.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        return _tokenIdToComment[tokenId].contentURI;
    }

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
