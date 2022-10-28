// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";
import "./IProfileNFT.sol";
import {Constants} from "../../libraries/Constants.sol";
import {Helpers} from "../../libraries/Helpers.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

/**
 * @title ProfileNFT
 * @notice To reduce complexity, this contract is not burnable as profiles own other NFTs so burning a profile will lead to a need to also burn other NFTs that the profile owns which is complex.
 * @dev frontend needs to track token ids own by each address and handle so it can query tokens for each address/handle.
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
    address private _followContractAddress;
    // Mapping of token id by handle hash.
    mapping(bytes32 => uint256) private _tokenIdByHandleHash;
    // Mapping to track user's default profile
    mapping(address => uint256) private _defaultTokenIdByAddress;
    // Mapping of profile struct by token id.
    mapping(uint256 => DataTypes.Profile) private _tokenById;

    // Events
    event ProfileCreated(DataTypes.Profile token, address owner);
    event ProfileImageUpdated(DataTypes.Profile token, address owner);
    event DefaultProfileUpdated(DataTypes.Profile token, address owner);

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
    function setFollowContractAddress(address followContractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        _followContractAddress = followContractAddress;
    }

    /**
     * @dev see IProfileNFT - createProfile
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
     * @param createProfileData {struct} - see DataTypes.CreateProfileData struct
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

        // Update _tokenIdByHandleHash mapping.
        _tokenIdByHandleHash[
            Helpers.hashHandle(createProfileData.handle)
        ] = tokenId;

        // Update _tokenById mapping.
        DataTypes.Profile memory newToken = DataTypes.Profile({
            owner: owner,
            tokenId: tokenId,
            following: 0,
            followers: 0,
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
     * @dev see IProfileNFT - updateProfileImage
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
        require(Helpers.notTooShortURI(updateProfileImageData.imageURI));
        require(Helpers.notTooLongURI(updateProfileImageData.imageURI));

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
     * @param updateProfileImageData - see DataTypes.UpdateProfileImageData
     * @return tokenId
     *
     */
    function _updateProfileImage(
        address owner,
        DataTypes.UpdateProfileImageData calldata updateProfileImageData
    ) internal returns (uint256) {
        uint256 tokenId = updateProfileImageData.tokenId;

        // Update the profile struct.
        _tokenById[tokenId].imageURI = updateProfileImageData.imageURI;

        // Emit update profile event.
        emit ProfileImageUpdated(_tokenById[tokenId], owner);

        return tokenId;
    }

    /**
     * @dev see IProfileNFT - setDefaultProfile
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
     * @dev see IProfileNFT - follow
     */
    function follow(uint256 followerId, uint256 followeeId)
        external
        override
        returns (bool)
    {
        // Validate the caller, it must be the Follow contract.
        require(msg.sender == _followContractAddress, "Forbidden");

        // Increase the following count of the follower.
        _tokenById[followerId].following++;

        // Increase the followers count of the followee.
        _tokenById[followeeId].followers++;

        return true;
    }

    /**
     * @dev see IProfileNFT - follow
     */
    function unFollow(uint256 followerId, uint256 followeeId)
        external
        override
        returns (bool)
    {
        // Validate the caller, it must be the Follow contract.
        require(msg.sender == _followContractAddress, "Forbidden");

        // Decrease the following count of the follower.
        // Make sure the count is greater than 0.
        if (_tokenById[followerId].following > 0) {
            _tokenById[followerId].following--;
        }

        // Decrease the followers count of the followee.
        // Make sure the count is greater than 0.
        if (_tokenById[followeeId].followers > 0) {
            _tokenById[followeeId].followers--;
        }

        return true;
    }

    /**
     * @dev see IProfileNFT - defaultProfile
     */
    function defaultProfile()
        external
        view
        override
        returns (DataTypes.Profile memory)
    {
        uint256 tokenId = _defaultTokenIdByAddress[msg.sender];
        require(tokenId != 0, "Not found");

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

    function _burn(uint256 tokenId) internal override(ERC721Upgradeable) {
        super._burn(tokenId);
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
