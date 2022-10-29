// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";
import "./IPublishNFT.sol";
import "./ICommentNFT.sol";
import "./ILikeNFT.sol";
import "../profile/IProfileNFT.sol";
import {Constants} from "../../libraries/Constants.sol";
import {Helpers} from "../../libraries/Helpers.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

/**
 * @title PublishNFT
 * @notice some data required to create a Publish NFT will not be stored on-chain, it will be used as an event arguments so the client listening to the event can update their UI/database accordingly.
 * @dev metadataURI must resolve to the metadata json object file of the publish, the json object must have required fields as specified in Metadata Guild at Publish struct in DataTypes.sol.
 */

contract PublishNFT is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IPublishNFT
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    // Profile contract for use to validate profile.
    address public profileAddress;
    // Like contract for use to create likes.
    address public likeAddress;
    // Comment contract for use to create comments.
    address public commentAddress;

    // Contract owner address.
    address private _owner;
    // The amount that a profile will send to the owner of the publish they like.
    uint public likeFee;
    // The percentage to be deducted from the like fee (as the platform commission) before transfering the like fee to the publish's owner, need to store it as a whole number and do division when using it.
    uint public platformFee;
    // Mapping of publish struct by token id.
    mapping(uint256 => DataTypes.Publish) private _tokenById;

    // Events
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
        DataTypes.Category tertiaryCategory
    );
    event PublishUpdated(
        uint256 tokenId,
        uint256 creatorId,
        address owner,
        string imageURI,
        string contentURI,
        string metadataURI,
        string title,
        string description,
        DataTypes.Category primaryCategory,
        DataTypes.Category secondaryCategory,
        DataTypes.Category tertiaryCategory
    );
    event PublishDeleted(uint256 indexed tokenId, address indexed owner);
    event Like(
        uint256 indexed likeId,
        uint256 indexed publishId,
        address indexed publishOwner,
        uint256 profileId,
        address profileOwner,
        uint fee
    );
    event UnLike(uint256 indexed likeId, uint256 publishId, uint256 profileId);
    event CommentCreated(
        uint256 indexed tokenId,
        uint256 indexed publishId,
        address indexed owner,
        uint256 profileId,
        string text,
        string contentURI
    );
    event CommentUpdated(
        uint256 indexed tokenId,
        uint256 indexed publishId,
        address indexed owner,
        uint256 profileId,
        string text,
        string contentURI
    );
    event CommentDeleted(uint256 tokenId, uint256 publishId);

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

        likeFee = 1000 ether;
        platformFee = 50;
        _owner = msg.sender;
    }

    /**
     * @dev see IPublishNFT - setProfileContractAddress
     */
    function setProfileContractAddress(address profileContractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        profileAddress = profileContractAddress;
    }

    /**
     * @dev see IPublishNFT - setLikeContractAddress
     */
    function setLikeContractAddress(address likeContractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        likeAddress = likeContractAddress;
    }

    /**
     * @dev see IPublishNFT - setCommentContractAddress
     */
    function setCommentContractAddress(address commentContractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        commentAddress = commentContractAddress;
    }

    /**
     * @dev see IPublishNFT - setContractOwner
     */
    function setContractOwner(address owner)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        _owner = owner;
    }

    /**
     * @dev see IPublishNFT - getContractOwner
     */
    function getContractOwner() external view returns (address) {
        return _owner;
    }

    /**
     * @dev see IPublishNFT - withdraw
     */
    function withdraw() external override onlyRole(ADMIN_ROLE) {
        // Make sure the owner address is set.
        require(_owner != address(0), "Owner not set");

        payable(_owner).transfer(address(this).balance);
    }

    /**
     * @dev see IPublishNFT - setLikeFee
     */
    function setLikeFee(uint fee) external override onlyRole(ADMIN_ROLE) {
        likeFee = fee;
    }

    /**
     * @dev see IPublishNFT - setOperationalFee
     */
    function setPlatformFee(uint fee) external override onlyRole(ADMIN_ROLE) {
        platformFee = fee;
    }

    /**
     * @dev see IPublishNFT - createPublish
     */
    function createPublish(
        DataTypes.CreatePublishData calldata createPublishData
    ) external override returns (uint256) {
        // Profile contract address must be set.
        require(profileAddress != address(0), "Not ready");

        // Caller must own the creator id.
        require(
            msg.sender ==
                IProfileNFT(profileAddress).ownerOfProfile(
                    createPublishData.creatorId
                ),
            "Forbidden"
        );

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
            imageURI: createPublishData.imageURI,
            contentURI: createPublishData.contentURI,
            metadataURI: createPublishData.metadataURI
        });

        // Emit publish created event.
        _emitPublishCreated(tokenId, msg.sender, createPublishData);

        return tokenId;
    }

    // A helper function to emit a create publish event that accepts a create publish data struct in memory to avoid a stack too deep error.
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
            createPublishData.tertiaryCategory
        );
    }

    /**
     * @dev see IPublishNFT - updatePublish
     * @dev If none of imageURI, contentURI, or metadataURI is changed the function will revert although title, description, or thoes 3 categories might be changed, this is to prevent callers from paying gas if the data that stored on-chain (imageURI, contentURI, metadatURI) isn't changed.
     * @dev If the value of any key in the struct isn't changed, the existing value must be provided.
     */
    function updatePublish(
        DataTypes.UpdatePublishData calldata updatePublishData
    ) external override returns (uint256) {
        // Profile contract address must be set.
        require(profileAddress != address(0), "Not ready");

        uint256 tokenId = updatePublishData.tokenId;

        // The token id must exist.
        require(_exists(tokenId), "Publish not found");

        // The caller must own the token.
        require(ownerOf(tokenId) == msg.sender, "Forbidden");

        // Caller must own the creator id.
        require(
            msg.sender ==
                IProfileNFT(profileAddress).ownerOfProfile(
                    updatePublishData.creatorId
                ),
            "Forbidden"
        );

        // The publish must belong to the creator.
        require(
            updatePublishData.creatorId == _tokenById[tokenId].creatorId,
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

        return tokenId;
    }

    // A helper function to emit an update publish event that accepts an update publish data struct in memory to avoid a stack too deep error.
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
            updatePublishData.tertiaryCategory
        );
    }

    /**
     * @dev see IPublishNFT - like
     */
    function like(DataTypes.LikeData calldata likeData)
        external
        payable
        override
        returns (bool)
    {
        // Profile contract address must be set.
        require(profileAddress != address(0), "Not ready");

        // Like contract address must be set.
        require(likeAddress != address(0), "Not ready");

        uint256 publishId = likeData.publishId;
        uint256 profileId = likeData.profileId;

        // The caller must own the profile id.
        require(
            msg.sender == IProfileNFT(profileAddress).ownerOfProfile(profileId),
            "Forbidden"
        );

        // The publish must exist.
        require(_exists(publishId), "Publish not found");

        // Validate ether sent.
        require(msg.value == likeFee, "Bad input");

        // Call the like contract to create a like NFT.
        (bool success, uint256 likeId) = ILikeNFT(likeAddress).createLike(
            msg.sender,
            likeData
        );

        require(success, "Like failed");

        // Get the Publish's owner address.
        address publishOwner = ownerOf(publishId);

        // Transfer like support fee (after deducting operational fee for the platform) to the publish owner.
        uint netFee = msg.value - ((msg.value * platformFee) / 100);
        payable(publishOwner).transfer(netFee);

        // Increase the publish struct likes.
        _tokenById[publishId].likes++;

        emit Like(
            likeId,
            publishId,
            publishOwner,
            profileId,
            msg.sender,
            netFee
        );

        return true;
    }

    /**
     * @dev see IPublishNFT - unLike
     */
    function unLike(DataTypes.UnLikeData calldata unLikeData)
        external
        override
        returns (bool)
    {
        // Profile contract address must be set.
        require(profileAddress != address(0), "Not ready");

        // Like contract address must be set.
        require(likeAddress != address(0), "Not ready");

        uint256 likeId = unLikeData.tokenId;
        uint256 publishId = unLikeData.publishId;
        uint256 profileId = unLikeData.profileId;

        // The caller must own the profile id.
        require(
            msg.sender == IProfileNFT(profileAddress).ownerOfProfile(profileId),
            "Forbidden"
        );

        // The publish must exist.
        require(_exists(publishId), "Publish not found");

        // Call the like contract to burn the like token.
        bool success = ILikeNFT(likeAddress).burn(
            likeId,
            msg.sender,
            profileId
        );

        require(success, "UnLike failed");

        // Decrease the publish's likes.
        // Make sure the likes is greater than 0.
        if (_tokenById[publishId].likes > 0) {
            _tokenById[publishId].likes--;
        }

        emit UnLike(likeId, publishId, profileId);

        return true;
    }

    /**
     * @dev see IPublishNFT - comment
     */
    function comment(DataTypes.CreateCommentData calldata createCommentData)
        external
        override
        returns (uint256)
    {
        // Profile contract address must be set.
        require(profileAddress != address(0), "Not ready");

        // Comment contract address must be set.
        require(commentAddress != address(0), "Not ready");

        uint256 publishId = createCommentData.publishId;
        uint256 profileId = createCommentData.profileId;

        // The publish must exist.
        require(_exists(publishId), "Publish not found");

        // Caller must own the profile.
        // This will also validate if the profile exists.
        require(
            msg.sender == IProfileNFT(profileAddress).ownerOfProfile(profileId),
            "Forbidden"
        );

        // Call the comment contract to create a Comment NFT.
        (bool success, uint256 commentId) = ICommentNFT(commentAddress)
            .createComment(msg.sender, createCommentData);

        require(success, "Create comment failed");

        // Emit comment created event.
        emit CommentCreated(
            commentId,
            createCommentData.publishId,
            msg.sender,
            createCommentData.profileId,
            createCommentData.text,
            createCommentData.contentURI
        );

        return commentId;
    }

    /**
     * @dev see IPublishNFT - updateComment
     * If there is no change, existing data must be provided
     */
    function updateComment(
        DataTypes.UpdateCommentData calldata updateCommentData
    ) external override returns (bool) {
        // Profile contract address must be set.
        require(profileAddress != address(0), "Not ready");

        // Comment contract address must be set.
        require(commentAddress != address(0), "Not ready");

        uint256 commentId = updateCommentData.tokenId;
        uint256 publishId = updateCommentData.publishId;
        uint256 profileId = updateCommentData.profileId;

        // The publish must exist.
        require(_exists(publishId), "Publish not found");

        // Caller must own the profile.
        // This will also validate if the profile exists.
        require(
            msg.sender == IProfileNFT(profileAddress).ownerOfProfile(profileId),
            "Forbidden"
        );

        // Call the comment contract to update a comment.
        bool success = ICommentNFT(commentAddress).updateComment(
            msg.sender,
            updateCommentData
        );

        require(success, "Update comment failed");

        emit CommentUpdated(
            commentId,
            publishId,
            msg.sender,
            profileId,
            updateCommentData.text,
            updateCommentData.contentURI
        );

        return true;
    }

    /**
     * @dev see IPublishNFT - deleteComment
     */
    function deleteComment(uint256 tokenId, uint256 profileId)
        external
        override
        returns (bool)
    {
        // Profile contract address must be set.
        require(profileAddress != address(0), "Not ready");

        // Comment contract address must be set.
        require(commentAddress != address(0), "Not ready");

        // Caller must own the profile.
        // This will also validate if the profile exists.
        require(
            msg.sender == IProfileNFT(profileAddress).ownerOfProfile(profileId),
            "Forbidden"
        );

        // Call the comment contract to delete the comment.
        bool success = ICommentNFT(commentAddress).burn(
            tokenId,
            msg.sender,
            profileId
        );

        require(success, "Delete comment failed");

        return true;
    }

    /**
     * @dev see IPublishNFT - getPublishById
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
     * @dev see IPublishNFT - publishesCount
     */
    function publishesCount() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    /**
     * A public function to burn a token.
     * @dev use this fuction to delete a publish.
     * @param tokenId {number} - a publish token id
     * @param creatorId {number} - the creator id of the publish
     * @return success {bool}
     */
    function burn(uint256 tokenId, uint256 creatorId) public returns (bool) {
        // Profile contract address must be set.
        require(profileAddress != address(0), "Not ready");

        // Publish must exist.
        require(_exists(tokenId), "Publish not found");

        // The caller must be the owner of the publish.
        require(msg.sender == ownerOf(tokenId), "Forbidden");

        // The caller must be the owner of the creator.
        require(
            msg.sender == IProfileNFT(profileAddress).ownerOfProfile(creatorId),
            "Forbidden"
        );

        // The publish must belong to the creator.
        require(_tokenById[tokenId].creatorId == creatorId, "Not allow");

        // Remove the publish from the struct mapping.
        delete _tokenById[tokenId];

        // Call the parent burn function.
        super.burn(tokenId);

        emit PublishDeleted(tokenId, msg.sender);

        return true;
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
