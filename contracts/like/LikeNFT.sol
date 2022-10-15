// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";
import "./ILikeNFT.sol";
import "../profile/IProfileNFT.sol";
import "../publish/IPublishNFT.sol";
import {Constants} from "../../libraries/Constants.sol";
import {Helpers} from "../../libraries/Helpers.sol";
import {DataTypes} from "../../libraries/DataTypes.sol";

/**
 * @title LikeNFT
 * @notice This is the contract that enable profiles to be able to send ethers to other profiles (the creators) when they like their publishes.
 * @notice Like NFT is minted upon like event.
 * @dev frontend needs to track token ids own by each address so it can query tokens for each address.
 */

contract LikeNFT is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ILikeNFT
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    // Profile contract.
    IProfileNFT private _profileContract;
    // Publish contract.
    IPublishNFT private _publishContract;

    // Owner address.
    address private _owner;
    // Like support amount. When a profile likes other profile's publishes they will have to send this amount as a support to the creator.
    uint private _likeSupportFee;
    // Operational fee for the platform, this is a percentage to deduct from the like fee before transfering the fee to the publish's owner, need to store it as a whole number and do division when using it.
    uint private _platformFee;
    // Mapping of Like struct by token id.
    mapping(uint256 => DataTypes.Like) private _tokenById;

    // Events
    event Received(address sender, uint value);
    event Like(DataTypes.Like token, address owner, uint256 publishId);
    event UnLike(DataTypes.Like token, address owner, uint256 publishId);

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

        _likeSupportFee = 0.001 ether;
        _platformFee = 2;
    }

    /**
     * To receive ether when "like" function is called.
     */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /**
     * @dev see ILikeNFT - setProfileContract
     */
    function setProfileContract(address profileContractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        _profileContract = IProfileNFT(profileContractAddress);
    }

    /**
     * @dev see ILikeNFT - setPublishContract
     */
    function setPublishContract(address publishContractAddress)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        _publishContract = IPublishNFT(publishContractAddress);
    }

    /**
     * @dev see ILikeNFT - setOwnerAddress
     */
    function setOwnerAddress(address owner)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        _owner = owner;
    }

    /**
     * @dev see ILikeNFT - getOwnerAddress
     */
    function getOwnerAddress()
        external
        view
        override
        onlyRole(ADMIN_ROLE)
        returns (address)
    {
        return _owner;
    }

    /**
     * @dev see ILikeNFT - withdraw
     */
    function withdraw() external override onlyRole(ADMIN_ROLE) {
        // Make sure the owner address is set.
        require(_owner != address(0), "Owner address not set");

        payable(_owner).transfer(address(this).balance);
    }

    /**
     * @dev see ILikeNFT - setLikeSupportFee
     */
    function setLikeSupportFee(uint amount)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        _likeSupportFee = amount;
    }

    /**
     * @dev see ILikeNFT - getLikeSupportFee
     */
    function getLikeSupportFee() external view returns (uint) {
        return _likeSupportFee;
    }

    /**
     * @dev see ILikeNFT - setOperationalFee
     */
    function setPlatformFee(uint fee) external override onlyRole(ADMIN_ROLE) {
        _platformFee = fee;
    }

    /**
     * @dev see ILikeNFT - getPlatformFee
     */
    function getPlatformFee() external view returns (uint) {
        return _platformFee;
    }

    /**
     * @dev see ILikeNFT - getContractBalance
     */
    function getContractBalance()
        external
        view
        override
        onlyRole(ADMIN_ROLE)
        returns (uint)
    {
        return address(this).balance;
    }

    /**
     * @dev see ILikeNFT - like
     */
    function like(DataTypes.CreateLikeData calldata createLikeData)
        external
        payable
        override
    {
        // Validate ether sent.
        require(msg.value == _likeSupportFee, "Bad input");

        // Get the Publish's owner.
        // The ownerOfPublish will also check if the publish id exist.
        address publishOwner = _publishContract.ownerOfPublish(
            createLikeData.publishId
        );

        // Increment the counter before using it so the id will start from 1 (instead of 0).
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        // Mint an NFT to the owner.
        _safeMint(msg.sender, tokenId);

        // Create Like NFT.
        DataTypes.Like memory token = DataTypes.Like({
            owner: msg.sender,
            tokenId: tokenId,
            profileId: createLikeData.profileId,
            publishId: createLikeData.publishId
        });

        // Update mapping.
        _tokenById[tokenId] = token;

        // Transfer like support fee after deducting operational fee for the platform to the publish owner.
        payable(publishOwner).transfer(
            msg.value - (msg.value * (_platformFee / 100))
        );

        // Update the Publish NFT's likes.
        _publishContract.like(createLikeData.publishId);

        // Emit Like event.
        emit Like(token, msg.sender, createLikeData.publishId);
    }

    /**
     * A public function to burn a token.
     * @dev use this function to unlike.
     * @param tokenId {number} - a token id to be burned
     */
    function burn(uint256 tokenId) public override {
        // Token must exist.
        require(_exists(tokenId), "Token not found");

        // The caller must be the owner.
        require(msg.sender == ownerOf(tokenId), "Forbidden");

        // Get the token struct.
        DataTypes.Like memory token = _tokenById[tokenId];

        // Clear the token from _tokenById mapping.
        delete _tokenById[tokenId];

        // Call the parent burn function.
        super.burn(tokenId);

        // Update the Publish NFT's likes.
        _publishContract.unLike(token.publishId);

        // Emit UnLike event
        emit UnLike(token, msg.sender, token.publishId);
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
