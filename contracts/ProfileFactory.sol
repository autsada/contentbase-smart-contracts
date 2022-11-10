// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "hardhat/console.sol";

import "./IProfileFactory.sol";
import "./Profile.sol";
import "./IProfile.sol";
import {Helpers} from "../libraries/Helpers.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Events} from "../libraries/Events.sol";

/**
 * @title ContentBase Factory
 * @notice This contract will deploy a proxy of ContentBase Profile.
 *
 */
contract ContentBaseProfileFactory is
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IContentBaseProfileFactory
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // The ContentBase owner address.
    address public platform;
    // The beacon address that holds the implementation contract address of ContentBase Profile.
    address public profileBeacon;
    // Mapping (profile => owner) of proxy profile contract addrss to owner.
    mapping(address => address) private _profileToOwner;
    // Mapping (hash => profile) of handle hash to proxy profile contract address.
    mapping(bytes32 => address) private _handleHashToProfile;
    // Mapping (owner => profile) of owner to their default profile address.
    mapping(address => address) private _ownerToDefaultProfile;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _profileBeacon) public initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(UPGRADER_ROLE, ADMIN_ROLE);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        platform = msg.sender;
        profileBeacon = address(_profileBeacon);
    }

    /**
     * @dev The modifier that check if the factory contract is ready, which means `platform`, `profileBeacon` states are all set.
     */
    modifier onlyReady() {
        // The platform address must be set.
        require(platform != address(0), "Not ready");
        // The profile and publish beacon addresses must be set.
        require(profileBeacon != address(0), "Not ready");

        _;
    }

    /**
     * @inheritdoc IContentBaseProfileFactory
     */
    function createProfile(
        DataTypes.CreateProfileData calldata createProfileData
    ) external override onlyReady {
        // Validate handle length and special characters, the helper function will revert with an error message if the check failed so we don't have to set the error message here.
        require(Helpers.validateHandle(createProfileData.handle));

        // Require handle to be unique, the helper function will revert with an error message if the check failed.
        require(
            Helpers.handleUnique(createProfileData.handle, _handleHashToProfile)
        );

        // The imageURI can be empty so we don't have to validate min length.
        require(Helpers.notTooLongURI(createProfileData.imageURI));

        // Create a profile beacon proxy.
        BeaconProxy profileProxy = new BeaconProxy(
            profileBeacon,
            abi.encodeWithSelector(
                ContentBaseProfile.initialize.selector,
                platform, // The platform owner address
                address(this), // The factory address
                msg.sender, // The caller address
                createProfileData
            )
        );
        address profileAddress = address(profileProxy);

        // Update the profileAddress to owner mapping.
        _profileToOwner[profileAddress] = msg.sender;

        // Update the handle hash to profileAddress mapping.
        _handleHashToProfile[
            Helpers.hashHandle(createProfileData.handle)
        ] = profileAddress;

        // Set the default profile if not already.
        if (_ownerToDefaultProfile[msg.sender] == address(0)) {
            _ownerToDefaultProfile[msg.sender] = profileAddress;
        }

        emit Events.ProfileCreated(
            msg.sender,
            profileAddress,
            createProfileData.handle,
            createProfileData.imageURI,
            _ownerToDefaultProfile[msg.sender] == profileAddress,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBaseProfileFactory
     */
    function setDefaultProfile(string calldata handle)
        external
        override
        onlyReady
    {
        // Get a profile address by handle hash.
        address profileAddress = _handleHashToProfile[
            Helpers.hashHandle(handle)
        ];
        require(profileAddress != address(0), "Profile not found");

        // Only the profile owner can set their default.
        require(msg.sender == _profileToOwner[profileAddress], "Unauthorized");

        // Revert if the profile is already the default.
        if (_ownerToDefaultProfile[msg.sender] == profileAddress)
            revert("Already set");

        _ownerToDefaultProfile[msg.sender] = profileAddress;

        emit Events.DefaultProfileUpdated(
            profileAddress,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBaseProfileFactory
     */
    function validateHandle(string calldata handle)
        external
        view
        override
        returns (bool)
    {
        return
            Helpers.handleUnique(handle, _handleHashToProfile) &&
            Helpers.validateHandle(handle);
    }

    /**
     * @inheritdoc IContentBaseProfileFactory
     */
    function getDefaultProfile()
        external
        view
        override
        onlyReady
        returns (DataTypes.Profile memory)
    {
        // Get the profile address of the caller.
        address profile = _ownerToDefaultProfile[msg.sender];

        if (profile == address(0)) revert("Default profile not set");

        // Call the profile to get the profile.
        return IContentBaseProfile(profile).getProfile();
    }

    /**
     * @inheritdoc IContentBaseProfileFactory
     * @notice this function will throw if the profile address is not a ContentBase profile
     * @param profile {address} - a profile address
     * @return ownerAddress {address} - an EOA address that own the given profile
     */
    function getProfileOwner(address profile)
        external
        view
        override
        returns (address)
    {
        require(
            _profileToOwner[profile] != address(0),
            "Not a ContentBase Profile"
        );

        return _profileToOwner[profile];
    }

    function pause() public whenPaused onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() public whenPaused onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
}
