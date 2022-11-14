// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";

import {ContentBaseStorageV1} from "./ContentBaseStorageV1.sol";
import {IContentBaseV1} from "./IContentBaseV1.sol";
import {Validations} from "./libraries/Validations.sol";
import {ProfileLogic} from "./libraries/ProfileLogic.sol";
import {FollowLogic} from "./libraries/FollowLogic.sol";
import {PublishLogic} from "./libraries/PublishLogic.sol";
import {CommentLogic} from "./libraries/CommentLogic.sol";
import {LikeLogic} from "./libraries/LikeLogic.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {Helpers} from "./libraries/Helpers.sol";

contract ContentBaseV1 is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ContentBaseStorageV1,
    IContentBaseV1
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * Initialize function.
     */
    function initialize() public initializer {
        __ERC721_init("ContentBase Platform", "CTB");
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
     */
    modifier onlyReady() {
        require(platformOwner != address(0), "Not ready");
        require(likeFee != 0, "Not ready");
        require(platformFee != 0, "Not ready");
        _;
    }

    /**
     * A modifier to check if the caller own the token.
     */
    modifier onlyTokenOwner(uint256 tokenId) {
        require(_exists(tokenId), "Token not found");
        require(ownerOf(tokenId) == msg.sender, "Forbidden");
        _;
    }

    /**
     * A modifier to check of the token is of the given collection.
     */
    modifier onlyCollection(uint256 tokenId, uint256 collection) {
        require(_exists(tokenId), "Token not found");
        require(
            _tokenIdToCollection[tokenId] == collection,
            "Wrong collection"
        );
        _;
    }

    /**
     *  ***** ADMIN RELATED FUNCTIONS *****
     */

    /**
     * @inheritdoc IContentBaseV1
     */
    function updateLikeFee(uint256 fee) external override onlyRole(ADMIN_ROLE) {
        likeFee = fee;
    }

    /**
     * @inheritdoc IContentBaseV1
     */
    function updatePlatformFee(uint24 fee)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        platformFee = fee;
    }

    /**
     * @inheritdoc IContentBaseV1
     */
    function withdraw() external override onlyReady onlyRole(ADMIN_ROLE) {
        payable(platformOwner).transfer(address(this).balance);
    }

    /**
     *  ***** PROFILE RELATED FUNCTIONS *****
     */

    /**
     * @inheritdoc IContentBaseV1
     */
    function createProfile(string calldata handle, string calldata imageURI)
        external
        override
        onlyReady
    {
        // Handle validation logic.
        bool valid = Validations._createProfileValidation(
            handle,
            imageURI,
            _handleHashToProfileId
        );

        require(valid, "Invalid input");

        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint an NFT to the caller.
        _safeMint(msg.sender, tokenId);

        // Set the created NFT to the PROFILE collection.
        _tokenIdToCollection[tokenId] = PROFILE;

        // Handle create profile logic.
        ProfileLogic._createProfile(
            tokenId,
            handle,
            imageURI,
            _tokenIdToProfile,
            _handleHashToProfileId,
            _ownerToDefaultProfileId
        );
    }

    /**
     * @inheritdoc IContentBaseV1
     */
    function updateProfileImage(uint256 tokenId, string calldata newImageURI)
        external
        override
        onlyReady
        onlyCollection(tokenId, PROFILE)
        onlyTokenOwner(tokenId)
    {
        address profileOwner = ownerOf(tokenId);

        // Hanlde validation logic.
        bool valid = Validations._updateProfileImageValidation(
            tokenId,
            newImageURI,
            _tokenIdToProfile
        );

        require(valid, "Invalid input");

        // Handle update profile image logic.
        ProfileLogic._updateProfileImage(
            tokenId,
            newImageURI,
            profileOwner,
            _tokenIdToProfile
        );
    }

    /**
     * @inheritdoc IContentBaseV1
     */
    function setDefaultProfile(string calldata handle) external override {
        // Get a profile id by the given handle.
        uint256 profileId = _handleHashToProfileId[Helpers.hashHandle(handle)];
        require(profileId != 0, "Profile not found");

        // The caller must own the token.
        require(ownerOf(profileId) == msg.sender, "Forbidden");

        // Recheck the category of the found token id.
        require(_tokenIdToCollection[profileId] == PROFILE, "Wrong token type");

        // The found token must not already the default.
        require(
            _ownerToDefaultProfileId[msg.sender] != profileId,
            "Already the default"
        );

        // Handle set default profile logic.
        ProfileLogic._setDefaultProfile(profileId, _ownerToDefaultProfileId);
    }

    /**
     * @inheritdoc IContentBaseV1
     */
    function validateHandle(string calldata handle)
        external
        view
        override
        returns (bool)
    {
        return
            Helpers.handleUnique(handle, _handleHashToProfileId) &&
            Helpers.validateHandle(handle);
    }

    /**
     * @inheritdoc IContentBaseV1
     */
    function getDefaultProfile()
        external
        view
        override
        returns (uint256, string memory)
    {
        require(
            _ownerToDefaultProfileId[msg.sender] != 0,
            "Default profile not set"
        );
        uint256 profileId = _ownerToDefaultProfileId[msg.sender];

        // Reconfirm that the found token id is a profile token.
        require(
            _tokenIdToCollection[profileId] == PROFILE,
            "Default profile not set"
        );

        return (profileId, _tokenIdToProfile[profileId].handle);
    }

    /**
     *  ***** FOLLOW RELATED FUNCTIONS *****
     */

    /**
     * @inheritdoc IContentBaseV1
     * @dev Use this function for both `follow` and `unfollow`.
     * @dev A Follow NFT will be minted to the caller in the case of `follow`, the existing Follow NFT will be burned in the case of `unfollow`.
     */
    function follow(uint256 followerId, uint256 followeeId)
        external
        override
        onlyReady
        onlyTokenOwner(followerId) // The caller must own the follower profile token.
        onlyCollection(followerId, PROFILE) // The follower id must be a profile token.
        onlyCollection(followeeId, PROFILE) // The followee id must be a profile token.
    {
        // A profile cannot follow itself.
        require(followerId != followeeId, "Not allow");

        // Check to identify if the call is for `follow` or `unfollow`.
        if (_profileIdToFolloweeIdToTokenId[followerId][followeeId] == 0) {
            // FOLLOW --> mint a new Follow NFT to the caller.

            // Increment the counter before using it so the id will start from 1 (instead of 0).
            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();

            // Mint a follow NFT to the caller (the owner (EOA) of the follower profile).
            _safeMint(msg.sender, tokenId);

            // Set the token to FOLLOW collection.
            _tokenIdToCollection[tokenId] = FOLLOW;

            // Handle `follow` logic.
            FollowLogic._follow(
                tokenId,
                followerId,
                followeeId,
                _tokenIdToProfile,
                _profileIdToFolloweeIdToTokenId,
                _profileIdToFollowerIdToTokenId
            );
        } else {
            // UNFOLLOW CASE --> burn the Follow token.

            uint256 followTokenId = _profileIdToFolloweeIdToTokenId[followerId][
                followeeId
            ];

            // Check if the found token is a Follow token.
            require(
                _tokenIdToCollection[followTokenId] == FOLLOW,
                "Wrong token type"
            );

            // Check token ownership.
            require(ownerOf(followTokenId) == msg.sender, "Forbidden");

            // Burn the token.
            burn(followTokenId);

            // Remove the token from the token to collection mapping.
            delete _tokenIdToCollection[followTokenId];

            // Handle `unfollow` logic.
            FollowLogic._follow(
                followTokenId,
                followerId,
                followeeId,
                _tokenIdToProfile,
                _profileIdToFolloweeIdToTokenId,
                _profileIdToFollowerIdToTokenId
            );
        }
    }

    /**
     *  ***** PUBLISH RELATED FUNCTIONS *****
     */

    /**
     * @inheritdoc IContentBaseV1
     */
    function createPublish(
        DataTypes.CreatePublishData calldata createPublishData
    )
        external
        override
        onlyReady
        onlyTokenOwner(createPublishData.creatorId)
        onlyCollection(createPublishData.creatorId, PROFILE)
    {
        // Hanlde validation logic.
        bool valid = Validations._createPublishValidation(createPublishData);

        require(valid, "Invalid input");

        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint a Publish NFT to the caller.
        _safeMint(msg.sender, tokenId);

        // Set the new token to PUBLISH collection.
        _tokenIdToCollection[tokenId] = PUBLISH;

        // Handle create publish logic.
        PublishLogic._createPublish(
            tokenId,
            createPublishData,
            _tokenIdToPublish
        );
    }

    /**
     * @inheritdoc IContentBaseV1
     * @dev If the value of any key in the struct isn't changed, the existing value must be provided.
     */
    function updatePublish(
        DataTypes.UpdatePublishData calldata updatePublishData
    )
        external
        override
        onlyReady
        onlyTokenOwner(updatePublishData.creatorId)
        onlyCollection(updatePublishData.creatorId, PROFILE)
        onlyTokenOwner(updatePublishData.tokenId)
        onlyCollection(updatePublishData.tokenId, PUBLISH)
    {
        uint256 tokenId = updatePublishData.tokenId;

        // The publish must belong to the creator.
        require(
            _tokenIdToPublish[tokenId].creatorId == updatePublishData.creatorId,
            "Not allow"
        );

        // Hanlde validation logic.
        bool valid = Validations._updatePublishValidation(updatePublishData);

        require(valid, "Invalid input");

        // Handle update publish logic.
        PublishLogic._updatePublish(updatePublishData, _tokenIdToPublish);
    }

    /**
     * @inheritdoc IContentBaseV1
     */
    function deletePublish(uint256 tokenId, uint256 creatorId)
        external
        override
        onlyReady
        onlyTokenOwner(creatorId)
        onlyCollection(creatorId, PROFILE)
        onlyTokenOwner(tokenId)
        onlyCollection(tokenId, PUBLISH)
    {
        // The publish must belong to the creator.
        require(_tokenIdToPublish[tokenId].creatorId == creatorId, "Not allow");

        // Call the parent burn function.
        burn(tokenId);

        // Remove the token from the collection mapping.
        delete _tokenIdToCollection[tokenId];

        // Handle delete publish logic.
        PublishLogic._deletePublish(tokenId, creatorId, _tokenIdToPublish);
    }

    /**
     *  ***** COMMENT RELATED FUNCTIONS *****
     */

    /**
     * @inheritdoc IContentBaseV1
     */
    function createComment(
        DataTypes.CreateCommentData calldata createCommentData
    )
        external
        override
        onlyReady
        onlyTokenOwner(createCommentData.creatorId)
        onlyCollection(createCommentData.creatorId, PROFILE)
    {
        uint256 targetId = createCommentData.targetId;

        // The target token must exist.
        require(_exists(targetId), "Token not found");

        // The target token must be of category PUBLISH or COMMENT.
        require(
            _tokenIdToCollection[targetId] == PUBLISH ||
                _tokenIdToCollection[targetId] == COMMENT,
            "Wrong token type"
        );

        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint a Comment NFT to the caller.
        _safeMint(msg.sender, tokenId);

        // Set the token to COMMENT collection.
        _tokenIdToCollection[tokenId] = COMMENT;

        // Handle create comment logic.
        CommentLogic._createComment(
            tokenId,
            createCommentData,
            _tokenIdToComment
        );
    }

    /**
     * @inheritdoc IContentBaseV1
     */
    function updateComment(
        DataTypes.UpdateCommentData calldata updateCommentData
    )
        external
        override
        onlyReady
        onlyTokenOwner(updateCommentData.creatorId)
        onlyCollection(updateCommentData.creatorId, PROFILE)
        onlyTokenOwner(updateCommentData.tokenId)
        onlyCollection(updateCommentData.tokenId, COMMENT)
    {
        // Handle update comment logic.
        CommentLogic._updateComment(updateCommentData, _tokenIdToComment);
    }

    /**
     * @inheritdoc IContentBaseV1
     */
    function deleteComment(uint256 tokenId, uint256 creatorId)
        external
        override
        onlyReady
        onlyTokenOwner(tokenId)
        onlyCollection(tokenId, COMMENT)
        onlyTokenOwner(creatorId)
        onlyCollection(creatorId, PROFILE)
    {
        // The given profile id must be the creator of the comment.
        require(_tokenIdToComment[tokenId].creatorId == creatorId, "Not allow");

        // Call the parent burn function.
        burn(tokenId);

        // Remove the token from the collection mapping.
        delete _tokenIdToCollection[tokenId];

        // Handle delete comment logic.
        CommentLogic._deleteComment(tokenId, creatorId, _tokenIdToComment);
    }

    /**
     *  ***** LIKE RELATED FUNCTIONS *****
     */

    /**
     * @inheritdoc IContentBaseV1
     * @dev Use this function for both `like` and `unlike`
     */
    function likePublish(uint256 publishId, uint256 profileId)
        external
        payable
        override
        onlyReady
        onlyTokenOwner(profileId)
        onlyCollection(profileId, PROFILE)
        onlyCollection(publishId, PUBLISH)
    {
        // Find the like id (if exist).
        uint256 likeId = _publishIdToProfileIdToLikeId[publishId][profileId];

        // Check if the call is for `like` or `unlike`.
        if (likeId == 0) {
            // A. `like` - Mint a LIKE token to the caller.

            // Validate ether sent.
            require(msg.value == likeFee, "Bad input");

            // Get the Publish's owner address.
            address publishOwner = ownerOf(publishId);

            // Transfer the like fee (after deducting operational fee for the platform) to the publish owner.
            uint256 netFee = msg.value - ((msg.value * platformFee) / 100);
            payable(publishOwner).transfer(netFee);

            // Increment the counter before using it so the id will start from 1 (instead of 0).
            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();

            // Mint a Like NFT to the caller.
            _safeMint(msg.sender, tokenId);

            // Set the token to LIKE collection.
            _tokenIdToCollection[tokenId] = LIKE;

            // Update the profile's Like NFT count.
            _profileIdToLikeNFTCount[profileId]++;

            // Handle like publish logic.
            LikeLogic.LikePublishData memory vars = LikeLogic.LikePublishData({
                tokenId: tokenId,
                publishId: publishId,
                publishOwner: publishOwner,
                profileId: profileId,
                netFee: netFee
            });
            LikeLogic._likePublish(
                vars,
                _tokenIdToPublish,
                _profileIdToLikeNFTCount,
                _publishIdToProfileIdToLikeId,
                _publishIdToProfileIdToDislikeStatus
            );
        } else {
            // B `unlike` - NOT to burn the Like token, just update related states.

            // The caller must own the Like token.
            require(ownerOf(likeId) == msg.sender);

            // Handle unlike publish logic.
            LikeLogic._unLikePublish(
                publishId,
                profileId,
                _tokenIdToPublish,
                _profileIdToLikeNFTCount,
                _publishIdToProfileIdToLikeId
            );
        }
    }

    /**
     * @inheritdoc IContentBaseV1
     * @dev Use this function for both `dislike` and `undoDislike`.
     * @dev NO Like NFT involve for this function.
     */
    function disLikePublish(uint256 publishId, uint256 profileId)
        external
        override
        onlyReady
        onlyTokenOwner(profileId)
        onlyCollection(profileId, PROFILE)
        onlyCollection(publishId, PUBLISH)
    {
        // Identify if the call is for `dislike` or `undo dislike`.
        bool isDisLiked = _publishIdToProfileIdToDislikeStatus[publishId][
            profileId
        ];

        if (!isDisLiked) {
            // DISLIKE

            // Handle dislike publish logic.
            LikeLogic._disLikePublish(
                publishId,
                profileId,
                _tokenIdToPublish,
                _publishIdToProfileIdToLikeId,
                _publishIdToProfileIdToDislikeStatus
            );
        } else {
            // UNDO DISLIKE

            // Handle undo dislike publish logic.
            LikeLogic._undoDisLikePublish(
                publishId,
                profileId,
                _tokenIdToPublish,
                _publishIdToProfileIdToDislikeStatus
            );
        }
    }

    /**
     * @inheritdoc IContentBaseV1
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
     * @inheritdoc IContentBaseV1
     * @dev Use this function for both `like` and `unlike`.
     * @dev No Like NFT involve for this function.
     */
    function likeComment(uint256 commentId, uint256 profileId)
        external
        override
        onlyReady
        onlyTokenOwner(profileId)
        onlyCollection(profileId, PROFILE)
        onlyCollection(commentId, COMMENT)
    {
        // Check if the call is for `like` or `unlike`.
        bool isLiked = _commentIdToProfileIdToLikeStatus[commentId][profileId];

        if (!isLiked) {
            // LIKE

            // Handle like comment logic.
            LikeLogic.LikeCommentData memory vars = LikeLogic.LikeCommentData({
                commentId: commentId,
                profileId: profileId,
                commentOwner: ownerOf(commentId)
            });
            LikeLogic._likeComment(
                vars,
                _tokenIdToComment,
                _commentIdToProfileIdToLikeStatus,
                _commentIdToProfileIdToDislikeStatus
            );
        } else {
            // UNLIKE

            // Handle unlike comment logic.
            LikeLogic._unLikeComment(
                commentId,
                profileId,
                _tokenIdToComment,
                _commentIdToProfileIdToLikeStatus
            );
        }
    }

    /**
     * @inheritdoc IContentBaseV1
     * @dev Use this function for both `dislike` and `undoDislike`.
     * @dev No Like NFT involve for this function.
     */
    function disLikeComment(uint256 commentId, uint256 profileId)
        external
        override
        onlyReady
        onlyTokenOwner(profileId)
        onlyCollection(profileId, PROFILE)
        onlyCollection(commentId, COMMENT)
    {
        // Check if the call is for `dislike` or `undoDislike`.
        bool isDisLiked = _commentIdToProfileIdToDislikeStatus[commentId][
            profileId
        ];

        if (!isDisLiked) {
            // DISLIKE

            // Handle dislike comment logic.
            LikeLogic._disLikeComment(
                commentId,
                profileId,
                _tokenIdToComment,
                _commentIdToProfileIdToLikeStatus,
                _commentIdToProfileIdToDislikeStatus
            );
        } else {
            // UNDO DISLIKE

            // Handle undo-dislike comment logic.
            LikeLogic._undoDislikeComment(
                commentId,
                profileId,
                _tokenIdToComment,
                _commentIdToProfileIdToDislikeStatus
            );
        }
    }

    /**
     * This function will return token uri depending on the token category.
     * @dev the Profile tokens return image uri.
     * @dev The Follow and Like tokens return empty string.
     * @dev the Publish tokens return metadata uris.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        if (_tokenIdToCollection[tokenId] == PROFILE)
            return _tokenIdToProfile[tokenId].imageURI;
        if (_tokenIdToCollection[tokenId] == PUBLISH)
            return _tokenIdToPublish[tokenId].metadataURI;
        if (_tokenIdToCollection[tokenId] == COMMENT)
            return _tokenIdToComment[tokenId].contentURI;
        else return "";
    }

    /**
     * Profile and Like NFTs are not allowed to be burned.
     * @param tokenId {uint256}
     */
    function burn(uint256 tokenId) public override {
        require(
            _tokenIdToCollection[tokenId] != PROFILE &&
                _tokenIdToCollection[tokenId] != LIKE,
            "Profile NFT and Like NFT cannot be burned"
        );

        super.burn(tokenId);
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
