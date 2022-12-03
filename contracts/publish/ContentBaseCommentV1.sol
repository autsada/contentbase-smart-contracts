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
import {IContentBasePublishV1} from "./IContentBasePublishV1.sol";
import {IContentBaseProfileV1} from "../profile/IContentBaseProfileV1.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Helpers} from "../libraries/Helpers.sol";

/**
 * @title ContentBaseCommentV1
 * @author Autsada T
 *
 * @notice A comment NFT will be minted and given to the caller when they use their profile to comment on a Publish or a Comment.
 * @notice The comment NFTs are non-burnable.
 * @notice No like NFT minted when a comment is liked, just to update its `likes` count.
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

    // A private state to store the profile contract address.
    address private _profileContractAddress;
    // A private state to store the publish contract address.
    address private _publishContractAddress;
    // Mapping (tokenId => comment struct).
    mapping(uint256 => DataTypes.Comment) private _tokenIdToComment;
    // Mapping of (commentId => (profileId => bool)) to track if a specific profile liked a comment.
    mapping(uint256 => mapping(uint256 => bool))
        private _commentIdToProfileIdToLikeStatus;
    // Mapping of (commentId => (profileId => bool)) to track if a specific profile disliked the comment.
    mapping(uint256 => mapping(uint256 => bool))
        private _commentIdToProfileIdToDislikeStatus;

    // Events.
    event CommentCreated(
        uint256 indexed tokenId,
        uint256 indexed parentId,
        uint256 indexed creatorId,
        address owner,
        string contentURI,
        DataTypes.CommentType commentType,
        uint256 timestamp
    );
    event CommentUpdated(
        uint256 indexed tokenId,
        string contentURI,
        uint256 timestamp
    );
    event CommentDeleted(uint256 indexed tokenId, uint256 timestamp);
    event CommentLiked(
        uint256 indexed commentId,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );
    event CommentUnLiked(
        uint256 indexed commentId,
        uint32 likes,
        uint256 timestamp
    );
    event CommentDisLiked(
        uint256 indexed commentId,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );
    event CommentUndoDisLiked(
        uint256 indexed commentId,
        uint32 disLikes,
        uint256 timestamp
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * Initialize function.
     */
    function initialize(
        address profileContractAddress,
        address publishContractAddress
    ) public initializer {
        __ERC721_init("ContentBase Publish Module", "CPM");
        __ERC721Burnable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        _profileContractAddress = profileContractAddress;
        _publishContractAddress = publishContractAddress;
    }

    /**
     * A modifier to check if the contract is ready for use.
     * @dev Extract code inside the modifier to a private function to reduce contract size.
     */
    function _onlyReady() private view {
        require(
            _profileContractAddress != address(0),
            "Profile contract not set"
        );
        require(
            _publishContractAddress != address(0),
            "Publish contract not set"
        );
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
        require(
            _profileContractAddress != address(0),
            "Profile contract not set"
        );
        address profileOwner = IContentBaseProfileV1(_profileContractAddress)
            .profileOwner(profileId);
        require(msg.sender == profileOwner, "Forbidden");
    }

    modifier onlyProfileOwner(uint256 profileId) {
        _onlyProfileOwner(profileId);
        _;
    }

    /**
     *  ***** ADMIN RELATED FUNCTIONS *****
     */

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function updateProfileContract(address contractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        _profileContractAddress = contractAddress;
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function updatePublishContract(address contractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        _publishContractAddress = contractAddress;
    }

    /**
     *  ***** PUBLIC FUNCTIONS *****
     */

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function commentOnPublish(
        DataTypes.CreateCommentOnPublishData calldata createCommentOnPublishData
    )
        external
        override
        onlyReady
        onlyProfileOwner(createCommentOnPublishData.creatorId)
    {
        uint256 publishId = createCommentOnPublishData.publishId;
        uint256 creatorId = createCommentOnPublishData.creatorId;

        // The parent publish to be commented on must exist.
        require(
            IContentBasePublishV1(_publishContractAddress).publishExist(
                publishId
            ),
            "Publish not found"
        );

        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint a Comment NFT to the caller.
        _safeMint(msg.sender, tokenId);

        // Create and store a new comment struct in the mapping.
        _tokenIdToComment[tokenId] = DataTypes.Comment({
            owner: msg.sender,
            creatorId: creatorId,
            parentId: publishId,
            commentType: DataTypes.CommentType.PUBLISH,
            likes: 0,
            disLikes: 0,
            contentURI: createCommentOnPublishData.contentURI
        });

        // Emit comment created event.
        emit CommentCreated(
            tokenId,
            publishId,
            creatorId,
            msg.sender,
            createCommentOnPublishData.contentURI,
            DataTypes.CommentType.PUBLISH,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function commentOnComment(
        DataTypes.CreateCommentOnCommentData calldata createCommentOnCommentData
    )
        external
        override
        onlyReady
        onlyProfileOwner(createCommentOnCommentData.creatorId)
    {
        uint256 commentId = createCommentOnCommentData.commentId;
        uint256 creatorId = createCommentOnCommentData.creatorId;

        // The parent comment to be commented on must exist.
        require(_exists(commentId), "Comment not found");

        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint a Comment NFT to the caller.
        _safeMint(msg.sender, tokenId);

        // Create and store a new comment struct in the mapping.
        _tokenIdToComment[tokenId] = DataTypes.Comment({
            owner: msg.sender,
            creatorId: creatorId,
            parentId: commentId,
            commentType: DataTypes.CommentType.COMMENT,
            likes: 0,
            disLikes: 0,
            contentURI: createCommentOnCommentData.contentURI
        });

        // Emit comment created event.
        emit CommentCreated(
            tokenId,
            commentId,
            creatorId,
            msg.sender,
            createCommentOnCommentData.contentURI,
            DataTypes.CommentType.COMMENT,
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

        emit CommentUpdated(
            updateCommentData.tokenId,
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

        emit CommentDeleted(tokenId, block.timestamp);
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
        // Check if the call is for `like` or `unlike`.
        bool liked = _commentIdToProfileIdToLikeStatus[commentId][profileId];

        if (!liked) {
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
            emit CommentLiked(
                commentId,
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
            emit CommentUnLiked(
                commentId,
                _tokenIdToComment[commentId].likes,
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
        // Check if the call is for `dislike` or `undoDislike`.
        bool disLiked = _commentIdToProfileIdToDislikeStatus[commentId][
            profileId
        ];

        if (!disLiked) {
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
            emit CommentDisLiked(
                commentId,
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
            emit CommentUndoDisLiked(
                commentId,
                _tokenIdToComment[commentId].disLikes,
                block.timestamp
            );
        }
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function getProfileContract() external view override returns (address) {
        return _profileContractAddress;
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function getPublishContract() external view override returns (address) {
        return _publishContractAddress;
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function getCommentById(uint256 tokenId)
        external
        view
        override
        returns (DataTypes.Comment memory)
    {
        return _tokenIdToComment[tokenId];
    }

    /**
     * Override the parent burn function.
     * @dev Force `burn` function to use the `deleteComment` function
     */
    function burn(uint256 tokenId) public view override {
        require(_exists(tokenId), "Comment not found");
        revert("Use `deleteComment` function");
    }

    /**
     * This function will return a token uri depending on the token category.
     * @dev the Publish tokens return metadata uris.
     * @dev the Comment tokens return content uris.
     * @dev The Like tokens return empty string.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "Comment not found");
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
        require(from == address(0) || to == address(0), "Non transferable");
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