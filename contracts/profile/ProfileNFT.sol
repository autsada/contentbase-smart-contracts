// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";
import "./IFollowNFT.sol";
import "./IProfileNFT.sol";
import {Constants} from "../../libraries/Constants.sol";
import {Helpers} from "../../libraries/Helpers.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

/**
 * @title ProfileNFT
 * @notice This is non-burnable NFT.
 * @notice An address can create as many profile as they want.
 */

contract ProfileNFT is
    Initializable,
    ERC721Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IProfileNFT
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    // Follow contract address.
    address public followContractAddress;

    // Mapping of token id by handle hash.
    mapping(bytes32 => uint256) private _tokenIdByHandleHash;
    // Mapping to track user's default profile.
    mapping(address => uint256) private _defaultProfileByAddress;
    // Mapping of profile struct by token id.
    mapping(uint256 => DataTypes.Profile) private _tokenById;

    // Events
    event ProfileCreated(
        uint256 indexed tokenId,
        address indexed owner,
        string handle,
        string imageURI,
        bool isDefault
    );
    event ProfileImageUpdated(
        uint256 tokenId,
        address owner,
        string handle,
        string imageURI
    );
    event DefaultProfileUpdated(uint256 tokenId, address owner);
    event Follow(
        uint256 indexed followerId,
        uint256 indexed followeeId,
        address ownerAddress,
        address followeeAddress
    );
    event UnFollow(uint256 followerId, uint256 followeeId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("Content Base Profile", "CBPr");
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
     * @dev see IProfileNFT - setFollowContractAddress
     */
    function setFollowContractAddress(address followAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        followContractAddress = followAddress;
    }

    /**
     * @dev see IProfileNFT - createProfile
     */
    function createProfile(
        DataTypes.CreateProfileData calldata createProfileData
    ) external override returns (uint256) {
        // Validate handle length and special characters, the helper function will revert with an error message if the check failed so we don't have to set the error message here.
        require(Helpers.validateHandle(createProfileData.handle));

        // Require handle to be unique, the helper function will revert with an error message if the check failed.
        require(
            Helpers.handleUnique(createProfileData.handle, _tokenIdByHandleHash)
        );

        // The imageURI can be empty so we don't have to validate min length.
        require(Helpers.notTooLongURI(createProfileData.imageURI));

        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint an NFT to the caller.
        _safeMint(msg.sender, tokenId);

        // Update the handle hash mapping.
        _tokenIdByHandleHash[
            Helpers.hashHandle(createProfileData.handle)
        ] = tokenId;

        // Update the profile struct mapping.
        DataTypes.Profile memory newToken = DataTypes.Profile({
            owner: msg.sender,
            following: 0,
            followers: 0,
            handle: createProfileData.handle,
            imageURI: createProfileData.imageURI
        });
        _tokenById[tokenId] = newToken;

        // If user doesn't have a default profile yet, set this new token as their default profile.
        if (_defaultProfileByAddress[msg.sender] == 0) {
            _setDefaultProfile(msg.sender, tokenId);
        }

        // Emit create profile event.
        emit ProfileCreated(
            tokenId,
            msg.sender,
            createProfileData.handle,
            createProfileData.imageURI,
            _defaultProfileByAddress[msg.sender] == tokenId
        );

        return tokenId;
    }

    /**
     * @dev see IProfileNFT - updateProfileImage
     */
    function updateProfileImage(
        DataTypes.UpdateProfileImageData calldata updateProfileImageData
    ) external override returns (uint256) {
        // The token id must exist.
        require(_exists(updateProfileImageData.tokenId), "Not found");

        // Only a profile owner can update their profile image.
        require(
            ownerOf(updateProfileImageData.tokenId) == msg.sender,
            "Forbidden"
        );

        // Validate the image uri.
        require(Helpers.notTooShortURI(updateProfileImageData.imageURI));
        require(Helpers.notTooLongURI(updateProfileImageData.imageURI));

        // Get the profile struct.
        DataTypes.Profile memory profile = _tokenById[
            updateProfileImageData.tokenId
        ];

        // Image uri must changed.
        require(
            keccak256(abi.encodePacked(updateProfileImageData.imageURI)) !=
                keccak256(abi.encodePacked(profile.imageURI)),
            "No change"
        );

        uint256 tokenId = updateProfileImageData.tokenId;

        // Update the profile struct.
        _tokenById[tokenId].imageURI = updateProfileImageData.imageURI;

        // Emit update profile event.
        emit ProfileImageUpdated(
            tokenId,
            msg.sender,
            profile.handle,
            updateProfileImageData.imageURI
        );

        return tokenId;
    }

    /**
     * @dev see IProfileNFT - setDefaultProfile
     */
    function setDefaultProfile(uint256 tokenId) external override {
        // The profile id must exist.
        require(_exists(tokenId), "Profile not found");

        // The Caller must own the profile.
        require(ownerOf(tokenId) == msg.sender, "Forbidden");

        // If the id is already a default, revert
        if (_defaultProfileByAddress[msg.sender] == tokenId)
            revert("Already a default");

        _setDefaultProfile({owner: msg.sender, tokenId: tokenId});

        emit DefaultProfileUpdated(tokenId, msg.sender);
    }

    /**
     * A private function that contain the logic to set default profile.
     * @dev validations will be done by caller function.
     * @param owner {address}
     * @param tokenId {uint256}
     */
    function _setDefaultProfile(address owner, uint256 tokenId) private {
        // Update the mapping
        _defaultProfileByAddress[owner] = tokenId;
    }

    /**
     * @dev see IProfileNFT - follow
     */
    function follow(DataTypes.FollowData calldata followData)
        external
        override
        returns (bool, uint256)
    {
        // Follow contract address must be set.
        require(followContractAddress != address(0), "Not ready");

        // The follower must exist.
        require(_exists(followData.followerId), "Follower not found");

        // The caller must own the follower profile.
        require(msg.sender == ownerOf(followData.followerId), "Forbidden");

        // The followee must exist.
        require(_exists(followData.followeeId), "Followee not found");

        // The profile cannot follow themselve.
        require(followData.followerId != followData.followeeId, "Not allow");

        // Call the follow contract to create a follow NFT.
        (bool success, uint256 tokenId) = IFollowNFT(followContractAddress)
            .follow(msg.sender, followData);

        require(success, "Follow failed");

        // Increase the follower's following count.
        _tokenById[followData.followerId].following++;

        // Increase the followee's followers count.
        _tokenById[followData.followeeId].followers++;

        emit Follow(
            followData.followerId,
            followData.followeeId,
            msg.sender,
            ownerOf(followData.followeeId)
        );

        return (true, tokenId);
    }

    /**
     * @dev see IProfileNFT - unFollow
     */
    function unFollow(uint256 tokenId, uint256 followerId)
        external
        override
        returns (bool)
    {
        // Follow contract address must be set.
        require(followContractAddress != address(0), "Not ready");

        // The follower must exist.
        require(_exists(followerId), "Follower not found");

        // The caller must own the follower profile.
        require(msg.sender == ownerOf(followerId), "Forbidden");

        // Call the follow contract to unfollow.
        // The follow's burn returns 2 values, the second one is the followee id.
        (bool success, uint256 followeeId) = IFollowNFT(followContractAddress)
            .burn(tokenId, msg.sender, followerId);

        require(success, "Unfollow failed");

        // Decrease the follower's following count.
        // Before updating, make sure the count is greater than 0.
        if (_tokenById[followerId].following > 0) {
            _tokenById[followerId].following--;
        }

        // Decrease the followee's followers count.
        // Before updating, make sure the count is greater than 0.
        if (_tokenById[followeeId].followers > 0) {
            _tokenById[followeeId].followers--;
        }

        emit UnFollow(followerId, followeeId);

        return true;
    }

    /**
     * @dev see IProfileNFT - getDefaultProfile
     */
    function getDefaultProfile()
        external
        view
        override
        returns (DataTypes.Profile memory)
    {
        uint256 tokenId = _defaultProfileByAddress[msg.sender];

        require(tokenId != 0, "Default profile not set");

        // Profile must exist.
        require(_exists(tokenId), "Profile invalid");

        return _tokenById[tokenId];
    }

    /**
     * @dev see IProfileNFT - getProfile
     */
    function getProfile(uint256 tokenId)
        external
        view
        override
        returns (DataTypes.Profile memory)
    {
        require(_exists(tokenId), "Profile not found");

        return _tokenById[tokenId];
    }

    /**
     * @dev see IProfileNFT - totalProfiles
     */
    function totalProfiles() external view override returns (uint256) {
        return _tokenIdCounter.current();
    }

    /**
     * @dev see IProfileNFT - ownerOfProfile
     */
    function ownerOfProfile(uint256 tokenId)
        external
        view
        override
        returns (address)
    {
        // Profile must exist.
        require(_exists(tokenId), "Profile not found");

        return ownerOf(tokenId);
    }

    /**
     * @dev see IProfileNFT - exists
     */
    function exists(uint256 tokenId) external view override returns (bool) {
        return _exists(tokenId);
    }

    /**
     * @dev see IProfileNFT - validateHandle
     */
    function validateHandle(string calldata handle)
        external
        view
        override
        returns (bool)
    {
        return
            Helpers.handleUnique(handle, _tokenIdByHandleHash) &&
            Helpers.validateHandle(handle);
    }

    /**
     * @notice If it's not the first creation, the token is non-transferable.
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
