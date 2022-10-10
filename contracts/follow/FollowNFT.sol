// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
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
 * @dev frontend needs to track token ids own by each address so it can query tokens for each address.
 */

contract FollowNFT is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
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
    mapping(uint256 => DataTypes.FollowStruct) private _tokenById;
    // Mapping of how many profiles follow a specific profile id.
    mapping(uint256 => uint256) private _followerCountByProfileId;
    // Mapping of how many profiles that a specific profile id follows.
    mapping(uint256 => uint256) private _followingCountByProfileId;

    // Events
    event FollowCreated(DataTypes.FollowStruct token, address owner);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("Content Base Follow", "CBF");
        __ERC721URIStorage_init();
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
        // Follower id and following must exist
        require(
            _profileContract.exists(createFollowData.followerId) &&
                _profileContract.exists(createFollowData.followingId),
            "Bad request"
        );

        // Caller must own the follower id.
        require(
            msg.sender ==
                _profileContract.ownerOfProfile(createFollowData.followerId),
            "Forbidden"
        );

        // Follower id must not equal following id
        require(
            createFollowData.followerId != createFollowData.followingId,
            "Bad input"
        );

        // Validate tokenURI.
        require(Helpers.notTooShortURI(createFollowData.tokenURI));
        require(Helpers.notTooLongURI(createFollowData.tokenURI));

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

        // Update tokenURI.
        _setTokenURI(tokenId, createFollowData.tokenURI);

        // Update _tokenById mapping.
        DataTypes.FollowStruct memory newToken = DataTypes.FollowStruct({
            tokenId: tokenId,
            followerId: createFollowData.followerId,
            followingId: createFollowData.followingId,
            owner: owner
        });
        _tokenById[tokenId] = newToken;

        // Increase follower count of the following id by 1.
        _followerCountByProfileId[createFollowData.followingId]++;

        // Increase following count of the follower id by 1.
        _followingCountByProfileId[createFollowData.followerId]++;

        // Emit publish created event.
        emit FollowCreated(_tokenById[tokenId], owner);

        return tokenId;
    }

    /**
     * @dev see IFollowNFT - unFollow
     */
    function unFollow(uint256 tokenId) external override returns (bool) {
        // Token must exists
        require(_exists(tokenId), "Not found");

        // Caller must own the token
        require(msg.sender == ownerOf(tokenId), "Forbidden");

        // Get token struct
        DataTypes.FollowStruct memory token = _tokenById[tokenId];

        // Decrease follower count of the following id.
        _followerCountByProfileId[token.followingId]--;

        // Decrease following count of the follower id.
        _followingCountByProfileId[token.followerId]--;

        // Remove the token from _tokenById mapping.
        delete _tokenById[tokenId];

        // Call the parent burn function.
        super.burn(tokenId);

        return true;
    }

    /**
     * @dev see IFollowNFT - followerByProfile
     */
    function followerByProfile(uint256 profileId)
        external
        view
        override
        returns (uint256)
    {
        // Profile id must exist.
        require(_profileContract.exists(profileId), "Profile not found");

        return _followerCountByProfileId[profileId];
    }

    /**
     * @dev see IFollowNFT - followingByProfile
     */
    function followingByProfile(uint256 profileId)
        external
        view
        override
        returns (uint256)
    {
        // Profile id must exist.
        require(_profileContract.exists(profileId), "Profile not found");

        return _followingCountByProfileId[profileId];
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

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
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
