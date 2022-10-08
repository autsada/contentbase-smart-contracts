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
import "./IProfileNFT.sol";
import "../publish/IPublishNFT.sol";
import {Constants} from "../../libraries/Constants.sol";
import {Helpers} from "../../libraries/Helpers.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

/**
 * @title ProfileNFT
 *
 * @notice This is the entrypoint to other Content Base Contracts. To mint other NFTs (Publish, Follow, Like, Share) and calling write functions in other contracts must be done via ProfileNFT Contract.
 */

contract ProfileNFT is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IProfileNFT
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    // Publish contract.
    IPublishNFT private _publishContract;

    // Mapping of token id by handle hash.
    mapping(bytes32 => uint256) private _tokenIdByHandleHash;
    // Mapping to track user's default profile
    mapping(address => uint256) private _defaultTokenIdByAddress;
    // Mapping of profile struct by token id.
    mapping(uint256 => DataTypes.ProfileStruct) private _tokenById;

    // Events
    event ProfileCreated(DataTypes.ProfileStruct token, address owner);
    event ProfileImageUpdated(DataTypes.ProfileStruct token, address owner);
    event DefaultProfileUpdated(DataTypes.ProfileStruct token, address owner);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("Content Base Profile", "CBPr");
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
     * An external function to set Publish contract for use to create Publish NFT.
     * @dev only allow ADMIN_ROLE
     */
    function setPublishContract(address publishContractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        _publishContract = IPublishNFT(publishContractAddress);
    }

    /**
     * An external function to create Profile NFT.
     * @dev validations must be done in this function.
     * @param createProfileData {struct} - refer to DataTypes.CreateProfileData struct
     * @return tokenId
     *
     */
    function createProfile(
        DataTypes.CreateProfileData calldata createProfileData
    ) external override returns (uint256) {
        // Validate handle length and special characters, the helper function will revert with error message if the check is false so we don't have to set the error message here.
        require(Helpers.validateHandle(createProfileData.handle));

        // Check if handle is already taken.
        require(
            Helpers.handleUnique(
                createProfileData.handle,
                _tokenIdByHandleHash
            ),
            "Handle taken"
        );

        // Validate tokenURI, the helper function will revert with error message if the check is false so we don't have to set the error message here.
        require(Helpers.notTooShortURI(createProfileData.tokenURI));
        require(Helpers.notTooLongURI(createProfileData.tokenURI));

        // The imageURI can be empty so we don't have to validate min length.
        require(Helpers.notTooLongURI(createProfileData.imageURI));

        return
            _createProfile({
                owner: msg.sender,
                createProfileData: createProfileData
            });
    }

    /**
     * A private function that contains the logic to create Profile NFT.
     * @dev validations will be done by caller function.
     * @param owner {address} - an address to be set as an owner of the NFT
     * @param createProfileData {struct} - refer to DataTypes.CreateProfileData struct
     * @return tokenId {uint256}
     *
     */
    function _createProfile(
        address owner,
        DataTypes.CreateProfileData calldata createProfileData
    ) private returns (uint256) {
        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint an NFT to owner
        _safeMint(owner, tokenId);

        // Store tokenURI
        _setTokenURI(tokenId, createProfileData.tokenURI);

        // Update _tokenIdByHandleHash mapping.
        _tokenIdByHandleHash[
            Helpers.hashHandle(createProfileData.handle)
        ] = tokenId;

        // Update _tokenById mapping.
        DataTypes.ProfileStruct memory newToken = DataTypes.ProfileStruct({
            tokenId: tokenId,
            owner: owner,
            handle: createProfileData.handle,
            imageURI: createProfileData.imageURI
        });
        _tokenById[tokenId] = newToken;

        // If user doesn't have a default profile yet, set this new token as their default profile.
        if (_defaultTokenIdByAddress[owner] == 0) {
            _defaultTokenIdByAddress[owner] = tokenId;
        }

        // Emit create profile event.
        emit ProfileCreated(newToken, owner);

        return tokenId;
    }

    /**
     * An external function to update profile image.
     * @dev validations must be done in this function.
     * @param updateProfileImageData - refer to DataTypes.UpdateProfileImageData struct
     * @return tokenId
     *
     */
    function updateProfileImage(
        DataTypes.UpdateProfileImageData calldata updateProfileImageData
    ) external override returns (uint256) {
        // The token id must exist.
        require(_exists(updateProfileImageData.tokenId), "Not found");

        // The caller must own the token.
        require(
            ownerOf(updateProfileImageData.tokenId) == msg.sender,
            "Forbidden"
        );

        // Validate the image uri.
        // The image uri might not change, in this case imageURI is empty, only validate if it's not empty.
        if (bytes(updateProfileImageData.imageURI).length != 0) {
            require(Helpers.notTooShortURI(updateProfileImageData.imageURI));
            require(Helpers.notTooLongURI(updateProfileImageData.imageURI));
        }

        // Validate the token uri.
        require(Helpers.notTooShortURI(updateProfileImageData.tokenURI));
        require(Helpers.notTooLongURI(updateProfileImageData.tokenURI));

        // Check if the tokenURI changed.
        // Don't have to check the imageURI as it might not be changed even the image changed.
        // If the tokenURI which stored on ipfs does not change, it means the image hasn't changed.
        require(
            keccak256(
                abi.encodePacked(tokenURI(updateProfileImageData.tokenId))
            ) != keccak256(abi.encodePacked(updateProfileImageData.tokenURI)),
            "Nothing change"
        );

        return
            _updateProfileImage({
                owner: msg.sender,
                updateProfileImageData: updateProfileImageData
            });
    }

    /**
     * A private function that contain the logic to update profile image.
     * @dev validations will be done by caller function.
     * @param owner {address}
     * @param updateProfileImageData - refer to DataTypes.UpdateProfileImageData
     * @return tokenId
     *
     */
    function _updateProfileImage(
        address owner,
        DataTypes.UpdateProfileImageData calldata updateProfileImageData
    ) internal returns (uint256) {
        uint256 tokenId = updateProfileImageData.tokenId;

        // Update tokenURI.
        _setTokenURI(tokenId, updateProfileImageData.tokenURI);

        // Update the profile struct.
        // If imageURI not provided, use the existing data otherwise use the new data.
        string memory oldImageURI = _tokenById[tokenId].imageURI;
        string memory newImageURI = bytes(updateProfileImageData.imageURI)
            .length == 0
            ? oldImageURI
            : updateProfileImageData.imageURI;
        _tokenById[tokenId].imageURI = newImageURI;

        // Emit update profile event.
        emit ProfileImageUpdated(_tokenById[tokenId], owner);

        return tokenId;
    }

    /**
     * An external function to set default profile.
     * @dev validations must be done in this function.
     * @param tokenId - a token id
     */
    function setDefaultProfile(uint256 tokenId) external override {
        // The id must exist
        require(_exists(tokenId), "Profile not found");

        // The Caller must own the token
        require(ownerOf(tokenId) == msg.sender, "Forbidden");

        // If the id is already a default, revert
        if (_defaultTokenIdByAddress[msg.sender] == tokenId)
            revert("Already a default");

        _setDefaultProfile({owner: msg.sender, tokenId: tokenId});
    }

    /**
     * A private function that contain the logic to set default profile.
     * @dev validations will be done by caller function.
     * @param owner {address}
     * @param tokenId {uint256}
     */
    function _setDefaultProfile(address owner, uint256 tokenId) private {
        // Update the mapping
        _defaultTokenIdByAddress[owner] = tokenId;

        // Emit an event
        emit DefaultProfileUpdated(_tokenById[tokenId], owner);
    }

    /**
     * An external function to list user's profiles.
     * @dev limit to 10 ids at a time
     * @param tokenIds {uint256[]} - An array of token ids
     * @return profiles {struct[]}
     */
    function ownerProfiles(uint256[] calldata tokenIds)
        external
        view
        override
        returns (DataTypes.ProfileStruct[] memory)
    {
        require(tokenIds.length < 11, "Limit to 10 profiles per request");

        // Get the length of to be created array, cannot use "tokenIds.length" as some id might not own by the caller.
        uint256 profileArrayLen;

        // Loop through the token ids array and check if the token exists and the caller is the owner.
        for (uint256 i = 0; i < tokenIds.length; ) {
            if (_exists(tokenIds[i]) && (ownerOf(tokenIds[i]) == msg.sender)) {
                profileArrayLen++;
            }
            unchecked {
                i++;
            }
        }

        require(profileArrayLen > 0, "No profiles found");

        // Create a profiles array in memory with the fix size of the array length.
        DataTypes.ProfileStruct[]
            memory profiles = new DataTypes.ProfileStruct[](profileArrayLen);

        // Loop through the ids array again to find the Profile struct for each id.
        // Track the index of to be created array.
        uint index;
        for (uint256 i = 0; i < tokenIds.length; ) {
            if (_exists(tokenIds[i]) && (ownerOf(tokenIds[i]) == msg.sender)) {
                profiles[index] = _tokenById[tokenIds[i]];
                index++;
            }
            unchecked {
                i++;
            }
        }

        return profiles;
    }

    /**
     * An external function to get the caller's default profile.
     */
    function defaultProfile()
        external
        view
        override
        returns (DataTypes.ProfileStruct memory)
    {
        uint256 tokenId = _defaultTokenIdByAddress[msg.sender];
        require(tokenId != 0, "Not found");

        return _tokenById[tokenId];
    }

    /**
     * An external function to get a profile by id.
     * @param tokenId {uint256}
     * @return token {struct}
     *
     */
    function profileById(uint256 tokenId)
        external
        view
        override
        returns (DataTypes.ProfileStruct memory)
    {
        // Token id must exist
        require(_exists(tokenId), "Not found");

        return _tokenById[tokenId];
    }

    /**
     * An external function to get total NFTs count.
     * @return count {uint256}
     *
     */
    function totalProfiles() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    /**
     * An external function to validate handle - validate length, special characters and uniqueness.
     * @param handle {string}
     * @return boolean
     */
    function validateHandle(string calldata handle)
        external
        view
        returns (bool)
    {
        return
            Helpers.handleUnique(handle, _tokenIdByHandleHash) &&
            Helpers.validateHandle(handle);
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

        // If the token id is a default profile, revert.
        if (_defaultTokenIdByAddress[msg.sender] == tokenId)
            revert("Burn default profile not allowed");

        // Clear token id from _tokenIdByHandleHash mapping.
        string memory handle = _tokenById[tokenId].handle;
        delete _tokenIdByHandleHash[keccak256(bytes(handle))];

        // Clear the token from _tokenById mapping.
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
     * @return tokenURI {string} - a url point the metadata.json containing the token data consist of:
     * - name {string} - "Content Base Profile"
     * - description {string} - "A profile of ${handle}", handle is the name who owns the profile
     * - image {string} - An ipfs uri point to an image stored on ipfs
     * - properties {object} - Other additional information of the token
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
