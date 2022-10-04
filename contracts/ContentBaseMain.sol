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

    // Mapping of rofile id by handle hash.
    mapping(bytes32 => uint256) private _profileIdByHandleHash;
    // Mapping to track user's default profile
    mapping(address => uint256) private _defaultProfileIdByAddress;
    // Mapping of token struct by token id.
    mapping(uint256 => DataTypes.Token) private _tokenById;

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
     * An external function to create profile nft.
     * @param uri {string} - a uri of the token's metadata file
     * @param createProfileData {struct} - refer to DataTypes.CreateProfileData struct
     *
     */
    function createProfile(
        string calldata uri,
        DataTypes.CreateProfileData calldata createProfileData
    ) external override returns (uint256) {
        // Validate handle length and special characters, the helper function will revert with error message if the check is false so we don't have to set the error message here.
        require(Helpers.onlyValidHandle(createProfileData.handle));

        // Check if handle is already taken.
        require(
            Helpers.onlyUniqueHandle(
                createProfileData.handle,
                _profileIdByHandleHash
            )
        );

        // Validate tokenURI, the helper function will revert with error message if the check is false so we don't have to set the error message here.
        require(Helpers.notTooShortURI(uri));
        require(Helpers.notTooLongURI(uri));

        // The imageURI can be empty so we don't have to validate min length.
        require(Helpers.notTooLongURI(createProfileData.imageURI));

        // Mint new token.
        uint256 tokenId = _mintToken(msg.sender, uri);

        // If it's the caller's first profile, set the token id as default
        if (_defaultProfileIdByAddress[msg.sender] == 0) {
            _defaultProfileIdByAddress[msg.sender] = tokenId;
        }

        // Create a profile.
        return
            _createProfile({
                owner: msg.sender,
                tokenId: tokenId,
                createProfileData: createProfileData,
                _profileIdByHandleHash: _profileIdByHandleHash,
                _tokenById: _tokenById
            });
    }

    /**
     * An external function to update profile image.
     * @dev token must id exist
     * @dev caller must be the owner of the token
     * @dev must be a profile token
     * @param tokenId {uint256} - an id of the token to be updated
     * @param uri {string} - a new uri of the token's metadata
     * @param imageURI {string} - a new image uri
     */
    function updateProfileImage(
        uint256 tokenId,
        string calldata uri,
        string calldata imageURI
    ) external override returns (uint256) {
        // The token id must exist.
        require(_exists(tokenId), "Profile not found");

        // The caller must own the token.
        require(ownerOf(tokenId) == msg.sender, "Forbidden");

        // Must be a profile token
        require(_isProfile(tokenId), "Profile not found");

        // Validate the image uri.
        require(Helpers.notTooShortURI(imageURI));
        require(Helpers.notTooLongURI(imageURI));

        // Validate the token uri.
        require(Helpers.notTooShortURI(uri));
        require(Helpers.notTooLongURI(uri));

        // Validate if the tokenURI changed.
        // Don't have to validate the imageURI as it might not be changed even the image changed.
        require(
            keccak256(abi.encodePacked(tokenURI(tokenId))) !=
                keccak256(abi.encodePacked(uri)),
            "Nothing change"
        );

        // Update the token uri.
        _setTokenURI(tokenId, uri);

        // Update the profile struct.
        return
            _updateProfileImage({
                owner: msg.sender,
                tokenId: tokenId,
                imageURI: imageURI,
                _tokenById: _tokenById
            });
    }

    /**
     * An external function to set user's default profile.
     * @dev token id must exist
     * @dev caller must be the owner of the token
     * @dev must be a profile token
     * @param tokenId - a token id
     */
    function setDefaultProfile(uint256 tokenId) external override {
        // The id must exist
        require(_exists(tokenId), "Profile not found");

        // The Caller must own the token
        require(ownerOf(tokenId) == msg.sender, "Forbidden");

        // Must be a profile token
        require(_isProfile(tokenId), "Profile not found");

        // If the id is already a default, revert
        if (_defaultProfileIdByAddress[msg.sender] == tokenId)
            revert("Already a default");

        // Update the profile
        _setDefaultProfile({
            owner: msg.sender,
            tokenId: tokenId,
            _defaultProfileIdByAddress: _defaultProfileIdByAddress,
            _tokenById: _tokenById
        });
    }

    /**
     * An external function to list profiles of the caller
     * @dev limit to 5 ids at a time
     * @param tokenIds {uint256[]} - An array of token ids
     */
    function ownerProfiles(uint256[] calldata tokenIds)
        external
        view
        returns (DataTypes.Token[] memory)
    {
        require(tokenIds.length < 6, "Limit to 5 profiles per request");

        // Get the length of to be created profiles array, cannot use "tokenIds.length" as some id might not be a profile token
        uint256 profileArrayLen;

        // Loop through the token ids array and check if the token exists and it's a profile token
        for (uint256 i = 0; i < tokenIds.length; ) {
            if (
                _exists(tokenIds[i]) &&
                _isProfile(tokenIds[i]) &&
                (ownerOf(tokenIds[i]) == msg.sender)
            ) {
                profileArrayLen++;
            }
            unchecked {
                i++;
            }
        }

        require(profileArrayLen > 0, "No profiles found");

        // Create a profiles array in memory with the fix size of the array length.
        DataTypes.Token[] memory profiles = new DataTypes.Token[](
            profileArrayLen
        );

        // Loop through the token ids array and find the token and assign it to each item in the profiles array
        // Need to track the index of the profiles array
        uint index;
        for (uint256 i = 0; i < tokenIds.length; ) {
            if (
                _exists(tokenIds[i]) &&
                _isProfile(tokenIds[i]) &&
                (ownerOf(tokenIds[i]) == msg.sender)
            ) {
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
     * An external function to get a profile by token id
     * @param tokenId {uint256}
     */
    function profileById(uint256 tokenId)
        external
        view
        returns (DataTypes.Token memory)
    {
        // Token id must exist
        require(_exists(tokenId), "Not found");

        // Must be a profile token
        require(_isProfile(tokenId), "Not a profile");

        return _tokenById[tokenId];
    }

    /**
     * An external function to get the caller's default profile
     */
    function defaultProfile() external view returns (DataTypes.Token memory) {
        uint256 tokenId = _defaultProfileIdByAddress[msg.sender];
        require(tokenId != 0, "No default profile");

        DataTypes.Token memory profile = _tokenById[tokenId];

        return profile;
    }

    /**
     * An external function to validate handle - validate length, special characters and uniqueness.
     * @param handle {string}
     */
    function validateHandle(string calldata handle)
        external
        view
        returns (bool)
    {
        require(Helpers.onlyValidHandle(handle));

        return Helpers.onlyUniqueHandle(handle, _profileIdByHandleHash);
    }

    /**
     * A helper function to check  if the token is a profile token.
     */
    function _isProfile(uint256 tokenId) private view returns (bool) {
        return (_tokenById[tokenId].tokenType == DataTypes.TokenType.Profile);
    }

    /// ***********************
    /// ***** Publish Logic *****
    /// ***********************

    /**
     * An external function to create publish nft.
     * @param uri {string} - a uri of the token's metadata file
     * @param createPublishData {struct} - refer to DataTypes.CreatePublishData struct
     *
     */
    function createPublish(
        string calldata uri,
        DataTypes.CreatePublishData calldata createPublishData
    ) external override returns (uint256) {
        // Handle must not empty
        require(bytes(createPublishData.handle).length > 0, "Bad request");

        // Get caller's profile id (token id) from the handle hash
        uint256 profileId = _profileIdByHandleHash[
            Helpers.hashHandle(createPublishData.handle)
        ];

        // Profile id (handle / token id) must exist
        require(_exists(profileId), "Handle not found");

        // Caller must own the handle (profile id / token id)
        require(ownerOf(profileId) == msg.sender, "Forbidden");

        // Validate tokenURI.
        require(Helpers.notTooShortURI(uri));
        require(Helpers.notTooLongURI(uri));

        // Validate imageURI.
        require(Helpers.notTooShortURI(createPublishData.imageURI));
        require(Helpers.notTooLongURI(createPublishData.imageURI));

        // Validate contentlURI.
        require(Helpers.notTooShortURI(createPublishData.contentURI));
        require(Helpers.notTooLongURI(createPublishData.contentURI));

        // Mint new token.
        uint256 tokenId = _mintToken(msg.sender, uri);

        return
            _createPublish({
                owner: msg.sender,
                tokenId: tokenId,
                createPublishData: createPublishData,
                _tokenById: _tokenById
            });
    }

    /**
     * An external function to update a publish.
     * @dev token must id exist
     * @dev caller must be the owner of the token
     * @dev must be a publish token
     * @param tokenId {uint256} - an id of the token to be updated
     * @param uri {string} - a uri point to the token's metadata file
     * @param updatePublishData {struct} - refer to DataTypes.UpdatePublishData struct
     *
     */
    function updatePublish(
        uint256 tokenId,
        string calldata uri,
        DataTypes.UpdatePublishData calldata updatePublishData
    ) external override returns (uint256) {
        // The token id must exist.
        require(_exists(tokenId), "Publish not found");

        // The caller must own the token.
        require(ownerOf(tokenId) == msg.sender, "Forbidden");

        // Must be a publish token
        require(_isPublish(tokenId), "Publish not found");

        // Validate tokenURI.
        require(Helpers.notTooShortURI(uri));
        require(Helpers.notTooLongURI(uri));

        // Validate imageURI.
        require(Helpers.notTooShortURI(updatePublishData.imageURI));
        require(Helpers.notTooLongURI(updatePublishData.imageURI));

        // Validate contentlURI.
        require(Helpers.notTooShortURI(updatePublishData.contentURI));
        require(Helpers.notTooLongURI(updatePublishData.contentURI));

        // Validate if the tokenURI changed.
        // Don't have to validate the imageURI as it might not be changed even the image changed.
        require(
            keccak256(abi.encodePacked(tokenURI(tokenId))) ==
                keccak256(abi.encodePacked(uri)),
            "Nothing change"
        );

        // Update the token uri.
        _setTokenURI(tokenId, uri);

        return
            _updatePublish({
                owner: msg.sender,
                tokenId: tokenId,
                updatePublishData: updatePublishData,
                _tokenById: _tokenById
            });
    }

    /**
     * An external function to get owner publishes
     * @dev return the publishes that the caller is the owner
     * @param tokenIds {uint256[]} - an array of token ids
     */
    function ownerPublishes(uint256[] calldata tokenIds)
        external
        view
        returns (DataTypes.Token[] memory)
    {
        // Validate the token ids array length
        if (
            tokenIds.length == 0 ||
            tokenIds.length > Constants.PUBLISH_QUERY_LIMIT
        ) revert("Invalid parameter");

        // Get the length of to be created publishes array, cannot use "tokenIds.length" as some id might not be a publish token and the caller might not be an owner
        uint256 publishesArrayLen;

        // Loop through the tokenIds array to check if each id is a publish token and the caller is the owner
        for (uint256 i = 0; i < tokenIds.length; ) {
            if (
                _isPublish(tokenIds[i]) && (ownerOf(tokenIds[i]) == msg.sender)
            ) {
                publishesArrayLen++;
            }
            unchecked {
                i++;
            }
        }

        // Validate the length of to be created array
        if (publishesArrayLen == 0) revert("Publishes not found");

        // Once we know the length of to be created array, loop through the tokenIds again and construct a publish token for each id (if the id is a publish and the caller is the owner) and put it in the new array
        // Create an array first
        DataTypes.Token[] memory tokens = new DataTypes.Token[](
            publishesArrayLen
        );
        // Track the index
        uint256 index;
        for (uint256 i = 0; i < tokenIds.length; ) {
            if (
                _isPublish(tokenIds[i]) && (ownerOf(tokenIds[i]) == msg.sender)
            ) {
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
     * An external function to get owner's publish by token id
     * @dev return only the publish that the caller own
     * @param tokenId {uint256}
     */
    function ownerPublish(uint256 tokenId)
        external
        view
        returns (DataTypes.Token memory)
    {
        // Token id must exist
        require(_exists(tokenId), "Not found");

        // Must be a publish token
        require(_isPublish(tokenId), "Not a publish");

        // The caller must own the token
        require(ownerOf(tokenId) == msg.sender, "Forbidden");

        return _tokenById[tokenId];
    }

    /**
     * An external function to get publishes
     * @dev similar to ownerPublishes but not specific to the publishes that owned by the caller, return only with visibility is ON
     * @param tokenIds {uint256[]} - an array of token ids
     */
    function publishesByIds(uint256[] calldata tokenIds)
        external
        view
        returns (DataTypes.Token[] memory)
    {
        // Validate the token ids array length
        if (
            tokenIds.length == 0 ||
            tokenIds.length > Constants.PUBLISH_QUERY_LIMIT
        ) revert("Invalid parameter");

        // Get the length of to be created publishes array, cannot use "tokenIds.length" as some id might not be a publish token
        uint256 publishesArrayLen;

        // Loop through the tokenIds array to check if each id is a publish token and its visibility is ON
        for (uint256 i = 0; i < tokenIds.length; ) {
            if (
                _isPublish(tokenIds[i]) &&
                (_tokenById[tokenIds[i]].visibility == DataTypes.Visibility.ON)
            ) {
                publishesArrayLen++;
            }
            unchecked {
                i++;
            }
        }

        // Validate the length of to be created array
        if (publishesArrayLen == 0) revert("Publishes not found");

        // Once we know the length of to be created array, loop through the tokenIds again and construct a publish token for each id (if the id is a publish and visibility is ON) and put it in the new array
        // Create an array first
        DataTypes.Token[] memory tokens = new DataTypes.Token[](
            publishesArrayLen
        );
        // Track the index
        uint256 index;
        for (uint256 i = 0; i < tokenIds.length; ) {
            if (
                _isPublish(tokenIds[i]) &&
                (_tokenById[tokenIds[i]].visibility == DataTypes.Visibility.ON)
            ) {
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
     * An external function to get a publish by token id
     * @dev similar to ownerPublish except not only the publish that the caller own but with only visibility ON
     * @param tokenId {uint256}
     */
    function publishById(uint256 tokenId)
        external
        view
        returns (DataTypes.Token memory)
    {
        // Token id must exist
        require(_exists(tokenId), "Not found");

        // Must be a publish token
        require(_isPublish(tokenId), "Not a publish");

        // Visibility must be ON
        require(
            _tokenById[tokenId].visibility == DataTypes.Visibility.ON,
            "Forbidden"
        );

        return _tokenById[tokenId];
    }

    /**
     * A helper function to check  if the token is a publish token.
     */
    function _isPublish(uint256 tokenId) private view returns (bool) {
        require(_exists(tokenId), "Not exist");

        return (_tokenById[tokenId].tokenType == DataTypes.TokenType.Publish);
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
     * An external function to get total NFTs count.
     */
    function totalNFTs() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    /**
     * A public function to burn a token.
     * @param tokenId {number} - a token id to be burned
     */
    function burn(uint256 tokenId) public override {
        // Token must exist.
        require(_exists(tokenId), "Token not found");

        // Not allow if the token is a profile token and it's the caller's default token
        if (
            _isProfile(tokenId) &&
            _defaultProfileIdByAddress[msg.sender] == tokenId
        ) revert("Cannot burn default profile");

        // Find an owner.
        address owner = ownerOf(tokenId);

        // The caller must me the owner.
        require(msg.sender == owner);

        // If the token is a profile token
        if (_isProfile(tokenId)) {
            // Remove the handle hash from _profileIdByHandleHash
            DataTypes.Token memory profile = _tokenById[tokenId];
            delete _profileIdByHandleHash[keccak256(bytes(profile.handle))];

            // If it's the caller's default profile, remove it from _defaultProfileIdByAddress mapping
            if (_defaultProfileIdByAddress[msg.sender] == tokenId) {
                delete _defaultProfileIdByAddress[msg.sender];
            }
        }

        // Remove the token from _tokenById mapping
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
        // If token visibility is off and the caller is not the owner, revert
        if (
            ownerOf(tokenId) != msg.sender &&
            _tokenById[tokenId].visibility == DataTypes.Visibility.OFF
        ) revert("Forbidden");

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
