// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";

import {Constants} from "../libraries/Constants.sol";

contract ContentBaseProfile is
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
     * @dev  profileId - a token id
     * @dev  owner - an address who owns the token
     * @dev uid - a database user id or wallet address
     * @dev handle - a user given name which must be unique
     * @dev imageURI - a uri for use as a profile's image
     * @dev isDefault - boolean if the owner want a profile be their default profile
     */
    struct Profile {
        uint256 profileId;
        address owner;
        string uid;
        string handle;
        string imageURI;
        bool isDefault;
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
    modifier _onlyValidImageURI(string calldata imageURI) {
        bytes memory bytesURI = bytes(imageURI);
        if (Constants.MAX_PROFILE_IMAGE_URI_LENGTH >= bytesURI.length) {
            _;
        } else {
            revert("Image uri is too long.");
        }
    }

    /**
     * @notice createProfileByAdmin can only be called by an admin (on behalf of users who use built in wallets)
     */
    function createProfileByAdmin(
        address profileOwnerAddress,
        string memory uid,
        string calldata handle,
        string calldata imageURI,
        bool isDefault
    )
        external
        onlyRole(ADMIN_ROLE)
        _onlyValidHandleLen(handle)
        _onlyValidImageURI(imageURI)
        returns (uint256)
    {
        return
            _createProfile({
                owner: profileOwnerAddress,
                uid: uid,
                handle: handle,
                imageURI: imageURI,
                isDefault: isDefault
            });
    }

    /**
     * @notice createProfile can be called by users directly when they use their own wallet
     */
    function createProfile(
        string memory uid,
        string calldata handle,
        string calldata imageURI,
        bool isDefault
    )
        external
        _onlyValidHandleLen(handle)
        _onlyValidImageURI(imageURI)
        returns (uint256)
    {
        require(!hasRole(ADMIN_ROLE, msg.sender), "Not for admin");

        return
            _createProfile({
                owner: msg.sender,
                uid: uid,
                handle: handle,
                imageURI: imageURI,
                isDefault: isDefault
            });
    }

    /**
     * @notice a function that actually contains logic to create a profile.
     *
     * @param owner - a wallet address of the owner of a profile.
     * @param uid - if using the built-in wallet it's a uid from external database, if using user own wallet it's an address.
     * @param handle - a user given name of the profile
     * @param imageURI - a uri for use as a profile's image
     * @param isDefault - if the profile is a default profile of the user.
     */
    function _createProfile(
        address owner,
        string memory uid,
        string memory handle,
        string memory imageURI,
        bool isDefault
    ) internal returns (uint256) {
        // Check if handle is already taken
        require(_handleUnique(handle), "Handle already taken.");

        _profileIdCounter.increment();
        uint256 newProfileId = _profileIdCounter.current();

        // Mint new token
        _safeMint(owner, newProfileId);

        // Push the profile id to user's profile ids array
        _profileIdsByAddress[owner].push(newProfileId);

        // Link profile id to handle hash
        _profileIdByHandleHash[_hashHandle(handle)] = newProfileId;

        // Create a profile struct and assign it to the newProfileId in the mapping.
        _profileById[newProfileId] = Profile({
            profileId: newProfileId,
            owner: owner,
            uid: uid,
            handle: handle,
            imageURI: imageURI,
            isDefault: isDefault
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
     */
    function validateHandle(string calldata handle)
        external
        view
        _onlyValidHandleLen(handle)
        returns (bool)
    {
        return _handleUnique(handle);
    }

    // A function to check if handle is unique
    function _handleUnique(string memory handle) internal view returns (bool) {
        return _profileIdByHandleHash[_hashHandle(handle)] == 0;
    }

    // A function to hash a handle
    function _hashHandle(string memory handle) internal pure returns (bytes32) {
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
