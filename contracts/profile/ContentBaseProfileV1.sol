// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";

import {IContentBaseProfileV1} from "./IContentBaseProfileV1.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Helpers} from "../libraries/Helpers.sol";

/**
 * @title ContentBaseProfileV1
 * @author Autsada T
 *
 * @notice An address (EOA) can mint as many profile NFTs as they want as long as they provide a unique handle.
 * @notice The profile NFTs are non-burnable.
 */

contract ContentBaseProfileV1 is
    Initializable,
    ERC721Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IContentBaseProfileV1
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Mapping (tokenId => profile struct).
    mapping(uint256 => DataTypes.Profile) private _tokenIdToProfile;
    // Mapping (hash => profile id) of handle hash to profile id.
    mapping(bytes32 => uint256) private _handleHashToProfileId;
    // Mapping (owner => profile id) of owner to their default profile id.
    mapping(address => uint256) private _ownerToDefaultProfileId;

    // Events
    event ProfileCreated(
        uint256 indexed profileId,
        address indexed owner,
        string handle,
        string imageURI,
        string originalHandle,
        bool isDefault,
        uint256 timestamp
    );
    event ProfileImageUpdated(
        uint256 indexed profileId,
        string imageURI,
        uint256 timestamp
    );
    event DefaultProfileUpdated(
        uint256 indexed newProfileId,
        uint256 indexed oldProfileId,
        uint256 timestamp
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * Initialize function.
     */
    function initialize() public initializer {
        __ERC721_init("ContentBase PROFILE", "CTB");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    /**
     * A modifier to check if the caller own the token.
     * @dev Extract code inside the modifier to a private function to reduce contract size.
     */
    function _onlyTokenOwner(uint256 tokenId) private view {
        require(_exists(tokenId), "Token not found");
        require(ownerOf(tokenId) == msg.sender, "Forbidden");
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        _onlyTokenOwner(tokenId);
        _;
    }

    /**
     * @inheritdoc IContentBaseProfileV1
     */
    function createProfile(
        string calldata handle,
        string calldata imageURI,
        string calldata originalHandle
    ) external override {
        // Validate handle length and special characters, the helper function will revert with an error message if the check failed so we don't have to set the error message here.
        require(Helpers.validateHandle(handle));

        // Require handle to be unique, the helper function will revert with an error message if the check failed.
        require(Helpers.handleUnique(handle, _handleHashToProfileId));

        // The imageURI can be empty so we don't have to validate min length.
        Helpers.notTooLongURI(imageURI);

        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint an NFT to the caller.
        _safeMint(msg.sender, tokenId);

        // Update handle hash to profile id mapping.
        _handleHashToProfileId[Helpers.hashHandle(handle)] = tokenId;

        // Set the default profile if not already.
        if (_ownerToDefaultProfileId[msg.sender] == 0) {
            _ownerToDefaultProfileId[msg.sender] = tokenId;
        }

        // Create a new profile struct and store it in the state.
        _tokenIdToProfile[tokenId] = DataTypes.Profile({
            owner: msg.sender,
            handle: handle,
            imageURI: imageURI
        });

        // Emit a profile created event.
        emit ProfileCreated(
            tokenId,
            msg.sender,
            handle,
            imageURI,
            originalHandle,
            _ownerToDefaultProfileId[msg.sender] == tokenId,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBaseProfileV1
     */
    function updateProfileImage(
        uint256 tokenId,
        string calldata newImageURI
    ) external override onlyTokenOwner(tokenId) {
        // Validate the image uri.
        Helpers.notTooShortURI(newImageURI);
        Helpers.notTooLongURI(newImageURI);

        // Compare existing image uri to the new uri.
        require(
            keccak256(abi.encodePacked(newImageURI)) !=
                keccak256(
                    abi.encodePacked(_tokenIdToProfile[tokenId].imageURI)
                ),
            "No change"
        );

        // Update the profile struct.
        _tokenIdToProfile[tokenId].imageURI = newImageURI;

        // Emit an event.
        emit ProfileImageUpdated(tokenId, newImageURI, block.timestamp);
    }

    /**
     * @inheritdoc IContentBaseProfileV1
     */
    function setDefaultProfile(string calldata handle) external override {
        // Get a profile id by the given handle.
        uint256 profileId = _handleHashToProfileId[Helpers.hashHandle(handle)];
        require(_exists(profileId), "Profile not found");

        // The caller must own the token.
        require(ownerOf(profileId) == msg.sender, "Forbidden");

        // The found token must not already the default.
        require(
            _ownerToDefaultProfileId[msg.sender] != profileId,
            "Already the default"
        );

        // Get the existing default profile id.
        uint256 oldProfileId = _ownerToDefaultProfileId[msg.sender];

        // Update the default profile mapping to the new profile.
        _ownerToDefaultProfileId[msg.sender] = profileId;

        // Emit a set default profile event.
        emit DefaultProfileUpdated(profileId, oldProfileId, block.timestamp);
    }

    /**
     * @inheritdoc IContentBaseProfileV1
     */
    function validateHandle(
        string calldata handle
    ) external view override returns (bool) {
        return
            Helpers.handleUnique(handle, _handleHashToProfileId) &&
            Helpers.validateHandle(handle);
    }

    /**
     * @inheritdoc IContentBaseProfileV1
     */
    function getDefaultProfile()
        external
        view
        override
        returns (uint256, DataTypes.Profile memory)
    {
        require(
            _ownerToDefaultProfileId[msg.sender] != 0,
            "Default profile not set"
        );
        uint256 profileId = _ownerToDefaultProfileId[msg.sender];

        return (profileId, _tokenIdToProfile[profileId]);
    }

    /**
     * @inheritdoc IContentBaseProfileV1
     */
    function profileExist(
        uint256 profileId
    ) external view override returns (bool) {
        return _exists(profileId);
    }

    /**
     * @inheritdoc IContentBaseProfileV1
     */
    function profileOwner(
        uint256 profileId
    ) external view override returns (address) {
        require(_exists(profileId), "Profile not found");
        return ownerOf(profileId);
    }

    /**
     * Return the profile's imageURI.
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return _tokenIdToProfile[tokenId].imageURI;
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
        require(from == address(0) || to == address(0), "Non transferable");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    // The following functions are overrides required by Solidity.

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
