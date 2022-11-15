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
import {Events} from "../libraries/Events.sol";

/**
 * @title ContentBasePublishV1
 * @author Autsada
 *
 * @notice This contract contains 2 ERC721 NFT collections - `PUBLISH` and `LIKE`.
 * @notice Publish NFTs are burnable, Like NFTs are non-burnable.
 * @notice Both publish NFTs and like NFTs can only be minted by addresses (EOA) that own profile NFTs.
 * @notice To mint a like NFT, the caller must send a long some ethers that equals to the specified `like fee` with the request, the platform fee will be applied to the like fee and the net total will be transfered to an owner of the liked publish.
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
        emit Events.PublishCreated(
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
    ) internal {
        emit Events.PublishUpdated(
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

        emit Events.PublishDeleted(
            tokenId,
            creatorId,
            msg.sender,
            block.timestamp
        );
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
                    publishOwner: ownerOf(publishId),
                    owner: msg.sender,
                    likes: _tokenIdToPublish[publishId].likes,
                    disLikes: _tokenIdToPublish[publishId].disLikes,
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
            emit Events.PublishUnLiked(
                publishId,
                profileId,
                msg.sender,
                _tokenIdToPublish[publishId].likes,
                _tokenIdToPublish[publishId].disLikes,
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
        emit Events.PublishLiked(
            vars.tokenId,
            vars.publishId,
            vars.profileId,
            vars.publishOwner,
            vars.owner,
            vars.likes,
            vars.disLikes,
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
            emit Events.PublishDisLiked(
                publishId,
                profileId,
                msg.sender,
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
            emit Events.PublishUndoDisLiked(
                publishId,
                profileId,
                msg.sender,
                _tokenIdToPublish[publishId].likes,
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
        returns (DataTypes.Publish memory)
    {
        return _tokenIdToPublish[tokenId];
    }

    /**
     * @inheritdoc IContentBasePublishV1
     */
    function publishExists(uint256 publishId)
        external
        view
        override
        returns (bool)
    {
        return _exists(publishId);
    }

    /**
     * Override the parent burn function.
     * @dev Force `burn` function to use `deletePublish` function so we can update the related states.
     */
    function burn(uint256 tokenId) public view override {
        if (_tokenIdToCollection[tokenId] == LIKE) {
            revert("Forbidden");
        } else {
            revert("Use `deletePublish` function instead");
        }
    }

    /**
     * This function will return a token uri depending on the token category.
     * @dev the Publish tokens return metadata uris.
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
