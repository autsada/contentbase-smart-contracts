// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";

import "../IProfileFactory.sol";
import "./IPublish.sol";
import "../like/ILike.sol";
import "../comment/IComment.sol";
import {Helpers} from "../../libraries/Helpers.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

/**
 * @title ContentBase Publish
 * @notice Some data required to create a Publish NFT will not be stored on-chain, it will be used as an event arguments so the client listening to the event can update their UI/database accordingly.
 * @notice This contract will need to communicate to ContentBase Like Contract for like operation, and ContentBase Comment for commenting operation. It will also need to communicate to the Profile Factory Contract to validate the callers to ensure they are ContentBase Profiles.
 * @dev metadataURI must resolve to the metadata json object file of the publish, the json object must have required fields as specified in Metadata Guild at Publish struct in DataTypes.sol.
 */

contract ContentBasePublish is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IContentBasePublish
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    // Contract owner address.
    address public platform;
    // Profile factory address for use to validate profiles.
    address public factoryContract;
    // Like contract for use to create comments.
    address public likeContract;
    // Comment contract for use to create comments.
    address public commentContract;

    // The amount that a profile will send to the owner of the publish they like.
    uint256 public likeFee;
    // The percentage to be deducted from the like fee (as the platform commission) before transfering the like fee to the publish's owner, need to store it as a whole number and do division when using it.
    uint24 public platformFee;
    // Mapping of publish struct by token id.
    mapping(uint256 => DataTypes.Publish) private _tokenById;
    // Mapping of (publishId => profileId) to track if a specific profile disliked the publish.
    mapping(uint256 => address) private _publishToDislikedProfile;

    // Publish Events.
    event PublishCreated(
        uint256 indexed tokenId,
        address indexed creatorId,
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
        address creatorId,
        address owner,
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
    event PublishDeleted(
        uint256 indexed tokenId,
        address indexed owner,
        address profileAddress,
        uint256 timestamp
    );

    // Like Events.
    event PublishLiked(
        uint256 indexed likeId,
        uint256 indexed publishId,
        address indexed publishOwner,
        address profileAddress,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 fee,
        uint256 timestamp
    );
    event PublishUnLiked(
        uint256 indexed likeId,
        uint256 publishId,
        address profileAddress,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );

    // DisLike Events.
    event PublishDisLiked(
        uint256 indexed publishId,
        address indexed profileAddress,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );
    event PublishUndoDisLiked(
        uint256 indexed publishId,
        address indexed profileAddress,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );

    /**
     * @dev the `commentId` if not 0, it means the newly created comment was made on that commentId (this is the case where profile comments on other comments).
     */
    event CommentCreated(
        uint256 indexed tokenId,
        uint256 indexed publishId,
        address indexed profileAddress,
        address owner,
        string text,
        string contentURI,
        uint256 commentId,
        uint256 timestamp
    );
    event CommentUpdated(
        uint256 indexed tokenId,
        uint256 indexed publishId,
        address indexed profileAddress,
        address owner,
        string text,
        string contentURI,
        uint256 timestamp
    );
    event CommentDeleted(
        uint256 indexed tokenId,
        uint256 publishId,
        uint256 timestamp
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("ContentBase Publish Module", "CPM");
        __ERC721Burnable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(UPGRADER_ROLE, ADMIN_ROLE);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        platform = msg.sender;
        likeFee = 1000 ether;
        platformFee = 50;
    }

    /**
     * The modifer to check the publish contract is properly initialized.
     */
    modifier onlyReady() {
        require(platform != address(0), "Not ready");
        require(factoryContract != address(0), "Not ready");
        require(likeContract != address(0), "Not ready");
        require(commentContract != address(0), "Not ready");
        require(likeFee != 0, "Not ready");
        require(platformFee != 0, "Not ready");

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
     * @inheritdoc IContentBasePublish
     */
    function updateContractOwner(address owner)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        platform = owner;
    }

    /**
     * @inheritdoc IContentBasePublish
     */
    function updateFactoryContract(address factoryAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        factoryContract = factoryAddress;
    }

    /**
     * @inheritdoc IContentBasePublish
     */
    function updateLikeContract(address contractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        likeContract = contractAddress;
    }

    /**
     * @inheritdoc IContentBasePublish
     */
    function updateCommentContract(address contractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        commentContract = contractAddress;
    }

    /**
     * @inheritdoc IContentBasePublish
     */
    function withdraw() external override onlyRole(ADMIN_ROLE) {
        // Make sure the owner address is set.
        require(platform != address(0), "Owner not set");

        payable(platform).transfer(address(this).balance);
    }

    /**
     * @inheritdoc IContentBasePublish
     */
    function updateLikeFee(uint256 fee) external override onlyRole(ADMIN_ROLE) {
        likeFee = fee;
    }

    /**
     * @inheritdoc IContentBasePublish
     */
    function updatePlatformFee(uint24 fee)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        platformFee = fee;
    }

    /**
     * @inheritdoc IContentBasePublish
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
        if (
            createPublishData.secondaryCategory == DataTypes.Category.Empty &&
            createPublishData.tertiaryCategory != DataTypes.Category.Empty
        ) revert("Invalid category");

        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint an NFT to the caller.
        _safeMint(msg.sender, tokenId);

        // Update the publish struct mapping.
        _tokenById[tokenId] = DataTypes.Publish({
            owner: msg.sender,
            creatorId: createPublishData.creatorId,
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
    ) private {
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
     * @inheritdoc IContentBasePublish
     */
    /**
     * @dev If the value of any key in the struct isn't changed, the existing value must be provided.
     */
    function updatePublish(
        DataTypes.UpdatePublishData calldata updatePublishData
    )
        external
        override
        onlyReady
        onlyProfileOwner(updatePublishData.creatorId)
    {
        uint256 tokenId = updatePublishData.tokenId;

        // The token id must exist.
        require(_exists(tokenId), "Publish not found");

        // The caller must own the token.
        require(ownerOf(tokenId) == msg.sender, "Forbidden");

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
        if (
            updatePublishData.secondaryCategory == DataTypes.Category.Empty &&
            updatePublishData.tertiaryCategory != DataTypes.Category.Empty
        ) revert("Invalid category");

        // Only update imageURI if it's changed.
        if (
            keccak256(abi.encodePacked(_tokenById[tokenId].imageURI)) !=
            keccak256(abi.encodePacked(updatePublishData.imageURI))
        ) {
            _tokenById[tokenId].imageURI = updatePublishData.imageURI;
        }

        // Only update contentURI if it's changed.
        if (
            keccak256(abi.encodePacked(_tokenById[tokenId].contentURI)) !=
            keccak256(abi.encodePacked(updatePublishData.contentURI))
        ) {
            _tokenById[tokenId].contentURI = updatePublishData.contentURI;
        }

        // Only update metadataURI if it's changed.
        if (
            keccak256(abi.encodePacked(_tokenById[tokenId].metadataURI)) !=
            keccak256(abi.encodePacked(updatePublishData.metadataURI))
        ) {
            _tokenById[tokenId].metadataURI = updatePublishData.metadataURI;
        }

        // Emit publish updated event
        _emitPublishUpdated(msg.sender, updatePublishData);
    }

    /**
     * A helper function to emit a update publish event that accepts a update publish data struct in memory to avoid a stack too deep error.
     * @param owner {address}
     * @param updatePublishData {struct}
     */
    function _emitPublishUpdated(
        address owner,
        DataTypes.UpdatePublishData memory updatePublishData
    ) private {
        emit PublishUpdated(
            updatePublishData.tokenId,
            updatePublishData.creatorId,
            owner,
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
     * @inheritdoc IContentBasePublish
     */
    function like(DataTypes.LikeData calldata likeData)
        external
        payable
        override
        onlyReady
        onlyProfileOwner(likeData.profileAddress)
    {
        uint256 publishId = likeData.publishId;
        address profileAddress = likeData.profileAddress;

        // The publish must exist.
        require(_exists(publishId), "Publish not found");

        // Validate ether sent.
        require(msg.value == likeFee, "Bad input");

        // Call `like` function in the Like contract.
        (
            bool success,
            uint256 likeId,
            DataTypes.LikeActionType actionType
        ) = IContentBaseLike(likeContract).like(msg.sender, likeData);
        require(success, "Like failed");

        // Get the Publish's owner address.
        address publishOwner = ownerOf(publishId);

        // Handle the logic depending on the actype type.
        if (actionType == DataTypes.LikeActionType.LIKE) {
            // LIKE --> transfer like fee to the publish owner.

            // Transfer like support fee (after deducting operational fee for the platform) to the publish owner.
            uint256 netFee = msg.value - ((msg.value * platformFee) / 100);
            payable(publishOwner).transfer(netFee);

            // Increase the publish struct likes.
            _tokenById[publishId].likes++;

            // Emit like event.
            emit PublishLiked(
                likeId,
                publishId,
                publishOwner,
                profileAddress,
                msg.sender,
                _tokenById[publishId].likes,
                _tokenById[publishId].disLikes,
                netFee,
                block.timestamp
            );
        } else {
            // UNLIKE

            // Decrease the publish struct likes.
            _tokenById[publishId].likes--;

            // emit unlike even.
            emit PublishUnLiked(
                likeId,
                publishId,
                profileAddress,
                msg.sender,
                _tokenById[publishId].likes,
                _tokenById[publishId].disLikes,
                block.timestamp
            );
        }
    }

    /**
     * @inheritdoc IContentBasePublish
     * @dev No NFT minted for this functionality.
     * @dev use this function for both `dislike` and `undo dislike`
     */
    function disLike(DataTypes.LikeData calldata likeData)
        external
        override
        onlyReady
        onlyProfileOwner(likeData.profileAddress)
    {
        uint256 publishId = likeData.publishId;
        address profileAddress = likeData.profileAddress;

        // The publish must exist.
        require(_exists(publishId), "Publish not found");

        // Identify if the call is for `dislike` or `undo dislike`.
        address disLikedAddr = _publishToDislikedProfile[publishId];

        // Handle the logic depending on the actype type.
        if (disLikedAddr == address(0)) {
            // DISLIKE --> need to call the Like contract to update like state.

            (bool success, bool isLiked) = IContentBaseLike(likeContract)
                .handleDislikePublish(profileAddress, publishId);

            require(success, "Dislike failed");

            // Increase the publish struct likes.
            _tokenById[publishId].disLikes++;

            // If the profile has liked the publish before, we need to reduce the publish's likes count as well.
            if (isLiked) {
                _tokenById[publishId].likes--;
            }

            // Emit like event.
            emit PublishDisLiked(
                publishId,
                profileAddress,
                msg.sender,
                _tokenById[publishId].likes,
                _tokenById[publishId].disLikes,
                block.timestamp
            );
        } else {
            // UNDO DISLIKE --> NO need to call the Like contract.

            // Make sure the profile has disliked the publish before.
            require(
                _publishToDislikedProfile[publishId] != address(0),
                "Undo failed"
            );

            // Decrease dislikes count.
            _tokenById[publishId].disLikes--;

            // emit unlike even.
            emit PublishUndoDisLiked(
                publishId,
                profileAddress,
                msg.sender,
                _tokenById[publishId].likes,
                _tokenById[publishId].disLikes,
                block.timestamp
            );
        }
    }

    /**
     * @inheritdoc IContentBasePublish
     */
    function comment(DataTypes.CreateCommentData calldata createCommentData)
        external
        override
        onlyReady
        onlyProfileOwner(createCommentData.profileAddress)
    {
        uint256 publishId = createCommentData.publishId;

        // The publish must exist.
        require(_exists(publishId), "Publish not found");

        // Call the comment contract to create a Comment NFT.
        (bool success, uint256 commentId) = IContentBaseComment(commentContract)
            .createComment(msg.sender, createCommentData);

        require(success, "Create comment failed");

        // Emit comment created event.
        emit CommentCreated(
            commentId,
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
     * @inheritdoc IContentBasePublish
     */
    /**
     * @dev For the field that has no change, existing data must be provided
     */
    function updateComment(
        DataTypes.UpdateCommentData calldata updateCommentData
    )
        external
        override
        onlyReady
        onlyProfileOwner(updateCommentData.profileAddress)
    {
        // uint256 commentId = updateCommentData.tokenId;
        uint256 publishId = updateCommentData.publishId;
        address profileAddress = updateCommentData.profileAddress;

        // The publish must exist.
        require(_exists(publishId), "Publish not found");

        // Call the comment contract to update a comment.
        bool success = IContentBaseComment(commentContract).updateComment(
            msg.sender,
            updateCommentData
        );

        require(success, "Update comment failed");

        emit CommentUpdated(
            updateCommentData.tokenId,
            publishId,
            profileAddress,
            msg.sender,
            updateCommentData.text,
            updateCommentData.contentURI,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBasePublish
     */
    function deleteComment(
        uint256 tokenId,
        uint256 publishId,
        address profileAddress
    )
        external
        override
        onlyReady
        onlyProfileOwner(profileAddress)
        returns (bool)
    {
        // The given publish id must exist.
        require(_exists(publishId), "Publish not found");

        // Call the comment contract to delete the comment.
        bool success = IContentBaseComment(commentContract).burn(
            tokenId,
            publishId,
            msg.sender,
            profileAddress
        );

        require(success, "Delete comment failed");

        return true;
    }

    /**
     * @inheritdoc IContentBasePublish
     */
    function getPublishById(uint256 tokenId)
        external
        view
        override
        returns (DataTypes.Publish memory)
    {
        // Publish must exist
        require(_exists(tokenId), "Not found");

        return _tokenById[tokenId];
    }

    /**
     * A public function to burn a token.
     * @dev use this fuction to delete a publish.
     * @param tokenId {uint256} - a publish token id
     * @param creatorId {address} - the profile address that created the publish
     */
    function burn(uint256 tokenId, address creatorId)
        public
        onlyReady
        onlyProfileOwner(creatorId)
    {
        // Publish must exist.
        require(_exists(tokenId), "Publish not found");

        // The caller must be the owner of the publish.
        require(msg.sender == ownerOf(tokenId), "Forbidden");

        // The publish must belong to the creator.
        require(_tokenById[tokenId].creatorId == creatorId, "Not allow");

        // Remove the publish from the struct mapping.
        delete _tokenById[tokenId];

        // Call the parent burn function.
        super.burn(tokenId);

        emit PublishDeleted(tokenId, msg.sender, creatorId, block.timestamp);
    }

    /**
     * A function to get a publish's metadata uri.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable)
        returns (string memory)
    {
        // Token must exist.
        require(_exists(tokenId), "Publish not found");

        return _tokenById[tokenId].metadataURI;
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
