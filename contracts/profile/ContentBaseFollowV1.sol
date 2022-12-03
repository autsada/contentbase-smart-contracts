// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";

import {IContentBaseFollowV1} from "./IContentBaseFollowV1.sol";
import {IContentBaseProfileV1} from "./IContentBaseProfileV1.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Helpers} from "../libraries/Helpers.sol";

/**
 * @title ContentBaseFollowV1
 * @author Autsada T
 *
 * @notice A follow NFT will be minted to a profile NFT owner when they use their profile to follow another profile, and the given follow NFT will be burned when they unfollow.
 * @notice The follow NFTs are non-burnable.
 */

contract ContentBaseFollowV1 is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IContentBaseFollowV1
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // A private state to store the profile contract address.
    address private _profileContractAddress;
    // A mapping (profile id => (followee id => follow token id)) to track the following profiles of a profile.
    mapping(uint256 => mapping(uint256 => uint256))
        private _profileIdToFolloweeIdToTokenId;
    // A mapping (profile id => (follower id => follow token id)) to track the follower profiles of a profile.
    mapping(uint256 => mapping(uint256 => uint256))
        private _profileIdToFollowerIdToTokenId;
    // A mapping (profile id => following) to track profile's following count.
    mapping(uint256 => uint32) private _profileIdToFollowingCount;
    // A mapping (profile id => followers) to track profile's followers count.
    mapping(uint256 => uint32) private _profileIdToFollowersCount;

    // Events
    event Following(
        uint256 indexed tokenId,
        uint256 indexed followerId,
        uint256 followeeId,
        uint256 timestamp
    );
    event UnFollowing(uint256 indexed tokenId, uint256 timestamp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * Initialize function.
     */
    function initialize(address profileContractAddress) public initializer {
        __ERC721_init("ContentBase Follow", "CTBF");
        __ERC721Burnable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        _profileContractAddress = profileContractAddress;
    }

    /**
     * A modifier to check if the contract is ready.
     */
    function _onlyReady() private view {
        // The profile contract address must be set.
        require(_profileContractAddress != address(0), "Not ready");
    }

    modifier onlyReady() {
        _onlyReady();
        _;
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
     * A modifier to check if the caller owns a given profile (and also check if the given profile id exists).
     * @dev Extract code inside the modifier to a private function to reduce contract size.
     */
    function _onlyProfileOwner(uint256 profileId) private view {
        address owner = IContentBaseProfileV1(_profileContractAddress)
            .profileOwner(profileId);
        require(msg.sender == owner, "Not a profile owner");
    }

    modifier onlyProfileOwner(uint256 profileId) {
        _onlyProfileOwner(profileId);
        _;
    }

    /**
     * @inheritdoc IContentBaseFollowV1
     */
    function updateProfileContract(address newContractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        _profileContractAddress = newContractAddress;
    }

    /**
     * @inheritdoc IContentBaseFollowV1
     */
    function getProfileContract() external view override returns (address) {
        return _profileContractAddress;
    }

    /**
     * @inheritdoc IContentBaseFollowV1
     */
    function follow(uint256 followerId, uint256 followeeId)
        external
        override
        onlyReady
        onlyProfileOwner(followerId)
    {
        // A profile cannot follow itself.
        require(followerId != followeeId, "Not allow");

        // Get the Follow token id (if exist).
        uint256 followTokenId = _profileIdToFolloweeIdToTokenId[followerId][
            followeeId
        ];

        // Check to identify if the call is for `follow` or `unfollow`.
        if (followTokenId == 0) {
            // FOLLOW --> mint a new Follow NFT to the caller.

            // Increment the counter before using it so the id will start from 1 (instead of 0).
            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();

            // Mint a follow NFT to the caller (the owner (EOA) of the follower profile).
            _safeMint(msg.sender, tokenId);

            // Update the profile to followee mapping of the follower profile.
            _profileIdToFolloweeIdToTokenId[followerId][followeeId] = tokenId;
            // Update the profile to follower mapping of the followee profile.
            _profileIdToFollowerIdToTokenId[followeeId][followerId] = tokenId;

            // Update the follower's following count.
            _profileIdToFollowingCount[followerId]++;
            // Update the followee's followers count.
            _profileIdToFollowersCount[followeeId]++;

            emit Following(tokenId, followerId, followeeId, block.timestamp);
        } else {
            // UNFOLLOW CASE --> burn the Follow token.

            // Check token ownership.
            require(ownerOf(followTokenId) == msg.sender, "Forbidden");

            // Burn the token.
            super.burn(followTokenId);

            // Update the profile to followee mapping of the follower profile;
            _profileIdToFolloweeIdToTokenId[followerId][followeeId] = 0;
            // Update the profile to follower mapping of the followee profile;
            _profileIdToFollowerIdToTokenId[followeeId][followerId] = 0;

            // Update the follower's following count.
            if (_profileIdToFollowingCount[followerId] > 0) {
                _profileIdToFollowingCount[followerId]--;
            }
            // Update the followee's followers count.
            if (_profileIdToFollowersCount[followeeId] > 0) {
                _profileIdToFollowersCount[followeeId]--;
            }

            emit UnFollowing(followTokenId, block.timestamp);
        }
    }

    /**
     * @inheritdoc IContentBaseFollowV1
     */
    function getFollowCounts(uint256 profileId)
        external
        view
        override
        returns (uint256, uint256)
    {
        // The given profile must exist.
        require(
            IContentBaseProfileV1(_profileContractAddress).profileExist(
                profileId
            ),
            "Profile not found"
        );

        return (
            _profileIdToFollowersCount[profileId],
            _profileIdToFollowingCount[profileId]
        );
    }

    /**
     * Override the parent burn function.
     * @dev use the `follow` function to burn (unfollow) the token.
     */
    function burn(uint256 tokenId)
        public
        view
        override
        onlyTokenOwner(tokenId)
    {
        revert("Use the `follow` function");
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
