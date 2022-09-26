// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";

import {Constants} from "../libraries/Constants.sol";

contract ContentBaseProfileV3 is
    Initializable,
    ERC721Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    CountersUpgradeable.Counter private _profileIdCounter;
    // array of profile ids by address
    mapping(address => uint256[]) private _profileIdsByAddress;
    // profile id by handle hash
    mapping(bytes32 => uint256) private _profileIdByHandleHash;
    // profile struct by profile id
    mapping(uint256 => Profile) private _profileById;

    /**
     * @dev A struct containing profile nft data.
     * @param  profileId - a token id
     * @param  owner - an address who owns the token
     * @param isDefault - boolean if the owner want a profile be their default profile
     * @param uid - a database user id
     * @param handle - a user given name which must be unique
     * @param tokenURI - a url point to json metadata save on ipfs - metadata = (handle: string, url: string - a url of the image on ipfs)
     * @param imageURI - a url point to an image saved on cloud storage, can be empty string
     */
    struct Profile {
        uint256 profileId;
        address owner;
        bool isDefault;
        string uid;
        string handle;
        string tokenURI;
        string imageURI;
    }

    /**
     * @dev A struct containing the required arguments for the "createProfile" function.
     * @param isDefault - boolean if the owner want a profile be their default profile
     * @param uid - a database user id
     * @param handle - a user given name which must be unique
     * @param tokenURI - a url point to json metadata save on ipfs - metadata = (handle: string, url: string - a url of the image on ipfs)
     * @param imageURI - a url point to an image saved on cloud storage, can be empty string
     */
    struct CreateProfileParams {
        bool isDefault;
        string uid;
        string handle;
        string tokenURI;
        string imageURI;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    event ProfileCreated(uint256 profileId, address owner);

    function initialize() public initializer {
        __ERC721_init("Content Base Profile", "CTB");
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
     * @dev modifier to check if handle has correct length
     */
    modifier _onlyValidHandleLen(string calldata handle) {
        bytes memory bytesHandle = bytes(handle);
        if (
            bytesHandle.length >= Constants.MIN_HANDLE_LENGTH &&
            bytesHandle.length <= Constants.MAX_HANDLE_LENGTH
        ) {
            _;
        } else {
            revert(
                "Handle must be at least 3 and not greater than 25 characters."
            );
        }
    }

    /**
     * @dev modifier to validate image uri
     */
    modifier _onlyValidURI(string calldata imageURI) {
        bytes memory bytesURI = bytes(imageURI);
        if (Constants.MAX_PROFILE_IMAGE_URI_LENGTH >= bytesURI.length) {
            _;
        } else {
            revert("Image uri is too long.");
        }
    }

    /**
     * @dev an external function that users can call to create profiles
     *
     * @param createProfileParams the struct containing required data to create a profile: (uid, handle, tokenURI, imageURI, isDefault) - imageURI can be empty string
     *
     */
    function createProfile(CreateProfileParams calldata createProfileParams)
        external
        _onlyValidHandleLen(createProfileParams.handle)
        _onlyValidURI(createProfileParams.tokenURI)
        _onlyValidURI(createProfileParams.imageURI)
        returns (uint256)
    {
        return
            _createProfile({
                owner: msg.sender,
                createProfileParams: createProfileParams
            });
    }

    /**
     * @dev an internal function that actually contains logic to create a profile.
     * @param createProfileParams the struct containing required data to create a profile: (uid, handle, tokenURI, imageURI, isDefault) - imageURI can be empty string
     *
     */
    function _createProfile(
        address owner,
        CreateProfileParams calldata createProfileParams
    ) internal returns (uint256) {
        // Check if handle is already taken
        require(
            _handleUnique(createProfileParams.handle),
            "Handle already taken."
        );

        _profileIdCounter.increment();
        uint256 newProfileId = _profileIdCounter.current();

        // Mint new token
        _safeMint(owner, newProfileId);

        // Push the profile id to user's profile ids array
        _profileIdsByAddress[owner].push(newProfileId);

        // Link profile id to handle hash
        _profileIdByHandleHash[
            _hashHandle(createProfileParams.handle)
        ] = newProfileId;

        // Create a profile struct and assign it to the newProfileId in the mapping.
        _profileById[newProfileId] = Profile({
            profileId: newProfileId,
            owner: owner,
            isDefault: createProfileParams.isDefault,
            uid: createProfileParams.uid,
            handle: createProfileParams.handle,
            tokenURI: createProfileParams.tokenURI,
            imageURI: createProfileParams.imageURI
        });

        // Emit an event
        emit ProfileCreated(newProfileId, owner);

        return newProfileId;
    }

    function totalProfiles() public view returns (uint256) {
        return _profileIdCounter.current();
    }

    // Function to fetch user's profiles
    function fetchMyProfiles(address owner)
        public
        view
        returns (Profile[] memory)
    {
        // Get the profile ids array of the owner
        uint256[] memory profileIds = _profileIdsByAddress[owner];

        if (profileIds.length == 0) revert("Not found");

        // Create a profiles array in memory with the fix size of ids array length
        Profile[] memory profiles = new Profile[](profileIds.length);

        // Loop through the ids array and get the profile for each id
        for (uint256 i = 0; i < profileIds.length; i++) {
            profiles[i] = _profileById[profileIds[i]];
        }

        return profiles;
    }

    /**
     * @dev A function to validate handle - validate len and uniqueness
     * @param handle a string handle name
     */
    function validateHandle(string calldata handle)
        external
        view
        _onlyValidHandleLen(handle)
        returns (bool)
    {
        return _handleUnique(handle);
    }

    /**
     * @dev A function to check if handle is unique
     * @param handle a string handle name
     */
    function _handleUnique(string calldata handle)
        internal
        view
        returns (bool)
    {
        return _profileIdByHandleHash[_hashHandle(handle)] == 0;
    }

    /**
     * @dev A function to hash the handle
     * @param handle a string handle name
     */
    function _hashHandle(string calldata handle)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(bytes(handle));
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {
        _grantRole(UPGRADER_ROLE, newImplementation);
    }

    /**
     * @notice If it's not the first creation of the token sender must be an owner of the token and is equal to "from" and "to", so token is non-transferable
     *
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721Upgradeable) {
        if (from != address(0)) {
            require(
                (msg.sender == ownerOf(tokenId)) &&
                    (msg.sender == from) &&
                    (msg.sender == to),
                "Profile is non-transferable"
            );
        }

        super._beforeTokenTransfer(from, to, tokenId);
    }

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
