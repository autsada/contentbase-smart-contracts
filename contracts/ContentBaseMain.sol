// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./ContentBaseProfile.sol";
import {Constants} from "../libraries/Constants.sol";
import {Helpers} from "../libraries/Helpers.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

contract ContentBase is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ContentBaseProfile
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    // Array of profile ids by address.
    mapping(address => uint256[]) private _profileIdsByAddress;
    // Profile id by handle hash.
    mapping(bytes32 => uint256) private _profileIdByHandleHash;
    // Profile struct by profile id.
    mapping(uint256 => DataTypes.Profile) private _profileById;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("Content Base", "CTB");
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
     * A public function to create profile nft
     * @param createProfileParams {struct} - refer to DataTypes.CreateProfileParams struct
     *
     */
    function createProfile(
        DataTypes.CreateProfileParams calldata createProfileParams
    ) public override returns (uint256) {
        // Validate handle length, the helper function will revert with error message if the check is false so we don't have to set the error message here
        require(Helpers.onlyValidHandleLen(createProfileParams.handle));

        // Check if handle is already taken
        require(
            Helpers.handleUnique(
                createProfileParams.handle,
                _profileIdByHandleHash
            ),
            "Handle already taken."
        );

        // Validate tokenURI and imageURI, the helper function will revert with error message if the check is false so we don't have to set the error message here.
        // An imageURI can be empty so we don't have to validate min length
        require(Helpers.notTooShortURI(createProfileParams.tokenURI));
        require(Helpers.notTooLongURI(createProfileParams.tokenURI));
        require(Helpers.notTooLongURI(createProfileParams.imageURI));

        // Mint new token
        uint256 newProfileId = safeMint(msg.sender);

        return
            _createProfile({
                owner: msg.sender,
                profileId: newProfileId,
                createProfileParams: createProfileParams,
                _profileIdsByAddress: _profileIdsByAddress,
                _profileIdByHandleHash: _profileIdByHandleHash,
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
     * A public function to update profile image
     * @param profileId {uint256} - An id of the profile to be updated
     * @param updateProfileParams {struct} - refer to DataTypes.UpdateProfileParams
     */
    function updateProfileImage(
        uint256 profileId,
        DataTypes.UpdateProfileParams calldata updateProfileParams
    ) public override returns (uint256) {
        // Check if the caller is the owner of the profile
        require(ownerOf(profileId) == msg.sender, "Forbidden");

        // Check if the profile id exist
        require(_exists(profileId), "Profile not found");

        // Valdate the parameters
        require(Helpers.notTooShortURI(updateProfileParams.tokenURI));
        require(Helpers.notTooLongURI(updateProfileParams.tokenURI));
        require(Helpers.notTooShortURI(updateProfileParams.imageURI));
        require(Helpers.notTooLongURI(updateProfileParams.imageURI));

        return
            _updateProfileImage(
                msg.sender,
                profileId,
                updateProfileParams,
                _profileById
            );
    }

    /// ***********************
    /// ***** Over all Logic *****
    /// ***********************

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
        if (from != address(0) || to != address(0)) {
            require(
                (msg.sender == ownerOf(tokenId)) &&
                    (msg.sender == from) &&
                    (msg.sender == to),
                "Token is non-transferable"
            );
        }

        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * A private function to perform minting logic
     * @param to {address} = An address to mint the token to
     */
    function safeMint(address to) private returns (uint256) {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(to, tokenId);

        return tokenId;
    }

    function burn(uint256 tokenId) public override {
        // Token must exist.
        require(_exists(tokenId), "Token not found");

        // Find an owner.
        address owner = ownerOf(tokenId);

        // If the token is a profile token, delete the token id (the profile id) from owner's profileIds array.
        DataTypes.Profile memory profile = _profileById[tokenId];
        if (profile.owner == owner && profile.profileId == tokenId) {
            // This case means the token is a profile token.
            // Find profile ids array of the owner and update it.
            uint256[] memory profileIds = _profileIdsByAddress[owner];

            if (profileIds.length > 0) {
                uint256[] memory updatedProfileIds;
                uint256 index = 0;
                for (uint256 i = 0; i < profileIds.length; i++) {
                    if (profileIds[i] != tokenId) {
                        // Keep only the id that doesn't equal tokenId.
                        updatedProfileIds[index] = profileIds[i];
                        index++;
                    }
                }

                _profileIdsByAddress[owner] = updatedProfileIds;
            }
        } else {}

        // Call the parent burn function.
        super.burn(tokenId);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {
        _grantRole(UPGRADER_ROLE, newImplementation);
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
