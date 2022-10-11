// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";
import "./IPublishNFT.sol";
import "../profile/IProfileNFT.sol";
import {Constants} from "../../libraries/Constants.sol";
import {Helpers} from "../../libraries/Helpers.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

/**
 * @title PublishNFT
 * @dev frontend needs to track token ids own by each address so it can query tokens for each address.
 */

contract PublishNFT is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
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

    // Mapping of publish struct by token id.
    mapping(uint256 => DataTypes.PublishStruct) private _tokenById;

    // Events
    event PublishCreated(DataTypes.PublishStruct token, address owner);
    event PublishUpdated(DataTypes.PublishStruct token, address owner);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("Content Base Publish", "CBPu");
        __ERC721URIStorage_init();
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

        // Validate tokenURI.
        require(Helpers.notTooShortURI(createPublishData.tokenURI));
        require(Helpers.notTooLongURI(createPublishData.tokenURI));

        // Validate imageURI.
        require(Helpers.notTooShortURI(createPublishData.imageURI));
        require(Helpers.notTooLongURI(createPublishData.imageURI));

        // Validate contentlURI.
        require(Helpers.notTooShortURI(createPublishData.contentURI));
        require(Helpers.notTooLongURI(createPublishData.contentURI));

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

        // Update tokenURI.
        _setTokenURI(tokenId, createPublishData.tokenURI);

        // Update _tokenById mapping.
        DataTypes.PublishStruct memory newToken = DataTypes.PublishStruct({
            creatorId: createPublishData.creatorId,
            owner: owner,
            imageURI: createPublishData.imageURI,
            contentURI: createPublishData.contentURI
        });
        _tokenById[tokenId] = newToken;

        // Emit publish created event.
        emit PublishCreated(_tokenById[tokenId], owner);

        return tokenId;
    }

    /**
     * @dev see IPublishNFT - updatePublish
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

        // Validate tokenURI.
        require(Helpers.notTooShortURI(updatePublishData.tokenURI));
        require(Helpers.notTooLongURI(updatePublishData.tokenURI));

        // Validate imageURI
        // The image uri (which is a publish's thumbnail image) might not change, in this case updatePublishData.imageURI is empty, so only validate if it's not empty.
        if (bytes(updatePublishData.imageURI).length != 0) {
            require(Helpers.notTooShortURI(updatePublishData.imageURI));
            require(Helpers.notTooLongURI(updatePublishData.imageURI));
        }

        // Validate contentlURI.
        // The content uri might not change, in this case updatePublishData.contentURI is empty, so only validate if it's not empty.
        if (bytes(updatePublishData.contentURI).length != 0) {
            require(Helpers.notTooShortURI(updatePublishData.contentURI));
            require(Helpers.notTooLongURI(updatePublishData.contentURI));
        }

        // Check if the tokenURI changed.
        // Don't have to check the imageURI and contentURI as it might not be changed even the image/content changed.
        require(
            keccak256(abi.encodePacked(tokenURI(updatePublishData.tokenId))) !=
                keccak256(abi.encodePacked(updatePublishData.tokenURI)),
            "Nothing change"
        );

        // Update the token uri.
        _setTokenURI(updatePublishData.tokenId, updatePublishData.tokenURI);

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
     *
     */
    function _updatePublish(
        address owner,
        DataTypes.UpdatePublishData calldata updatePublishData
    ) private returns (uint256) {
        // If imageURI is empty, use the existing data otherwise use the updated data
        string memory oldImageURI = _tokenById[updatePublishData.tokenId]
            .imageURI;
        string memory newImageURI = bytes(updatePublishData.imageURI).length ==
            0
            ? oldImageURI
            : updatePublishData.imageURI;

        // If contentURI is empty, use the existing data otherwise use the updated data
        string memory oldContentURI = _tokenById[updatePublishData.tokenId]
            .contentURI;
        string memory newContentURI = bytes(updatePublishData.contentURI)
            .length == 0
            ? oldContentURI
            : updatePublishData.contentURI;

        // Update the data in storage
        _tokenById[updatePublishData.tokenId].imageURI = newImageURI;
        _tokenById[updatePublishData.tokenId].contentURI = newContentURI;

        // Emit publish created event
        emit PublishUpdated(_tokenById[updatePublishData.tokenId], owner);

        return updatePublishData.tokenId;
    }

    /**
     * @dev see IPublishNFT - ownerPublishes
     */
    function ownerPublishes(uint256[] calldata tokenIds)
        external
        view
        override
        returns (DataTypes.PublishStruct[] memory)
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
        DataTypes.PublishStruct[]
            memory publishes = new DataTypes.PublishStruct[](publishesArrayLen);
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
        returns (DataTypes.PublishStruct[] memory)
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
        DataTypes.PublishStruct[]
            memory publishes = new DataTypes.PublishStruct[](publishesArrayLen);
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
        returns (DataTypes.PublishStruct memory)
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

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
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
