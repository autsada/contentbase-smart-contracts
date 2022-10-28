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
import "../profile/IProfileNFT.sol";
import "../like/ILikeNFT.sol";
import {Constants} from "../../libraries/Constants.sol";
import {Helpers} from "../../libraries/Helpers.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

/**
 * @title PublishNFT
 * @dev frontend needs to track token ids own by each address so it can query tokens for each address.
 * @dev metadataURI must resolve to the metadata json object file of the publish, the json object must have required fields as specified in Metadata Guild at Publish struct in DataTypes.sol.
 * @dev createPublish / updatePublish require some information that will not be stored on the blockchain, but for event emitting only. This is to inform frontends the information of the publish so they can update their UI / database accordingly.
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

    // Profile contract.
    IProfileNFT private _profileContract;
    // Like contract address.
    address private _likeContractAddress;

    // Mapping of publish struct by token id.
    mapping(uint256 => DataTypes.Publish) private _tokenById;

    // Events
    event PublishCreated(
        DataTypes.Publish token,
        address owner,
        string title,
        string description,
        DataTypes.Category primaryCategory,
        DataTypes.Category secondaryCategory,
        DataTypes.Category tertiaryCategory
    );
    event PublishUpdated(
        DataTypes.Publish token,
        address owner,
        string title,
        string description,
        DataTypes.Category primaryCategory,
        DataTypes.Category secondaryCategory,
        DataTypes.Category tertiaryCategory
    );
    event PublishDeleted(uint256 tokenId, address owner);

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
    }

    /**
     * @dev see IPublishNFT - setProfileContract
     */
    function setProfileContract(address profileContractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        _profileContract = IProfileNFT(profileContractAddress);
    }

    /**
     * @dev see IPublishNFT - setLikeContractAddress
     */
    function setLikeContractAddress(address likeContractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        _likeContractAddress = likeContractAddress;
    }

    /**
     * @dev see IPublishNFT - createPublish
     */
    function createPublish(
        DataTypes.CreatePublishData calldata createPublishData
    ) external override returns (uint256) {
        // Caller must own the creator id.
        require(
            msg.sender ==
                _profileContract.ownerOfProfile(createPublishData.creatorId),
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
        require(Helpers.notTooLongDescription(createPublishData.description));

        // Validate categories.
        require(
            Helpers.validPrimaryCategory(createPublishData.primaryCategory)
        );
        require(Helpers.validCategory(createPublishData.secondaryCategory));
        require(Helpers.validCategory(createPublishData.tertiaryCategory));

        return
            _createPublish({
                owner: msg.sender,
                createPublishData: createPublishData
            });
    }

    /**
     * A private function that contains the logic to create Publish NFT.
     * @dev validations will be done by caller function.
     * @param owner {address} - an address to be set as an owner of the NFT
     * @param createPublishData {struct} - see DataTypes.CreatePublishData struct
     * @return tokenId {uint256}
     *
     */
    function _createPublish(
        address owner,
        DataTypes.CreatePublishData calldata createPublishData
    ) private returns (uint256) {
        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint an NFT to the owner.
        _safeMint(owner, tokenId);

        // Update _tokenById mapping.
        DataTypes.Publish memory newToken = DataTypes.Publish({
            owner: owner,
            tokenId: tokenId,
            creatorId: createPublishData.creatorId,
            likes: 0,
            imageURI: createPublishData.imageURI,
            contentURI: createPublishData.contentURI,
            metadataURI: createPublishData.metadataURI
        });
        _tokenById[tokenId] = newToken;

        // Emit publish created event.
        emit PublishCreated(
            _tokenById[tokenId],
            owner,
            createPublishData.title,
            createPublishData.description,
            createPublishData.primaryCategory,
            createPublishData.secondaryCategory,
            createPublishData.tertiaryCategory
        );

        return tokenId;
    }

    /**
     * @dev see IPublishNFT - updatePublish
     * @dev If none of imageURI, contentURI, or metadataURI is changed the function will revert although title, description, or thoes 3 categories might be changed, this is to prevent callers from paying gas if the data that stored on-chain (imageURI, contentURI, metadatURI) isn't changed.
     * @dev If the value of any key in the struct isn't changed, the existing value must be provided.
     */
    function updatePublish(
        DataTypes.UpdatePublishData calldata updatePublishData
    ) external override returns (uint256) {
        // The token id must exist.
        require(_exists(updatePublishData.tokenId), "Not found");

        // The caller must own the token.
        require(ownerOf(updatePublishData.tokenId) == msg.sender, "Forbidden");

        // Caller must own the creator id.
        require(
            msg.sender ==
                _profileContract.ownerOfProfile(updatePublishData.creatorId),
            "Forbidden"
        );

        // Creator id must own the token.
        require(
            updatePublishData.creatorId ==
                _tokenById[updatePublishData.tokenId].creatorId,
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

        // Revert if on-chain data NOT changed.
        if (
            keccak256(
                abi.encodePacked(_tokenById[updatePublishData.tokenId].imageURI)
            ) ==
            keccak256(abi.encodePacked(updatePublishData.imageURI)) &&
            keccak256(
                abi.encodePacked(
                    _tokenById[updatePublishData.tokenId].contentURI
                )
            ) ==
            keccak256(abi.encodePacked(updatePublishData.contentURI)) &&
            keccak256(
                abi.encodePacked(
                    _tokenById[updatePublishData.tokenId].metadataURI
                )
            ) ==
            keccak256(abi.encodePacked(updatePublishData.metadataURI))
        ) revert("Nothing changed");

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

        return
            _updatePublish({
                owner: msg.sender,
                updatePublishData: updatePublishData
            });
    }

    /**
     * A private function that contains the logic to update Publish token.
     * @dev validations will be done by caller function.
     * @param updatePublishData {struct} - see DataTypes.UpdatePublishData struct
     * @return tokenId {uint256}
     */
    function _updatePublish(
        address owner,
        DataTypes.UpdatePublishData calldata updatePublishData
    ) private returns (uint256) {
        // Only update imageURI if it's changed.
        if (
            keccak256(
                abi.encodePacked(_tokenById[updatePublishData.tokenId].imageURI)
            ) != keccak256(abi.encodePacked(updatePublishData.imageURI))
        ) {
            _tokenById[updatePublishData.tokenId].imageURI = updatePublishData
                .imageURI;
        }

        // Only update contentURI if it's changed.
        if (
            keccak256(
                abi.encodePacked(
                    _tokenById[updatePublishData.tokenId].contentURI
                )
            ) != keccak256(abi.encodePacked(updatePublishData.contentURI))
        ) {
            _tokenById[updatePublishData.tokenId].contentURI = updatePublishData
                .contentURI;
        }

        // Only update metadataURI if it's changed.
        if (
            keccak256(
                abi.encodePacked(
                    _tokenById[updatePublishData.tokenId].metadataURI
                )
            ) != keccak256(abi.encodePacked(updatePublishData.metadataURI))
        ) {
            _tokenById[updatePublishData.tokenId]
                .metadataURI = updatePublishData.metadataURI;
        }

        // Emit publish created event
        emit PublishUpdated(
            _tokenById[updatePublishData.tokenId],
            owner,
            updatePublishData.title,
            updatePublishData.description,
            updatePublishData.primaryCategory,
            updatePublishData.secondaryCategory,
            updatePublishData.tertiaryCategory
        );

        return updatePublishData.tokenId;
    }

    /**
     * @dev see IPublishNFT - like
     */
    function like(uint256 tokenId) external override returns (bool) {
        // Validate the caller, it must be the Like contract.
        require(msg.sender == _likeContractAddress, "Forbidden");

        // Update the publish's likes.
        _tokenById[tokenId].likes++;

        return true;
    }

    /**
     * @dev see IPublishNFT - unLike
     */
    function unLike(uint256 tokenId) external override returns (bool) {
        // Validate the caller, it must be the Like contract.
        require(msg.sender == _likeContractAddress, "Forbidden");

        // Update the publish's likes.
        // Make sure the likes is greater than 0.
        if (_tokenById[tokenId].likes > 0) {
            _tokenById[tokenId].likes--;
        }

        return true;
    }

    /**
     * @dev see IPublishNFT - ownerPublishes
     */
    function ownerPublishes(uint256[] calldata tokenIds)
        external
        view
        override
        returns (DataTypes.Publish[] memory)
    {
        // Validate param
        require(
            tokenIds.length > 0 &&
                tokenIds.length <= Constants.TOKEN_QUERY_LIMIT,
            "Bad input"
        );

        // Get to be created array length first.
        uint256 publishesArrayLen;

        // Loop through the given tokenIds array to check each id if it exists and the caller is the owner.
        for (uint256 i = 0; i < tokenIds.length; ) {
            if (_exists(tokenIds[i]) && ownerOf(tokenIds[i]) == msg.sender) {
                publishesArrayLen++;
            }
            unchecked {
                i++;
            }
        }

        // Revert if no profile found.
        if (publishesArrayLen == 0) revert("Not found");

        // Create a fix size empty array.
        DataTypes.Publish[] memory publishes = new DataTypes.Publish[](
            publishesArrayLen
        );
        // Track the array index
        uint256 index;

        // Loop through the given token ids again to find a token for each id and put it in the array.
        for (uint256 i = 0; i < tokenIds.length; ) {
            if (_exists(tokenIds[i]) && (ownerOf(tokenIds[i]) == msg.sender)) {
                publishes[index] = _tokenById[tokenIds[i]];
                index++;
            }
            unchecked {
                i++;
            }
        }

        return publishes;
    }

    /**
     * @dev see IPublishNFT - getPublishes
     */
    function getPublishes(uint256[] calldata tokenIds)
        external
        view
        override
        returns (DataTypes.Publish[] memory)
    {
        // Validate param
        require(
            tokenIds.length > 0 &&
                tokenIds.length <= Constants.TOKEN_QUERY_LIMIT,
            "Bad input"
        );

        // Get to be created array length first.
        uint256 publishesArrayLen;

        // Loop through the given tokenIds array to check each id if it exists.
        for (uint256 i = 0; i < tokenIds.length; ) {
            if (_exists(tokenIds[i])) {
                publishesArrayLen++;
            }
            unchecked {
                i++;
            }
        }

        // Revert if no any Publish found.
        if (publishesArrayLen == 0) revert("Not found");

        // Create a fix size empty array.
        DataTypes.Publish[] memory publishes = new DataTypes.Publish[](
            publishesArrayLen
        );
        // Track the array index
        uint256 index;

        // Loop through the given token ids again to find a token for each id and put it in the array.
        for (uint256 i = 0; i < tokenIds.length; ) {
            if (_exists(tokenIds[i])) {
                publishes[index] = _tokenById[tokenIds[i]];
                index++;
            }
            unchecked {
                i++;
            }
        }

        return publishes;
    }

    /**
     * @dev see IPublishNFT - publishById
     */
    function publishById(uint256 tokenId)
        external
        view
        override
        returns (DataTypes.Publish memory)
    {
        // Token id must exist
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
     * @dev see IPublishNFT - ownerOfPublish
     */
    function ownerOfPublish(uint256 publishId) external view returns (address) {
        // Publish must exist.
        require(_exists(publishId), "Publish not found");

        return ownerOf(publishId);
    }

    /**
     * A public function to burn a token.
     * @param tokenId {number} - a token id to be burned
     */
    function burn(uint256 tokenId) public override {
        // Token must exist.
        require(_exists(tokenId), "Token not found");

        // The caller must be the owner.
        require(msg.sender == ownerOf(tokenId), "Forbidden");

        // Remove the token from _tokenById mapping.
        delete _tokenById[tokenId];

        // Call the parent burn function.
        super.burn(tokenId);

        emit PublishDeleted(tokenId, msg.sender);
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
