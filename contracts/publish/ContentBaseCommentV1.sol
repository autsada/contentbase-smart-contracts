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
        string text,
        DataTypes.CommentType commentType,
        uint256 timestamp
    );
    event CommentUpdated(
        uint256 indexed tokenId,
        uint256 indexed creatorId,
        address owner,
        string contentURI,
        string text,
        uint256 timestamp
    );
    event CommentDeleted(
        uint256 indexed tokenId,
        uint256 indexed creatorId,
        address owner,
        uint256 timestamp
    );
    event CommentLiked(
        uint256 indexed commentId,
        uint256 indexed profileId,
        uint256 timestamp
    );
    event CommentUnLiked(
        uint256 indexed commentId,
        uint256 indexed profileId,
        uint256 timestamp
    );
    event CommentDisLiked(
        uint256 indexed commentId,
        uint256 indexed profileId,
        uint256 timestamp
    );
    event CommentUndoDisLiked(
        uint256 indexed commentId,
        uint256 indexed profileId,
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
     * A modifier to check if the comment exists.
     */
    function _onlyCommentExists(uint256 commentId) private view {
        require(_exists(commentId), "Comment not found");
    }

    modifier onlyCommentExists(uint256 commentId) {
        _onlyCommentExists(commentId);
        _;
    }

    /**
     *  ***** ADMIN RELATED FUNCTIONS *****
     */

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function updateProfileContract(
        address contractAddress
    ) external override onlyRole(ADMIN_ROLE) {
        _profileContractAddress = contractAddress;
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function updatePublishContract(
        address contractAddress
    ) external override onlyRole(ADMIN_ROLE) {
        _publishContractAddress = contractAddress;
    }

    /**
     *  ***** PUBLIC FUNCTIONS *****
     */

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function commentOnPublish(
        DataTypes.CreateCommentData calldata createCommentData
    )
        external
        override
        onlyReady
        onlyProfileOwner(createCommentData.creatorId)
    {
        uint256 publishId = createCommentData.parentId;
        uint256 creatorId = createCommentData.creatorId;

        // The parent publish to be commented on must exist.
        require(
            IContentBasePublishV1(_publishContractAddress).publishExist(
                publishId
            ),
            "Publish not found"
        );

        // Validate contentURI.
        Helpers.notTooShortURI(createCommentData.contentURI);
        Helpers.notTooLongURI(createCommentData.contentURI);

        // `text` must be provided.
        require(bytes(createCommentData.text).length > 0, "Invalid input");

        // Validate text.
        if (bytes(createCommentData.text).length > 0) {
            Helpers.notTooLongComment(createCommentData.text);
        }

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
            contentURI: createCommentData.contentURI
        });

        // Emit comment created event.
        emit CommentCreated(
            tokenId,
            publishId,
            creatorId,
            msg.sender,
            createCommentData.contentURI,
            createCommentData.text,
            DataTypes.CommentType.PUBLISH,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function commentOnComment(
        DataTypes.CreateCommentData calldata createCommentData
    )
        external
        override
        onlyReady
        onlyProfileOwner(createCommentData.creatorId)
        onlyCommentExists(createCommentData.parentId)
    {
        uint256 commentId = createCommentData.parentId;
        uint256 creatorId = createCommentData.creatorId;

        // Validate contentURI.
        Helpers.notTooShortURI(createCommentData.contentURI);
        Helpers.notTooLongURI(createCommentData.contentURI);

        // `text` must be provided.
        require(bytes(createCommentData.text).length > 0, "Invalid input");

        // Validate text.
        if (bytes(createCommentData.text).length > 0) {
            Helpers.notTooLongComment(createCommentData.text);
        }

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
            contentURI: createCommentData.contentURI
        });

        // Emit comment created event.
        emit CommentCreated(
            tokenId,
            commentId,
            creatorId,
            msg.sender,
            createCommentData.contentURI,
            createCommentData.text,
            DataTypes.CommentType.COMMENT,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     * @dev If the value of any key in the struct isn't changed, the existing value must be provided.
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

        // Validate contentURI.
        Helpers.notTooShortURI(updateCommentData.contentURI);
        Helpers.notTooLongURI(updateCommentData.contentURI);

        // `text` must be provided.
        require(bytes(updateCommentData.text).length > 0, "Invalid input");

        // Validate text.
        if (bytes(updateCommentData.text).length > 0) {
            Helpers.notTooLongComment(updateCommentData.text);
        }

        // Only update the contentURI if it changed.
        if (
            keccak256(abi.encodePacked(updateCommentData.contentURI)) !=
            keccak256(abi.encodePacked(_tokenIdToComment[tokenId].contentURI))
        ) {
            // Update the comment struct.
            _tokenIdToComment[tokenId].contentURI = updateCommentData
                .contentURI;
        }

        emit CommentUpdated(
            updateCommentData.tokenId,
            updateCommentData.creatorId,
            msg.sender,
            updateCommentData.contentURI,
            updateCommentData.text,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function deleteComment(
        uint256 tokenId,
        uint256 creatorId
    )
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

        emit CommentDeleted(tokenId, creatorId, msg.sender, block.timestamp);
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function likeComment(
        uint256 commentId,
        uint256 profileId
    )
        external
        override
        onlyReady
        onlyProfileOwner(profileId)
        onlyCommentExists(commentId)
    {
        // Check if the call is for `like` or `unlike`.
        bool liked = _commentIdToProfileIdToLikeStatus[commentId][profileId];

        if (!liked) {
            // LIKE

            // Update the comment to profile to like status mapping.
            _commentIdToProfileIdToLikeStatus[commentId][profileId] = true;

            // If the profile `dislike` the comment before, update the dislike states.
            if (_commentIdToProfileIdToDislikeStatus[commentId][profileId]) {
                _commentIdToProfileIdToDislikeStatus[commentId][
                    profileId
                ] = false;
            }

            // Emit comment liked event.
            emit CommentLiked(commentId, profileId, block.timestamp);
        } else {
            // UNLIKE

            // Update the comment to profile to like mapping.
            _commentIdToProfileIdToLikeStatus[commentId][profileId] = false;

            // Emit comment unliked event.
            emit CommentUnLiked(commentId, profileId, block.timestamp);
        }
    }

    /**
     * @inheritdoc IContentBaseCommentV1
     */
    function disLikeComment(
        uint256 commentId,
        uint256 profileId
    )
        external
        override
        onlyReady
        onlyProfileOwner(profileId)
        onlyCommentExists(commentId)
    {
        // Check if the call is for `dislike` or `undoDislike`.
        bool disLiked = _commentIdToProfileIdToDislikeStatus[commentId][
            profileId
        ];

        if (!disLiked) {
            // DISLIKE

            // Update the comment to profile to dislike status mapping.
            _commentIdToProfileIdToDislikeStatus[commentId][profileId] = true;

            // If the profile `like` the comment before, update the like states.
            if (_commentIdToProfileIdToLikeStatus[commentId][profileId]) {
                _commentIdToProfileIdToLikeStatus[commentId][profileId] = false;
            }

            // Emit comment disliked event.
            emit CommentDisLiked(commentId, profileId, block.timestamp);
        } else {
            // UNDO DISLIKE

            // Update the comment to profile to dislike status mapping.
            _commentIdToProfileIdToDislikeStatus[commentId][profileId] = false;

            // Emit comment disliked event.
            emit CommentUndoDisLiked(commentId, profileId, block.timestamp);
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
    function getCommentById(
        uint256 tokenId
    ) external view override returns (DataTypes.Comment memory) {
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
     * Return the comment's content uri
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
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

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    // The following functions are overrides required by Solidity.

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
