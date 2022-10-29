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
import {Constants} from "../../libraries/Constants.sol";
import {Helpers} from "../../libraries/Helpers.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

/**
 * @title Follow NFT
 * This NFT will be minted when a profile follow other profile.
 * "follow" and "burn" (unFollow) only accept calls from the Profile contract.
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

    // Profile contract address.
    address public profileContractAddress;

    // Mapping of follow struct by token id.
    mapping(uint256 => DataTypes.Follow) private _tokenById;
    // Mapping (profileId => (profileId => boolean)) to track if a specific profile is following another profile, (1 => (2 => true)) means profile id 1 has been following profile id 2.
    mapping(uint256 => mapping(uint256 => bool)) private _followsList;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("Content Base Publish", "CBPu");
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
     * @dev see IFollowNFT - setProfileContractAddress
     */
    function setProfileContractAddress(address profileAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        profileContractAddress = profileAddress;
    }

    /**
     * @dev see IFollowNFT - follow
     */
    function follow(address owner, DataTypes.FollowData calldata followData)
        external
        override
        returns (bool, uint256)
    {
        // Only accept a call from the profile contract.
        require(msg.sender == profileContractAddress, "Forbidden");

        // Require the follower not already followed the followee.
        require(
            !_followsList[followData.followerId][followData.followeeId],
            "Already follow"
        );

        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint an NFT to the caller.
        _safeMint(owner, tokenId);

        // Create and store a follow struct in the mapping.
        _tokenById[tokenId] = DataTypes.Follow({
            owner: owner,
            followerId: followData.followerId,
            followeeId: followData.followeeId
        });

        // Update the follows list mapping.
        _followsList[followData.followerId][followData.followeeId] = true;

        return (true, tokenId);
    }

    /**
     * @dev see IFollowNFT - burn
     */
    function burn(
        uint256 tokenId,
        address owner,
        uint256 followerId
    ) external override returns (bool, uint256) {
        // Only accept a call from the profile contract.
        require(msg.sender == profileContractAddress, "Forbidden");

        // Follow must exist.
        require(_exists(tokenId), "Follow not found");

        // The caller must be the owner of the follow.
        require(owner == ownerOf(tokenId), "Forbidden");

        // Get the token.
        DataTypes.Follow memory token = _tokenById[tokenId];

        // The follow must belong to the follower.
        require(token.followerId == followerId, "Not allow");

        // Call the parent burn function.
        super.burn(tokenId);

        // Update the follows list mapping.
        _followsList[followerId][token.followeeId] = false;

        // Remove the struct from the mapping.
        delete _tokenById[tokenId];

        return (true, token.followeeId);
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
