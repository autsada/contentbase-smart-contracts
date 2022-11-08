// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";

import "./IProfile.sol";
import "./IProfileFactory.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Helpers} from "../libraries/Helpers.sol";

/**
 * @title ContentBase Profile Contract
 * @notice This is the implementation of ContentBase Profile, this contrat is designed to be deployed as a proxy contract via the factory contract every time an EOA calls the `createProfile` function in the factory. So each time an EOA calls the `createProfile` function they will receive a profile proxy contract, and they can create as many profiles as they want as long as the given handle is unique.
 * @notice The profile contract will mint (or burn) a Follow NFT when the contract get called on the `follow` function by other profile contract.
 * @notice Almost of the write functions in the contract are guarded with onlyOwner modifier, so only an owner of the contract can call them.
 *
 */

contract ContentBaseProfile is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    OwnableUpgradeable,
    IContentBaseProfile
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    /**
     * ===== Storage ===== *
     */
    // ContentBase owner address.
    address public platform;
    // ContentBase factory contract address for use to communicate with the factory contract.
    address public factoryContract;
    // Follow token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;
    // Profile info struct.
    DataTypes.Profile private profile;
    // Followers state: mapping (followerAddress => tokenId) to tract the follow token ids (the tokens issued by this contract) by follower address.
    mapping(address => uint256) private _followerToTokenId;
    // Following state: mapping (followingAddress => uint256) to track other profiles that this profile that inherits this contract is following (following of the profile).
    mapping(address => uint256) private _followingToTokenId;
    // Mapping (tokenId => followStruct).
    mapping(uint256 => DataTypes.Follow) private _tokenIdToFollow;

    /**
     * ===== Events ===== *
     */
    event ProfileImageUpdated(
        address indexed owner,
        address indexed proxy,
        string imageURI
    );
    /**
     * @dev `follower` and `followee` are proxy profile addresses, `followerOwner` is an EOA that owns the follower proxy contract, `tokenId` is a token id.
     */
    event FollowNFTMinted(
        address indexed follower,
        address indexed followerOwner,
        address indexed followee,
        uint256 tokenId
    );
    event FollowNFTBurned(
        address indexed follower,
        address indexed followerOwner,
        address indexed followee,
        uint256 tokenId
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * ===== Initialize Function ===== *
     */

    /**
     * @param _platform {address} - the address of ContentBase owner
     * @param _factoryContract {address} - the address of the ContentBase Factory Contract
     * @param _owner {address} - an address of the proxy profile contract owner
     * @param createProfileData - see DataTypes.CreateProfileData
     */
    function initialize(
        address _platform,
        address _factoryContract,
        address _owner,
        DataTypes.CreateProfileData calldata createProfileData
    ) public initializer {
        __ERC721_init("ContentBase Profile's Follow NFT", "CPF");
        __ERC721Burnable_init();
        __Ownable_init();
        // Transfer an ownership to the owner (EOA) of the proxy profile that initialize the follow contract.
        transferOwnership(_owner);

        platform = _platform;
        factoryContract = _factoryContract;
        profile = DataTypes.Profile({
            owner: _owner,
            handle: createProfileData.handle,
            imageURI: createProfileData.imageURI,
            followers: 0,
            following: 0
        });
    }

    /**
     * ===== Modifiers ===== *
     */

    /**
     * The modifer to check the profile contract is properly initialized.
     */
    modifier onlyReady() {
        require(platform != address(0), "Not ready");
        require(factoryContract != address(0), "Not ready");
        require(profile.owner != address(0), "Not ready");

        _;
    }

    /**
     * The modifier to check if the given profile address is a ContentBase Profile.
     */
    modifier onlyContentBaseProfile(address profileAddress) {
        address profileOwner = IContentBaseProfileFactory(factoryContract)
            .getProfileOwner(profileAddress);
        require(profileOwner != address(0));

        _;
    }

    /**
     * ===== Functions ===== *
     */

    /**
     * @inheritdoc IContentBaseProfile
     */
    function updateProfileImage(string calldata imageURI)
        external
        override
        onlyReady
        onlyOwner
    {
        // Validate the image uri.
        require(Helpers.notTooShortURI(imageURI));
        require(Helpers.notTooLongURI(imageURI));

        // Get the profile struct.
        DataTypes.Profile memory oldData = profile;

        // Image uri must changed.
        require(
            keccak256(abi.encodePacked(imageURI)) !=
                keccak256(abi.encodePacked(oldData.imageURI)),
            "No change"
        );

        // Update the profile struct.
        profile.imageURI = imageURI;

        emit ProfileImageUpdated(msg.sender, address(this), imageURI);
    }

    /**
     * @inheritdoc IContentBaseProfile
     */
    /**
     * @dev This function will be called by the owner of the profile contract when they want to follow other profile, and this function will forward the call to the `follow` function on the target profile address.
     *
     * This diagram shows the flow when profile address A follows profile address B.
     * EOA -> A `requestFollow` -> B `follow` (update B's followers states) -> returned values to A `requestFollow` (update A's following states)
     *
     *
     */
    function requestFollow(address targetProfileAddress)
        external
        override
        onlyOwner
        onlyReady
        onlyContentBaseProfile(targetProfileAddress)
    {
        // Call the `follow` function on the `targetProfileAddress` and get returned values.
        (
            bool success,
            DataTypes.Follow memory followToken,
            uint256 tokenId,
            DataTypes.FollowType followType
        ) = IContentBaseProfile(targetProfileAddress).follow();

        require(success, "Follow failed");

        // On follow success, call the follow module to upate the following states.
        // Update the following states depending on the follow type.
        if (followType == DataTypes.FollowType.FOLLOW) {
            // FOLLOW
            profile.following++;
            _followingToTokenId[followToken.issuer] = tokenId;
        } else {
            // UNFOLLOW
            profile.following--;
            delete _followingToTokenId[followToken.issuer];
        }
    }

    /**
     * @inheritdoc IContentBaseProfile
     */
    /**
     * @dev This function will be called from other profile contracts to follow the profile of the called address.
     * @dev As the function will be called by a contract so the `msg.sender` is the profile contract address who calls the function, and this caller address is the following profile address.
     */
    function follow()
        external
        override
        onlyReady
        onlyContentBaseProfile(msg.sender)
        returns (
            bool,
            DataTypes.Follow memory,
            uint256,
            DataTypes.FollowType
        )
    {
        // Get the owner (EOA) of the caller (following profile).
        // The caller `msg.sender` is the profile contract address.
        address profileOwner = IContentBaseProfileFactory(factoryContract)
            .getProfileOwner(msg.sender);

        // Check to identify if the call is for follow or unfollow.
        if (_followerToTokenId[msg.sender] == 0) {
            // FOLLOW CASE -->
            // Increment the counter before using it so the id will start from 1 (instead of 0).
            _tokenIdCounter.increment();
            uint256 newTokenId = _tokenIdCounter.current();

            // Mint the follow NFT to the follower profile owner (EOA).
            _safeMint(profileOwner, newTokenId);

            // Set the follow struct in the struct mapping.
            _tokenIdToFollow[newTokenId] = DataTypes.Follow({
                owner: profileOwner,
                follower: msg.sender,
                issuer: address(this) // As the Follow Contract will be inherited by the Profile Contract, so `address(this)` is the profile address.
            });

            // Update the followers states of the contract.
            _followerToTokenId[msg.sender] = newTokenId;
            profile.followers++;

            emit FollowNFTMinted(
                msg.sender,
                profileOwner,
                address(this),
                newTokenId
            );

            return (
                true,
                _tokenIdToFollow[newTokenId],
                newTokenId,
                DataTypes.FollowType.FOLLOW
            );
        } else {
            // UNFOLLOW CASE
            uint256 followTokenId = _followerToTokenId[msg.sender];

            DataTypes.Follow memory followStruct = _tokenIdToFollow[
                followTokenId
            ];

            // Check token ownership.
            require(ownerOf(followTokenId) == profileOwner, "Forbidden");

            // Burn the token.
            super.burn(followTokenId);

            // Delete follow struct mapping;
            delete _tokenIdToFollow[followTokenId];

            // Update followers states.
            delete _followerToTokenId[msg.sender];
            profile.followers--;

            emit FollowNFTBurned(
                msg.sender,
                profileOwner,
                address(this),
                followTokenId
            );

            return (
                true,
                followStruct,
                followTokenId,
                DataTypes.FollowType.UNFOLLOW
            );
        }
    }

    /**
     * @inheritdoc IContentBaseProfile
     */
    function getProfile()
        external
        view
        onlyReady
        returns (DataTypes.Profile memory)
    {
        return profile;
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
}
