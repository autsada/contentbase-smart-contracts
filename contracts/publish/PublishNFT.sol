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
import {Constants} from "../../libraries/Constants.sol";
import {Helpers} from "../../libraries/Helpers.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

/**
 * @title PublishNFT
 *
 * @notice The create publish function will only be called from Profile contract as we need to have some checks in there to make sure only addresses that have profiles can create publishes.
 * @notice The function to set Profile contract address must have onlyRole(ADMIN_ROLE) modifier.
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

    // Profile contract address for use to check if the caller is the Profile contract when create Publish NFT.
    address private _profileContractAddress;

    // Mapping of publish struct by token id.
    mapping(uint256 => DataTypes.PublishStruct) private _tokenById;

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
     * An external function to set Profile contract
     * @dev only ADMIN_ROLE can call this function
     */
    function setProfileContract(address profileContractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        _profileContractAddress = profileContractAddress;
    }

    /**
     * A modifier to check if the caller is a Profile contract address
     */
    modifier onlyProfile() {
        require(msg.sender == _profileContractAddress, "Not allow");
        _;
    }

    /**
     * An external function that will be called to crate Publish NFT
     * @dev this function only allows call from the Profile contract.
     * @dev parameters validation to be done by caller (Profile contract).
     * @param createPublishData {struct} - refer to DataTypes.CreatePublishData struct
     * @return token {PublishStruct}
     */
    function createPublish(
        DataTypes.CreatePublishData calldata createPublishData
    ) external override onlyProfile returns (DataTypes.PublishStruct memory) {
        return _createPublish(createPublishData);
    }

    /**
     * A private function that contains the logic to create Publish NFT.
     * @dev parameters validation will be done by caller function.
     * @param createPublishData {struct} - refer to DataTypes.CreatePublishData struct
     * @return token {PublishStruct}
     *
     */
    function _createPublish(
        DataTypes.CreatePublishData calldata createPublishData
    ) private returns (DataTypes.PublishStruct memory) {
        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint an NFT to the owner
        _safeMint(createPublishData.owner, tokenId);

        // Update tokenURI.
        _setTokenURI(tokenId, createPublishData.tokenURI);

        // Update _tokenById mapping.
        DataTypes.PublishStruct memory newToken = DataTypes.PublishStruct({
            tokenId: tokenId,
            creatorId: createPublishData.creatorId,
            owner: createPublishData.owner,
            imageURI: createPublishData.imageURI,
            contentURI: createPublishData.contentURI
        });
        _tokenById[tokenId] = newToken;

        return newToken;
    }

    /**
     * An external function to get Publish NFTs by ids.
     * @param tokenIds {uint256[]} - an array of token ids
     * @return tokens {PublishStruct[]} - an array of Publish structs
     */
    function publishesByIds(uint256[] calldata tokenIds)
        external
        view
        override
        returns (DataTypes.PublishStruct[] memory)
    {
        // Validate the token ids array length
        if (
            tokenIds.length == 0 ||
            tokenIds.length > Constants.PUBLISH_QUERY_LIMIT
        ) revert("Invalid parameter");

        // Get the length of to be created array, cannot use "tokenIds.length" as some id might not exist.
        uint256 publishesArrayLen;

        // Loop through the tokenIds array to check if each id exits.
        for (uint256 i = 0; i < tokenIds.length; ) {
            if (_exists(tokenIds[i])) {
                publishesArrayLen++;
            }
            unchecked {
                i++;
            }
        }

        // Check if the length of to be created array is greater than 0.
        if (publishesArrayLen == 0) revert("No publishes found");

        // Once the length of to be created array is known, loop through the tokenIds again and construct a Publish struct for each id.
        // Create an empty array first.
        DataTypes.PublishStruct[] memory tokens = new DataTypes.PublishStruct[](
            publishesArrayLen
        );
        // Track the index of the array.
        uint256 index;

        for (uint256 i = 0; i < tokenIds.length; ) {
            if (_exists(tokenIds[i])) {
                // Find the token and put it in the array
                tokens[index] = _tokenById[tokenIds[i]];
                index++;
            }
            unchecked {
                i++;
            }
        }

        return tokens;
    }

    /**
     * An external function to get a Publish NFT.
     * @param tokenId {uint256}
     * @return token {PublishStruct}
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
     * An external function to get total NFTs count.
     * @return total {uint256} - total number of NFTs already minted
     */
    function totalPublishes() external view override returns (uint256) {
        return _tokenIdCounter.current();
    }

    /**
     * A public function to burn a token.
     * @param tokenId {number} - a token id to be burned
     */
    function burn(uint256 tokenId) public override {
        // Token must exist.
        require(_exists(tokenId), "Token not found");

        // Find the owner.
        address owner = ownerOf(tokenId);
        // The caller must be the owner.
        require(msg.sender == owner);

        // Remove the token from _tokenById mapping.
        delete _tokenById[tokenId];

        // Call the parent burn function.
        super.burn(tokenId);
    }

    /**
     * @notice If it's not the first creation or burn token, the token in non-transferable
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

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    /**
     * @param tokenId {number}
     * @return tokenURI {string} - a uri of the token's metadata
     *
     */
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
