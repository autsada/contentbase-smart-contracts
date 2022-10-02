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
import "./ContentBaseProfile.sol";
import "./ContentBasePublish.sol";
import {Constants} from "../libraries/Constants.sol";
import {Helpers} from "../libraries/Helpers.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

contract ContentBase is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ContentBaseProfile,
    ContentBasePublish
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    /**
     * There are 4 types of token that use the same token counter, so it's needed to track each type separately
     * These are 4 types:
     * - Profile type
     * - Publish type
     * - Follow type
     * - Like type
     */

    // Mapping of array of profile ids by address.
    mapping(address => uint256[]) private _profileIdsByAddress;
    // Mapping of rofile id by handle hash.
    mapping(bytes32 => uint256) private _profileIdByHandleHash;
    // Mapping of profile struct by profile id.
    mapping(uint256 => DataTypes.Profile) private _profileById;

    // Mapping of array of publish ids by address.
    mapping(address => uint256[]) private _publishIdsByAddress;
    // Mapping of publish struct by publish id.
    mapping(uint256 => DataTypes.Publish) private _publishById;
    // Array of all publish ids
    uint256[] private _allPublishIds;
    // Mapping of publish count by categories
    mapping(bytes32 => uint256) private _publishCountByCategory;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("Content Base", "CTB");
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

    /// ***********************
    /// ***** Profile Logic *****
    /// ***********************

    /**
     * A public function to create profile nft.
     * @param uri {string} - a uri point to the token's metadata file
     * @param createProfileParams {struct} - refer to DataTypes.CreateProfileParams struct
     *
     */
    function createProfile(
        string calldata uri,
        DataTypes.CreateProfileParams calldata createProfileParams
    ) public override returns (uint256) {
        // Validate handle length and special characters, the helper function will revert with error message if the check is false so we don't have to set the error message here.
        require(Helpers.onlyValidHandle(createProfileParams.handle));

        // Check if handle is already taken.
        require(
            Helpers.onlyUniqueHandle(
                createProfileParams.handle,
                _profileIdByHandleHash
            )
        );

        // Validate tokenURI, the helper function will revert with error message if the check is false so we don't have to set the error message here.
        require(Helpers.notTooShortURI(uri));
        require(Helpers.notTooLongURI(uri));

        // The imageURI can be empty so we don't have to validate min length.
        require(Helpers.notTooLongURI(createProfileParams.imageURI));

        // Mint new token.
        uint256 tokenId = _mintToken(msg.sender, uri);

        // Create a profile.
        return
            _createProfile({
                owner: msg.sender,
                profileId: tokenId,
                createProfileParams: createProfileParams,
                _profileIdsByAddress: _profileIdsByAddress,
                _profileIdByHandleHash: _profileIdByHandleHash,
                _profileById: _profileById
            });
    }

    /**
     * A public function to update profile image.
     * @dev token id must exist
     * @dev caller must be the owner of the token
     * @param updateProfileImageParams - refer to DataTypes.UpdateProfileImageParams
     */
    function updateProfileImage(
        DataTypes.UpdateProfileImageParams calldata updateProfileImageParams
    ) public override returns (uint256) {
        // Check if the caller is the owner of the profile.
        require(
            ownerOf(updateProfileImageParams.profileId) == msg.sender,
            "Forbidden"
        );

        // Check if the profile id exist.
        require(
            _exists(updateProfileImageParams.profileId),
            "Profile not found"
        );

        // Check if it's profile token
        require(_isProfile(updateProfileImageParams.profileId), "Not found");

        // Validate the image uri.
        require(Helpers.notTooShortURI(updateProfileImageParams.imageURI));
        require(Helpers.notTooLongURI(updateProfileImageParams.imageURI));

        // Validate the token uri.
        require(Helpers.notTooShortURI(updateProfileImageParams.tokenURI));
        require(Helpers.notTooLongURI(updateProfileImageParams.tokenURI));

        // Validate if the tokenURI changed.
        // Don't have to validate the imageURI as it might not be changed even the image changed.
        require(
            keccak256(
                abi.encodePacked(tokenURI(updateProfileImageParams.profileId))
            ) == keccak256(abi.encodePacked(updateProfileImageParams.tokenURI)),
            "Nothing change"
        );

        // Update the token uri.
        _setTokenURI(
            updateProfileImageParams.profileId,
            updateProfileImageParams.tokenURI
        );

        // Update the profile struct.
        return
            _updateProfileImage({
                owner: msg.sender,
                profileId: updateProfileImageParams.profileId,
                imageURI: updateProfileImageParams.imageURI,
                _profileById: _profileById
            });
    }

    /**
     * A public function to update profile image.
     * @dev token id must exist
     * @dev caller must be the owner of the token
     * @param profileId - a token id
     */
    function setDefaultProfile(uint256 profileId) public override {
        // The id must exist
        require(_exists(profileId), "Profile not found");

        // Caller must own the token
        require(ownerOf(profileId) == msg.sender, "Forbidden");

        // Must be a profile token
        require(_isProfile(profileId), "Profile not found");

        // If the id is already a default, revert
        if (_profileById[profileId].isDefault) revert("Already a default");

        // Update the profile
        _setDefaultProfile({
            owner: msg.sender,
            profileId: profileId,
            _profileIdsByAddress: _profileIdsByAddress,
            _profileById: _profileById
        });
    }

    /**
     * A public function to fetch profiles of a specific address
     * @param owner {address} - An address who owns profiles
     */
    function fetchProfilesByAddress(address owner)
        public
        view
        override
        returns (DataTypes.Profile[] memory)
    {
        return
            _fetchProfilesByAddress(owner, _profileIdsByAddress, _profileById);
    }

    /**
     * A public function to get a profile by id
     * @param profileId {uint256}
     */
    function getProfileById(uint256 profileId)
        public
        view
        returns (DataTypes.Profile memory)
    {
        // Profile must exist
        require(_exists(profileId), "Not found");

        // Must be a profile token
        require(_isProfile(profileId), "Not found");

        return _profileById[profileId];
    }

    /**
     * A public function to validate handle - validate length, special characters and uniqueness.
     * @param handle {string}
     */
    function validateHandle(string calldata handle) public view returns (bool) {
        require(Helpers.onlyValidHandle(handle));

        return Helpers.onlyUniqueHandle(handle, _profileIdByHandleHash);
    }

    /**
     * A helper function to check  if the token is a profile token.
     */
    function _isProfile(uint256 tokenId) private view returns (bool) {
        return (_profileById[tokenId].owner != address(0) &&
            _profileById[tokenId].profileId != 0);
    }

    /// ***********************
    /// ***** Publish Logic *****
    /// ***********************

    /**
     * A public function to create publish nft.
     * @param uri {string} - a uri point to the token's metadata file
     * @param createPublishParams {struct} - refer to DataTypes.CreatePublishParams struct
     *
     */
    function createPublish(
        string calldata uri,
        DataTypes.CreatePublishParams calldata createPublishParams
    ) public override returns (uint256) {
        // Get caller's profile id from the handle
        uint256 profileId = _profileIdByHandleHash[
            Helpers.hashHandle(createPublishParams.handle)
        ];

        // Handle (profile id) must exist
        require(_exists(profileId), "Handle not found");

        // Caller must own the handle (profile id)
        require(ownerOf(profileId) == msg.sender, "Forbidden");

        // Validate tokenURI.
        require(Helpers.notTooShortURI(uri));
        require(Helpers.notTooLongURI(uri));

        // Validate title length
        require(Helpers.onlyValidHandle(createPublishParams.title));

        // Validate description length
        require(Helpers.onlyValidDescription(createPublishParams.description));

        // Validate categories
        require(Helpers.onlyValidCategories(createPublishParams.categories));

        // Validate thumbnailURI.
        require(Helpers.notTooShortURI(createPublishParams.thumbnailURI));
        require(Helpers.notTooLongURI(createPublishParams.thumbnailURI));

        // Validate contentlURI.
        require(Helpers.notTooShortURI(createPublishParams.contentURI));
        require(Helpers.notTooLongURI(createPublishParams.contentURI));

        // Mint new token.
        uint256 tokenId = _mintToken(msg.sender, uri);

        return
            _createPublish({
                owner: msg.sender,
                publishId: tokenId,
                createPublishParams: createPublishParams,
                _publishIdsByAddress: _publishIdsByAddress,
                _publishById: _publishById,
                _allPublishIds: _allPublishIds,
                _publishCountByCategory: _publishCountByCategory
            });
    }

    /// ***********************
    /// ***** General Logic *****
    /// ***********************

    /**
     * A private function to mint nft
     * @param to {address} - mint to address
     * @param uri {string} - tokenURI
     */
    function _mintToken(address to, string calldata uri)
        private
        returns (uint256)
    {
        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(to, tokenId);

        // Store tokenURI
        _setTokenURI(tokenId, uri);

        return tokenId;
    }

    /**
     * A public function to get total NFTs count.
     */
    function totalNFTs() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    /**
     * A public function to burn a token.
     * @param tokenId {number} - a token id to be burned
     */
    function burn(uint256 tokenId) public override {
        // Token must exist.
        require(_exists(tokenId), "Token not found");

        // Find an owner.
        address owner = ownerOf(tokenId);

        // The caller must me the owner
        require(msg.sender == owner);

        // If the token is a profile token, delete the token id (the profile id) from owner's profileIds array.
        DataTypes.Profile memory profile = _profileById[tokenId];
        if (profile.owner == owner && profile.profileId == tokenId) {
            // This case means the token is a profile token.

            // 1. Delete the profile from profile by id mapping.
            delete _profileById[tokenId];

            // 2. Remove the burned id from user's profile ids array.
            uint256[] memory profileIds = _profileIdsByAddress[owner];

            if (profileIds.length > 0) {
                // Contruct a new profile ids array
                uint256[] memory updatedProfileIds = new uint256[](
                    profileIds.length - 1
                );
                uint256 index = 0;

                // Loop though the current profile ids array to filter out the burned id
                for (uint256 i = 0; i < profileIds.length; ) {
                    if (profileIds[i] != tokenId) {
                        // Keep only the id that doesn't equal tokenId.
                        updatedProfileIds[index] = profileIds[i];
                        index++;
                    }
                    unchecked {
                        i++;
                    }
                }

                _profileIdsByAddress[owner] = updatedProfileIds;

                // If the burned id is a default profile and user still have some profiles left, set the first id in the remaining profile ids array as a default
                if (profile.isDefault && updatedProfileIds.length > 0) {
                    _profileById[updatedProfileIds[0]].isDefault = true;
                }
            }
        } else {}

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
