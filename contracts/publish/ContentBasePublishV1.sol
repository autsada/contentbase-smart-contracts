// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";

import {IContentBasePublishV1} from "./IContentBasePublishV1.sol";
import {IContentBaseProfileV1} from "../profile/IContentBaseProfileV1.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Helpers} from "../libraries/Helpers.sol";

/**
 * @title ContentBasePublishV1
 * @author Autsada
 *
 * @notice This contract contains 3 ERC721 NFT collections - `PUBLISH`, `LIKE`, and `COMMENT`.
 * @notice Publish and Comments NFTs are burnable, Like NFTs are non-burnable.
 * @notice These 3 collections can only be minted by addresses (EOA) that own profile NFTs.
 * @notice To mint a like NFT, the caller must send a long some ethers that equals to the specified `like fee` with the request, the platform fee will be applied to the like fee and the net total will be transfered to an owner of the liked publish.
 * @notice No Like NFTs involve when minting Comment NFTs.
 */

contract ContentBasePublishV1 is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IContentBasePublishV1
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ContentBase owner address.
    address public platformOwner;
    // Profile contract address.
    address public profileContract;
    // The amount that a profile will send to the owner of the publish they like.
    uint256 public likeFee;
    // The percentage to be deducted from the like fee (as the platform commission) before transfering the like fee to the publish's owner, need to store it as a whole number and do division when using it.
    uint256 public platformFee;

    // Token Collections.
    uint256 public constant PUBLISH = 1;
    uint256 public constant LIKE = 2;
    uint256 public constant COMMENT = 3;

    // Mappping to track token id to token collection.
    mapping(uint256 => uint256) private _tokenIdToCollection;

    // Mapping (tokenId => publish struct).
    mapping(uint256 => DataTypes.Publish) private _tokenIdToPublish;
    // Mapping of (publishId => (profileId => likeId)) to track if a specific profile id liked a publish, for example (1 => (2 => 3)) means publish token id 1 has been liked by profile token id 2, and like token id 3 has been minted to the profile id 2.
    mapping(uint256 => mapping(uint256 => uint256))
        private _publishIdToProfileIdToLikeId;
    // Mapping of (publishId => (profileId => bool)) to track if a specific profile disliked a publish, for example (1 => (2 => true)) means publish token id 1 has been dis-liked by profile token id 2.
    mapping(uint256 => mapping(uint256 => bool))
        private _publishIdToProfileIdToDislikeStatus;
    // Mapping to track how many Like NFT a profile has.
    mapping(uint256 => uint256) internal _profileIdToLikeNFTCount;
    // Mapping (tokenId => publish struct).
    mapping(uint256 => DataTypes.Comment) private _tokenIdToComment;
    // Mapping of (commentId => (profileId => bool)) to track if a specific profile liked a comment.
    mapping(uint256 => mapping(uint256 => bool))
        internal _commentIdToProfileIdToLikeStatus;
    // Mapping of (commentId => (profileId => bool)) to track if a specific profile disliked the comment.
    mapping(uint256 => mapping(uint256 => bool))
        internal _commentIdToProfileIdToDislikeStatus;

    // Publish Events.
    event PublishCreated(
        uint256 indexed tokenId,
        uint256 indexed creatorId,
        address indexed owner,
        string imageURI,
        string contentURI,
        string metadataURI,
        string title,
        string description,
        DataTypes.Category primaryCategory,
        DataTypes.Category secondaryCategory,
        DataTypes.Category tertiaryCategory,
        uint256 timestamp
    );
    event PublishUpdated(
        uint256 indexed tokenId,
        string imageURI,
        string contentURI,
        string metadataURI,
        string title,
        string description,
        DataTypes.Category primaryCategory,
        DataTypes.Category secondaryCategory,
        DataTypes.Category tertiaryCategory,
        uint256 timestamp
    );
    event PublishDeleted(uint256 indexed tokenId, uint256 timestamp);

    // Comment Events.
    event CommentCreated(
        uint256 indexed tokenId,
        uint256 indexed targetId,
        uint256 indexed creatorId,
        address owner,
        string contentURI,
        uint256 timestamp
    );
    event CommentUpdated(
        uint256 indexed tokenId,
        string contentURI,
        uint256 timestamp
    );
    event CommentDeleted(uint256 indexed tokenId, uint256 timestamp);

    // Like Events (Publish).
    event PublishLiked(
        uint256 indexed tokenId,
        uint256 indexed publishId,
        uint256 indexed profileId,
        address profileOwner,
        uint256 fee,
        uint256 timestamp
    );
    event PublishUnLiked(
        uint256 indexed publishId,
        uint32 likes,
        uint256 timestamp
    );

    event PublishDisLiked(
        uint256 indexed publishId,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );
    event PublishUndoDisLiked(
        uint256 indexed publishId,
        uint32 disLikes,
        uint256 timestamp
    );

    // Like Events (Comment).
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
    function initialize() public initializer {
        __ERC721_init("ContentBase Publish Module", "CPM");
        __ERC721Burnable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        platformOwner = msg.sender;
        likeFee = 1000 ether;
        platformFee = 50;
    }

    /**
     * A modifier to check if the contract is ready for use.
     * @dev Extract code inside the modifier to a private function to reduce contract size.
     */
    function _onlyReady() private view {
        require(platformOwner != address(0), "Not ready");
        require(profileContract != address(0), "Not ready");
        require(likeFee != 0, "Not ready");
        require(platformFee != 0, "Not ready");
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
     * A modifier to check of the token is of the given collection.
     * @dev Extract code inside the modifier to a private function to reduce contract size.
     */
    function _onlyCollection(uint256 tokenId, uint256 collection) private view {
        require(_exists(tokenId), "Token not found");
        require(
            _tokenIdToCollection[tokenId] == collection,
            "Wrong collection"
        );
    }

    modifier onlyCollection(uint256 tokenId, uint256 collection) {
        _onlyCollection(tokenId, collection);
        _;
    }

    /**
     *  ***** ADMIN RELATED FUNCTIONS *****
     */

    /**
     * @inheritdoc IContentBasePublishV1
     */
    function updatePlatformOwner(address ownerAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        platformOwner = ownerAddress;
    }

    /**
     * @inheritdoc IContentBasePublishV1
     */
    function updateProfileContract(address contractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        profileContract = contractAddress;
    }

    /**
     * @inheritdoc IContentBasePublishV1
     */
    function updateLikeFee(uint256 fee) external override onlyRole(ADMIN_ROLE) {
        likeFee = fee;
    }

    /**
     * @inheritdoc IContentBasePublishV1
     */
    function updatePlatformFee(uint256 fee)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        platformFee = fee;
    }

    /**
     * @inheritdoc IContentBasePublishV1
     */
    function withdraw() external override onlyReady onlyRole(ADMIN_ROLE) {
        payable(platformOwner).transfer(address(this).balance);
    }

    /**
     * @inheritdoc IContentBasePublishV1
     */
    function createPublish(
        DataTypes.CreatePublishData calldata createPublishData
    )
        external
        override
        onlyReady
        onlyProfileOwner(createPublishData.creatorId)
    {
        // Validate imageURI.
        require(Helpers.notTooShortURI(createPublishData.imageURI));
        require(Helpers.notTooLongURI(createPublishData.imageURI));

        // Validate contentURI.
        require(Helpers.notTooShortURI(createPublishData.contentURI));
        require(Helpers.notTooLongURI(createPublishData.contentURI));

        // Validate metadataURI.
        require(Helpers.notTooShortURI(createPublishData.metadataURI));
        require(Helpers.notTooLongURI(createPublishData.metadataURI));

        // Validate title.
        require(Helpers.notTooShortTitle(createPublishData.title));
        require(Helpers.notTooLongTitle(createPublishData.title));

        // Validate description.
        // Description can be empty so no need to validate min length.
        require(Helpers.notTooLongDescription(createPublishData.description));

        // Validate categories.
        require(
            Helpers.validPrimaryCategory(createPublishData.primaryCategory)
        );
        require(Helpers.validCategory(createPublishData.secondaryCategory));
        require(Helpers.validCategory(createPublishData.tertiaryCategory));

        // If the secondary category is Empty, the tertiary category must also Empty.
        if (createPublishData.secondaryCategory == DataTypes.Category.Empty) {
            require(
                createPublishData.tertiaryCategory == DataTypes.Category.Empty,
                "Invalid category"
            );
        }

        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint a Publish NFT to the caller.
        _safeMint(msg.sender, tokenId);

        // Set the new token to PUBLISH collection.
        _tokenIdToCollection[tokenId] = PUBLISH;

        // Update the publish struct mapping.
        _tokenIdToPublish[tokenId] = DataTypes.Publish({
            owner: msg.sender,
            creatorId: createPublishData.creatorId,
            revenue: 0,
            likes: 0,
            disLikes: 0,
            imageURI: createPublishData.imageURI,
            contentURI: createPublishData.contentURI,
            metadataURI: createPublishData.metadataURI
        });

        // Emit publish created event.
        _emitPublishCreated(tokenId, msg.sender, createPublishData);
    }

    /**
     * A helper function to emit a create publish event that accepts a create publish data struct in memory to avoid a stack too deep error.
     * @param tokenId {uint256}
     * @param owner {address}
     * @param createPublishData {struct}
     */
    function _emitPublishCreated(
        uint256 tokenId,
        address owner,
        DataTypes.CreatePublishData memory createPublishData
    ) internal {
        emit PublishCreated(
            tokenId,
            createPublishData.creatorId,
            owner,
            createPublishData.imageURI,
            createPublishData.contentURI,
            createPublishData.metadataURI,
            createPublishData.title,
            createPublishData.description,
            createPublishData.primaryCategory,
            createPublishData.secondaryCategory,
            createPublishData.tertiaryCategory,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBasePublishV1
     * @dev If the value of any key in the struct isn't changed, the existing value must be provided.
     */
    function updatePublish(
        DataTypes.UpdatePublishData calldata updatePublishData
    )
        external
        override
        onlyReady
        onlyProfileOwner(updatePublishData.creatorId)
        onlyTokenOwner(updatePublishData.tokenId)
        onlyCollection(updatePublishData.tokenId, PUBLISH)
    {
        uint256 tokenId = updatePublishData.tokenId;

        // The publish must belong to the creator.
        require(
            _tokenIdToPublish[tokenId].creatorId == updatePublishData.creatorId,
            "Not allow"
        );

        // Validate imageURI
        require(Helpers.notTooShortURI(updatePublishData.imageURI));
        require(Helpers.notTooLongURI(updatePublishData.imageURI));

        // Validate contentURI.
        require(Helpers.notTooShortURI(updatePublishData.contentURI));
        require(Helpers.notTooLongURI(updatePublishData.contentURI));

        // Validate metadataURI.
        require(Helpers.notTooShortURI(updatePublishData.metadataURI));
        require(Helpers.notTooLongURI(updatePublishData.metadataURI));

        // Validate title.
        require(Helpers.notTooShortTitle(updatePublishData.title));
        require(Helpers.notTooLongTitle(updatePublishData.title));

        // Validate description.
        require(Helpers.notTooLongDescription(updatePublishData.description));

        // Validate categories.
        require(
            Helpers.validPrimaryCategory(updatePublishData.primaryCategory)
        );
        require(Helpers.validCategory(updatePublishData.secondaryCategory));
        require(Helpers.validCategory(updatePublishData.tertiaryCategory));

        // If the secondary category is Empty, the tertiary category must also Empty.
        if (updatePublishData.secondaryCategory == DataTypes.Category.Empty) {
            require(
                updatePublishData.tertiaryCategory == DataTypes.Category.Empty,
                "Invalid category"
            );
        }

        // Only update imageURI if it's changed.
        if (
            keccak256(abi.encodePacked(_tokenIdToPublish[tokenId].imageURI)) !=
            keccak256(abi.encodePacked(updatePublishData.imageURI))
        ) {
            _tokenIdToPublish[tokenId].imageURI = updatePublishData.imageURI;
        }

        // Only update contentURI if it's changed.
        if (
            keccak256(
                abi.encodePacked(_tokenIdToPublish[tokenId].contentURI)
            ) != keccak256(abi.encodePacked(updatePublishData.contentURI))
        ) {
            _tokenIdToPublish[tokenId].contentURI = updatePublishData
                .contentURI;
        }

        // Only update metadataURI if it's changed.
        if (
            keccak256(
                abi.encodePacked(_tokenIdToPublish[tokenId].metadataURI)
            ) != keccak256(abi.encodePacked(updatePublishData.metadataURI))
        ) {
            _tokenIdToPublish[tokenId].metadataURI = updatePublishData
                .metadataURI;
        }

        // Emit publish updated event
        _emitPublishUpdated(updatePublishData);
    }

    /**
     * A helper function to emit a update publish event that accepts a update publish data struct in memory to avoid a stack too deep error.
     * @param updatePublishData {struct}
     */
    function _emitPublishUpdated(
        DataTypes.UpdatePublishData memory updatePublishData
    ) internal {
        emit PublishUpdated(
            updatePublishData.tokenId,
            updatePublishData.imageURI,
            updatePublishData.contentURI,
            updatePublishData.metadataURI,
            updatePublishData.title,
            updatePublishData.description,
            updatePublishData.primaryCategory,
            updatePublishData.secondaryCategory,
            updatePublishData.tertiaryCategory,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBasePublishV1
     */
    function deletePublish(uint256 tokenId, uint256 creatorId)
        external
        override
        onlyReady
        onlyProfileOwner(creatorId)
        onlyTokenOwner(tokenId)
        onlyCollection(tokenId, PUBLISH)
    {
        // The publish must belong to the creator.
        require(_tokenIdToPublish[tokenId].creatorId == creatorId, "Not allow");

        // Call the parent burn function.
        super.burn(tokenId);

        // Update the token to collection mapping.
        delete _tokenIdToCollection[tokenId];

        // Remove the publish from the struct mapping.
        delete _tokenIdToPublish[tokenId];

        emit PublishDeleted(tokenId, block.timestamp);
    }

    /**
     * @inheritdoc IContentBasePublishV1
     */
    function likePublish(uint256 publishId, uint256 profileId)
        external
        payable
        override
        onlyReady
        onlyProfileOwner(profileId)
        onlyCollection(publishId, PUBLISH)
    {
        // Find the like id (if exist).
        uint256 likeId = _publishIdToProfileIdToLikeId[publishId][profileId];

        // Check if the call is for `like` or `unlike`.
        if (likeId == 0) {
            // A. `like` - Mint a LIKE token to the caller.

            // Validate ether sent.
            require(msg.value == likeFee, "Bad input");

            // Transfer the like fee (after deducting operational fee for the platform) to the publish owner.
            uint256 netFee = msg.value - ((msg.value * platformFee) / 100);
            payable(ownerOf(publishId)).transfer(netFee);

            // Increment the counter before using it so the id will start from 1 (instead of 0).
            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();

            // Mint a Like NFT to the caller.
            _safeMint(msg.sender, tokenId);

            // Set the token to LIKE collection.
            _tokenIdToCollection[tokenId] = LIKE;

            // Update the profile's Like NFT count.
            _profileIdToLikeNFTCount[profileId]++;

            // Update the publish's revenue.
            _tokenIdToPublish[publishId].revenue += netFee;

            // Increase `likes` count of the publish struct.
            _tokenIdToPublish[publishId].likes++;

            // Update publish to profile to like mapping.
            _publishIdToProfileIdToLikeId[publishId][profileId] = tokenId;

            // If the profile disliked the publish before, we need to update all related states.
            if (_publishIdToProfileIdToDislikeStatus[publishId][profileId]) {
                _publishIdToProfileIdToDislikeStatus[publishId][
                    profileId
                ] = false;

                if (_tokenIdToPublish[publishId].disLikes > 0) {
                    _tokenIdToPublish[publishId].disLikes--;
                }
            }

            // Emit publish liked event.
            _emitPublishLiked(
                DataTypes.PublishLikedEventArgs({
                    tokenId: tokenId,
                    publishId: publishId,
                    profileId: profileId,
                    owner: msg.sender,
                    netFee: netFee
                })
            );
        } else {
            // B `unlike` - NOT to burn the Like token, just update the related states.

            // The caller must own the Like token.
            require(ownerOf(likeId) == msg.sender);

            // Decrease `likes` count of the publish struct.
            // Make sure the count is greater than 0.
            if (_tokenIdToPublish[publishId].likes > 0) {
                _tokenIdToPublish[publishId].likes--;
            }

            // Remove the like id from the publish to profile to like mapping, this will make this profile can like the given publish id again.
            _publishIdToProfileIdToLikeId[publishId][profileId] = 0;

            // Emit publish unliked event.
            emit PublishUnLiked(
                publishId,
                _tokenIdToPublish[publishId].likes,
                block.timestamp
            );
        }
    }

    /**
     * A helper function to emit a publish liked event that accepts args as a struct in memory to avoid a stack too deep error.
     * @param vars - see DataTypes.PublishLikedEventArgs
     */
    function _emitPublishLiked(DataTypes.PublishLikedEventArgs memory vars)
        internal
    {
        emit PublishLiked(
            vars.tokenId,
            vars.publishId,
            vars.profileId,
            vars.owner,
            vars.netFee,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBasePublishV1
     * @dev NO Like NFT involve for this function.
     */
    function disLikePublish(uint256 publishId, uint256 profileId)
        external
        override
        onlyReady
        onlyProfileOwner(profileId)
        onlyCollection(publishId, PUBLISH)
    {
        // Identify if the call is for `dislike` or `undo dislike`.
        bool isDisLiked = _publishIdToProfileIdToDislikeStatus[publishId][
            profileId
        ];

        if (!isDisLiked) {
            // DISLIKE

            // Update the disliked mapping.
            _publishIdToProfileIdToDislikeStatus[publishId][profileId] = true;

            // Increase the publish struct disLikes.
            _tokenIdToPublish[publishId].disLikes++;

            // If the profile liked the publish before, we need to update the liked mapping and decrease the publish's likes count as well.
            if (_publishIdToProfileIdToLikeId[publishId][profileId] != 0) {
                _publishIdToProfileIdToLikeId[publishId][profileId] = 0;

                if (_tokenIdToPublish[publishId].likes > 0) {
                    _tokenIdToPublish[publishId].likes--;
                }
            }

            // Emit publihs dislike event.
            emit PublishDisLiked(
                publishId,
                _tokenIdToPublish[publishId].likes,
                _tokenIdToPublish[publishId].disLikes,
                block.timestamp
            );
        } else {
            // UNDO DISLIKE

            // Update the disliked mapping.
            _publishIdToProfileIdToDislikeStatus[publishId][profileId] = false;

            // Decrease dislikes count.
            // Make sure the count is greater than 0.
            if (_tokenIdToPublish[publishId].disLikes > 0) {
                _tokenIdToPublish[publishId].disLikes--;
            }

            // Emit publihs undo-dislike event.
            emit PublishUndoDisLiked(
                publishId,
                _tokenIdToPublish[publishId].disLikes,
                block.timestamp
            );
        }
    }

    /**
     * @inheritdoc IContentBasePublishV1
     */
    function getPublishById(uint256 tokenId)
        external
        view
        override
        onlyCollection(tokenId, PUBLISH)
        returns (DataTypes.Publish memory)
    {
        return _tokenIdToPublish[tokenId];
    }

    /**
     * @inheritdoc IContentBasePublishV1
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

        // Target token must exist.
        require(_exists(targetId), "Token not found");

        // Target token must be a Publish or a Comment.
        require(
            _tokenIdToCollection[targetId] == PUBLISH ||
                _tokenIdToCollection[targetId] == COMMENT,
            "Wrong collection"
        );

        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint a Comment NFT to the caller.
        _safeMint(msg.sender, tokenId);

        // Set the new token to COMMENT collection.
        _tokenIdToCollection[tokenId] = COMMENT;

        // Create and store a new comment struct in the mapping.
        _tokenIdToComment[tokenId] = DataTypes.Comment({
            owner: msg.sender,
            creatorId: createCommentData.creatorId,
            targetId: createCommentData.targetId,
            likes: 0,
            disLikes: 0,
            contentURI: createCommentData.contentURI
        });

        // Emit comment created event.
        emit CommentCreated(
            tokenId,
            createCommentData.targetId,
            createCommentData.creatorId,
            msg.sender,
            createCommentData.contentURI,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBasePublishV1
     */
    function updateComment(
        DataTypes.UpdateCommentData calldata updateCommentData
    )
        external
        override
        onlyReady
        onlyProfileOwner(updateCommentData.creatorId)
        onlyTokenOwner(updateCommentData.tokenId)
        onlyCollection(updateCommentData.tokenId, COMMENT)
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
     * @inheritdoc IContentBasePublishV1
     */
    function deleteComment(uint256 tokenId, uint256 creatorId)
        external
        override
        onlyReady
        onlyTokenOwner(tokenId)
        onlyProfileOwner(creatorId)
        onlyCollection(tokenId, COMMENT)
    {
        // The given profile id must be the creator of the comment.
        require(_tokenIdToComment[tokenId].creatorId == creatorId, "Not allow");

        // Call the parent burn function.
        super.burn(tokenId);

        // Update the token to collection struct.
        delete _tokenIdToCollection[tokenId];

        // Remove the struct from the mapping.
        delete _tokenIdToComment[tokenId];

        emit CommentDeleted(tokenId, block.timestamp);
    }

    /**
     * @inheritdoc IContentBasePublishV1
     */
    function likeComment(uint256 commentId, uint256 profileId)
        external
        override
        onlyReady
        onlyProfileOwner(profileId)
        onlyCollection(commentId, COMMENT)
    {
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
     * @inheritdoc IContentBasePublishV1
     */
    function disLikeComment(uint256 commentId, uint256 profileId)
        external
        override
        onlyReady
        onlyProfileOwner(profileId)
        onlyCollection(commentId, COMMENT)
    {
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
     * @inheritdoc IContentBasePublishV1
     */
    function getCommentById(uint256 tokenId)
        external
        view
        override
        onlyCollection(tokenId, COMMENT)
        returns (DataTypes.Comment memory)
    {
        return _tokenIdToComment[tokenId];
    }

    /**
     * Override the parent burn function.
     * @dev Force `burn` function to use `deletePublish` function so we can update the related states.
     */
    function burn(uint256 tokenId) public view override {
        if (_tokenIdToCollection[tokenId] == LIKE) {
            revert("Forbidden");
        } else {
            revert("Use `deletePublish` or `deleteComment`");
        }
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
        if (_tokenIdToCollection[tokenId] == PUBLISH)
            return _tokenIdToPublish[tokenId].metadataURI;
        if (_tokenIdToCollection[tokenId] == COMMENT)
            return _tokenIdToComment[tokenId].contentURI;
        else return "";
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
