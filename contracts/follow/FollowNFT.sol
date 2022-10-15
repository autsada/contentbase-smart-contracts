// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";
import "./IFollowNFT.sol";
import "../profile/IProfileNFT.sol";
import {Constants} from "../../libraries/Constants.sol";
import {Helpers} from "../../libraries/Helpers.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

/**
 * @title FollowNFT
 * @notice An NFT will be minted when a Profile NFT follows other Profile NFT.
 * @notice This contract doesn't need to be URIStorage.
 * @dev frontend needs to track token ids so it can query tokens for each address.
 */

contract FollowNFT is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IFollowNFT
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    // Profile contract.
    IProfileNFT private _profileContract;

    // Mapping of Follow struct by token id.
    mapping(uint256 => DataTypes.Follow) private _tokenById;
    // Mapping that shows following count of a specific profile id.
    mapping(uint256 => uint256) private _followingCountByProfileId;
    // Mapping that shows followers count of a specific profile id.
    mapping(uint256 => uint256) private _followersCountByProfileId;

    // Events
    event Follow(DataTypes.Follow token, address follower, address followee);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("Content Base Follow", "CBF");
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

    /**
     * @dev see IPublishNFT - setProfileContract
     */
    function setProfileContract(address profileContractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        _profileContract = IProfileNFT(profileContractAddress);
    }

    /**
     * @dev see IFollowNFT - follow
     */
    function follow(DataTypes.CreateFollowData calldata createFollowData)
        external
        override
        returns (uint256)
    {
        // Follower's profile id must exist.
        require(
            _profileContract.exists(createFollowData.followerId),
            "Profile not found"
        );

        // Caller must own the follower profile.
        require(
            msg.sender ==
                _profileContract.ownerOfProfile(createFollowData.followerId),
            "Forbidden"
        );

        // Followee profile id must exist.
        require(
            _profileContract.exists(createFollowData.followeeId),
            "Followee profile not found"
        );

        // Follower profile id must not same as followee profile id.
        require(
            createFollowData.followerId != createFollowData.followeeId,
            "Not allow"
        );

        return _follow({owner: msg.sender, createFollowData: createFollowData});
    }

    /**
     * A private function that contains the logic to create Follow NFT.
     * @dev validations will be done by caller function.
     * @param owner {address} - an address to be set as an owner of the NFT
     * @param createFollowData {struct} - see DataTypes.CreateFollowData struct
     * @return tokenId {uint256}
     *
     */
    function _follow(
        address owner,
        DataTypes.CreateFollowData calldata createFollowData
    ) private returns (uint256) {
        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint an NFT to the owner.
        _safeMint(owner, tokenId);

        // Update _tokenById mapping.
        DataTypes.Follow memory newToken = DataTypes.Follow({
            owner: owner,
            tokenId: tokenId,
            followerId: createFollowData.followerId,
            followeeId: createFollowData.followeeId
        });
        _tokenById[tokenId] = newToken;

        // Update following count of the follower.
        _followingCountByProfileId[createFollowData.followerId];
        // Update followers count of the followee.
        _followersCountByProfileId[createFollowData.followeeId];

        // Get the followee's owner.
        address followeeAddress = _profileContract.ownerOfProfile(
            createFollowData.followeeId
        );
        // Emit FollowingCreated event.
        emit Follow(_tokenById[tokenId], owner, followeeAddress);

        return tokenId;
    }

    /**
     * @dev see IFollowNFT - followingCount
     */
    function followingCount(uint256 profileId) external view returns (uint256) {
        // Profile id must exist.
        require(_profileContract.exists(profileId), "Profile not found");

        return _followingCountByProfileId[profileId];
    }

    /**
     * @dev see IFollowNFT - followersCount
     */
    function followersCount(uint256 profileId) external view returns (uint256) {
        // Profile id must exist.
        require(_profileContract.exists(profileId), "Profile not found");

        return _followersCountByProfileId[profileId];
    }

    /**
     * @dev see IFollowNFT - getFollows
     */
    function getFollows(uint256[] calldata tokenIds)
        external
        view
        returns (DataTypes.Follow[] memory)
    {
        // Validate the ids array.
        require(
            tokenIds.length > 0 &&
                tokenIds.length <= Constants.TOKEN_QUERY_LIMIT,
            "Bad input"
        );

        // Get to be created array length first.
        uint256 followsArrayLen;

        // Loop through the given tokenIds array to check each id if it exists.
        for (uint256 i = 0; i < tokenIds.length; ) {
            if (_exists(tokenIds[i])) {
                followsArrayLen++;
            }
            unchecked {
                i++;
            }
        }

        // Revert if no any Follow found.
        if (followsArrayLen == 0) revert("Not found");

        // Create a fix size empty array.
        DataTypes.Follow[] memory follows = new DataTypes.Follow[](
            followsArrayLen
        );
        // Track the array index
        uint256 index;

        // Loop through the given token ids again to find a token for each id and put it in the array.
        for (uint256 i = 0; i < tokenIds.length; ) {
            if (_exists(tokenIds[i])) {
                follows[index] = _tokenById[tokenIds[i]];
                index++;
            }
            unchecked {
                i++;
            }
        }

        return follows;
    }

    /**
     * A public function to burn a token.
     * @dev use this function to unfollow.
     * @param tokenId {number} - a token id to be burned
     */
    function burn(uint256 tokenId) public override {
        // Token must exist.
        require(_exists(tokenId), "Token not found");

        // The caller must be the owner.
        require(msg.sender == ownerOf(tokenId), "Forbidden");

        // Get token struct.
        DataTypes.Follow memory token = _tokenById[tokenId];

        // Update following count of the follower.
        _followingCountByProfileId[token.followerId]--;

        // Update followers count of the follwee.
        _followersCountByProfileId[token.followeeId]--;

        // Clear the token from _tokenById mapping.
        delete _tokenById[tokenId];

        // Call the parent burn function.
        super.burn(tokenId);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    // The following functions are overrides required by Solidity.

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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
