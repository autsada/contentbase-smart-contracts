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
 * @author Autsada T
 *
 * @notice A publish NFT will be minted to a profile owner upon the creation (upload) of a publish.
 * @notice The publish NFTs are non-burnable.
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

    // Profile contract address.
    address private _profileContractAddress;
    // Mapping (tokenId => publish struct).
    mapping(uint256 => DataTypes.Publish) private _tokenIdToPublish;

    // Events.
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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * Initialize function.
     */
    function initialize(address profileContractAddress) public initializer {
        __ERC721_init("ContentBase Publish Module", "CPM");
        __ERC721Burnable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        _profileContractAddress = profileContractAddress;
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
     * @inheritdoc IContentBasePublishV1
     */
    function updateProfileContract(
        address contractAddress
    ) external override onlyRole(ADMIN_ROLE) {
        _profileContractAddress = contractAddress;
    }

    /**
     *  ***** PUBLIC FUNCTIONS *****
     */

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

        // Update the publish struct mapping.
        _tokenIdToPublish[tokenId] = DataTypes.Publish({
            owner: msg.sender,
            creatorId: createPublishData.creatorId,
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
    function deletePublish(
        uint256 tokenId,
        uint256 creatorId
    )
        external
        override
        onlyReady
        onlyProfileOwner(creatorId)
        onlyTokenOwner(tokenId)
    {
        // The publish must belong to the creator.
        require(_tokenIdToPublish[tokenId].creatorId == creatorId, "Not allow");

        // Call the parent burn function.
        super.burn(tokenId);

        // Remove the publish from the struct mapping.
        delete _tokenIdToPublish[tokenId];

        emit PublishDeleted(tokenId, block.timestamp);
    }

    /**
     * @inheritdoc IContentBasePublishV1
     */
    function getProfileContract() external view override returns (address) {
        return _profileContractAddress;
    }

    /**
     * @inheritdoc IContentBasePublishV1
     */
    function getPublishById(
        uint256 tokenId
    ) external view override returns (DataTypes.Publish memory) {
        return _tokenIdToPublish[tokenId];
    }

    /**
     * @inheritdoc IContentBasePublishV1
     */
    function publishExist(
        uint256 publishId
    ) external view override returns (bool) {
        return _exists(publishId);
    }

    /**
     * @inheritdoc IContentBasePublishV1
     */
    function publishOwner(
        uint256 publishId
    ) external view override returns (address) {
        require(_exists(publishId), "Publish not found");
        return ownerOf(publishId);
    }

    /**
     * Override the parent burn function.
     * @dev Force `burn` function to use `deletePublish` function so we can update the related states.
     */
    function burn(uint256 tokenId) public view override {
        require(_exists(tokenId), "Publish not found");
        revert("Use `deletePublish`");
    }

    /**
     * Return the publish' metadata uri.
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return _tokenIdToPublish[tokenId].metadataURI;
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
