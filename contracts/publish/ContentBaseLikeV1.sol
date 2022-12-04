// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";

import {IContentBaseLikeV1} from "./IContentBaseLikeV1.sol";
import {IContentBasePublishV1} from "./IContentBasePublishV1.sol";
import {IContentBaseProfileV1} from "../profile/IContentBaseProfileV1.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Helpers} from "../libraries/Helpers.sol";

/**
 * @title ContentBaseLikeV1
 * @author Autsada T
 *
 * @notice A like NFT will be minted when a profile like a publish, to mint a like NFT, the caller must send a long some ethers that equals to the specified `like fee` with the request, the platform fee will be applied to the like fee and the net total will be transfered to an owner of the liked publish.
 * @notice The like NFTs are non-burnable.
 */

contract ContentBaseLikeV1 is
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IContentBaseLikeV1
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    // Token Ids counter.
    CountersUpgradeable.Counter private _tokenIdCounter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // A ContentBase owner address.
    address public platformOwner;
    // The amount that a profile will send to the owner of the publish they like.
    uint256 public likeFee;
    // The percentage to be deducted from the like fee (as the platform commission) before transfering the like fee to the publish's owner, need to store it as a whole number and do division when using it.
    uint256 public platformFee;

    // A private state to store the profile contract address.
    address private _profileContractAddress;
    // A private state to store the publish contract address.
    address private _publishContractAddress;
    // A mapping of (publishId => (profileId => likeId)) to track if a specific profile id liked a publish, for example (1 => (2 => 3)) means publish token id 1 has been liked by profile token id 2, and like token id 3 has been minted to the profile id 2.
    mapping(uint256 => mapping(uint256 => uint256))
        private _publishIdToProfileIdToLikeId;
    // A mapping of (publishId => (profileId => bool)) to track if a specific profile disliked a publish, for example (1 => (2 => true)) means publish token id 1 has been dis-liked by profile token id 2.
    mapping(uint256 => mapping(uint256 => bool))
        private _publishIdToProfileIdToDislikeStatus;
    // A mapping (publish id => total received) to track total like fee received of each publish.
    mapping(uint256 => uint256) public publishIdToTotalReceived;
    // A mapping to track how many Like NFT a profile has.
    mapping(uint256 => uint256) public profileIdToLikeNFTCount;
    // A mapping (publish id => likes) to track the likes count of a publish.
    mapping(uint256 => uint32) public publishIdToLikesCount;
    // A mapping (publish id => disLikes) to track the disLikes count of a publish.
    mapping(uint256 => uint32) public publishIdToDisLikesCount;

    // Events.
    event PublishLiked(
        uint256 indexed tokenId,
        uint256 indexed publishId,
        uint256 indexed profileId,
        uint256 fee,
        uint256 totalReceived,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );
    event PublishUnLiked(
        uint256 indexed likeId,
        uint256 indexed publishId,
        uint32 likes,
        uint256 timestamp
    );
    event PublishDisLiked(
        uint256 indexed publishId,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );
    event PublishUndoDisLiked(
        uint256 indexed publishId,
        uint32 disLikes,
        uint256 timestamp
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * Initialize function.
     */
    function initialize(
        address profileContractAddress,
        address publishContractAddress
    ) public initializer {
        __ERC721_init("ContentBase Publish Module", "CPM");
        __ERC721Burnable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        platformOwner = msg.sender;
        likeFee = 1000 ether;
        platformFee = 50;
        _profileContractAddress = profileContractAddress;
        _publishContractAddress = publishContractAddress;
    }

    /**
     * A modifier to check if the contract is ready for use.
     * @dev Extract code inside the modifier to a private function to reduce contract size.
     */
    function _onlyReady() private view {
        require(platformOwner != address(0), "Platform owner not set");
        require(likeFee != 0, "Like fee not set");
        require(platformFee != 0, "Platform fee not set");
        require(
            _profileContractAddress != address(0),
            "Profile contract not set"
        );
        require(
            _publishContractAddress != address(0),
            "Publish contract not set"
        );
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
     * A modifier to check if the given profile id is a ContentBase profile and the caller is the owner.
     * @dev Extract code inside the modifier to a private function to reduce contract size.
     */
    function _onlyProfileOwner(uint256 profileId) private view {
        require(
            _profileContractAddress != address(0),
            "Profile contract not set"
        );
        address profileOwner = IContentBaseProfileV1(_profileContractAddress)
            .profileOwner(profileId);
        require(msg.sender == profileOwner, "Forbidden");
    }

    modifier onlyProfileOwner(uint256 profileId) {
        _onlyProfileOwner(profileId);
        _;
    }

    /**
     * A modifier to check if the given publish id exists.
     * @dev Extract code inside the modifier to a private function to reduce contract size.
     */
    function _onlyPublishExist(uint256 publishId) private view {
        require(
            _publishContractAddress != address(0),
            "Publish contract not set"
        );
        require(
            IContentBasePublishV1(_publishContractAddress).publishExist(
                publishId
            ),
            "Publish not found"
        );
    }

    modifier onlyPublishExist(uint256 publishId) {
        _onlyPublishExist(publishId);
        _;
    }

    /**
     *  ***** ADMIN RELATED FUNCTIONS *****
     */

    /**
     * @inheritdoc IContentBaseLikeV1
     */
    function updatePlatformOwner(
        address ownerAddress
    ) external override onlyRole(ADMIN_ROLE) {
        platformOwner = ownerAddress;
    }

    /**
     * @inheritdoc IContentBaseLikeV1
     */
    function updateProfileContract(
        address contractAddress
    ) external override onlyRole(ADMIN_ROLE) {
        _profileContractAddress = contractAddress;
    }

    /**
     * @inheritdoc IContentBaseLikeV1
     */
    function updatePublishContract(
        address contractAddress
    ) external override onlyRole(ADMIN_ROLE) {
        _publishContractAddress = contractAddress;
    }

    /**
     * @inheritdoc IContentBaseLikeV1
     */
    function updateLikeFee(uint256 fee) external override onlyRole(ADMIN_ROLE) {
        likeFee = fee;
    }

    /**
     * @inheritdoc IContentBaseLikeV1
     */
    function updatePlatformFee(
        uint256 fee
    ) external override onlyRole(ADMIN_ROLE) {
        platformFee = fee;
    }

    /**
     * @inheritdoc IContentBaseLikeV1
     */
    function withdraw() external override onlyReady onlyRole(ADMIN_ROLE) {
        payable(platformOwner).transfer(address(this).balance);
    }

    /**
     *  ***** PUBLIC FUNCTIONS *****
     */

    /**
     * @inheritdoc IContentBaseLikeV1
     */
    function likePublish(
        uint256 publishId,
        uint256 profileId
    )
        external
        payable
        override
        onlyReady
        onlyProfileOwner(profileId)
        onlyPublishExist(publishId)
    {
        // Find the like id (if exist).
        uint256 likeId = _publishIdToProfileIdToLikeId[publishId][profileId];

        // Check if the call is for `like` or `unlike`.
        if (likeId == 0) {
            // A. `like` - Mint a LIKE token to the caller.

            // Validate ether sent.
            require(msg.value == likeFee, "Bad input");

            // Transfer the like fee (after deducting operational fee for the platform) to the publish owner.
            uint256 netFee = msg.value - ((msg.value * platformFee) / 100);
            payable(
                IContentBasePublishV1(_publishContractAddress).publishOwner(
                    publishId
                )
            ).transfer(netFee);

            // Increment the counter before using it so the id will start from 1 (instead of 0).
            _tokenIdCounter.increment();
            uint256 tokenId = _tokenIdCounter.current();

            // Mint a Like NFT to the caller.
            _safeMint(msg.sender, tokenId);

            // Update publish to profile to like id mapping.
            _publishIdToProfileIdToLikeId[publishId][profileId] = tokenId;

            // If the profile disliked the publish before, reset the state and decrease the disLikes count.
            if (_publishIdToProfileIdToDislikeStatus[publishId][profileId]) {
                _publishIdToProfileIdToDislikeStatus[publishId][
                    profileId
                ] = false;

                if (publishIdToDisLikesCount[publishId] > 0) {
                    publishIdToDisLikesCount[publishId]--;
                }
            }

            // Update the publish's total received.
            publishIdToTotalReceived[publishId] += netFee;

            // Update the profile's Like NFT count.
            profileIdToLikeNFTCount[profileId]++;

            // Update the publish's likes count.
            publishIdToLikesCount[publishId]++;

            // Emit publish liked event.
            _emitPublishLiked(
                DataTypes.PublishLikedEventArgs({
                    tokenId: tokenId,
                    publishId: publishId,
                    profileId: profileId,
                    netFee: netFee,
                    totalReceived: publishIdToTotalReceived[publishId],
                    likes: publishIdToLikesCount[publishId],
                    disLikes: publishIdToDisLikesCount[publishId]
                })
            );
        } else {
            // B `unlike` - burn the Like NFT.

            // The caller must own the Like token.
            require(ownerOf(likeId) == msg.sender);

            // Burn the token.
            super.burn(likeId);

            // Remove the like id from the publish to profile to like mapping, this will make this profile can like the given publish id again.
            _publishIdToProfileIdToLikeId[publishId][profileId] = 0;

            // Update the profile's Like NFT count.
            // Make sure the count is greater than 0.
            if (profileIdToLikeNFTCount[profileId] > 0) {
                profileIdToLikeNFTCount[profileId]--;
            }

            // Update the publish's likes count.
            // Make sure the count is greater than 0.
            if (publishIdToLikesCount[publishId] > 0) {
                publishIdToLikesCount[publishId]--;
            }

            // Emit publish unliked event.
            emit PublishUnLiked(
                likeId,
                publishId,
                publishIdToLikesCount[publishId],
                block.timestamp
            );
        }
    }

    /**
     * A helper function to emit a publish liked event that accepts args as a struct in memory to avoid a stack too deep error.
     * @param vars - see DataTypes.PublishLikedEventArgs
     */
    function _emitPublishLiked(
        DataTypes.PublishLikedEventArgs memory vars
    ) internal {
        emit PublishLiked(
            vars.tokenId,
            vars.publishId,
            vars.profileId,
            vars.netFee,
            vars.totalReceived,
            vars.likes,
            vars.disLikes,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IContentBaseLikeV1
     * @dev NO Like NFT involve for this function.
     */
    function disLikePublish(
        uint256 publishId,
        uint256 profileId
    )
        external
        override
        onlyReady
        onlyProfileOwner(profileId)
        onlyPublishExist(publishId)
    {
        // Identify if the call is for `dislike` or `undo dislike`.
        bool disLiked = _publishIdToProfileIdToDislikeStatus[publishId][
            profileId
        ];

        if (!disLiked) {
            // DISLIKE

            // Update the disliked mapping.
            _publishIdToProfileIdToDislikeStatus[publishId][profileId] = true;

            // Update the publish's disLikes count.
            publishIdToDisLikesCount[publishId]++;

            // Update the publish's likes count.
            // Make sure the count is greater than 0.
            if (publishIdToLikesCount[publishId] > 0) {
                publishIdToLikesCount[publishId]--;
            }

            // Emit publihs dislike event.
            emit PublishDisLiked(
                publishId,
                publishIdToLikesCount[publishId],
                publishIdToDisLikesCount[publishId],
                block.timestamp
            );
        } else {
            // UNDO DISLIKE

            // Update the disliked mapping.
            _publishIdToProfileIdToDislikeStatus[publishId][profileId] = false;

            // Update the publish's disLikes count.
            // Make sure the count is greater than 0.
            if (publishIdToDisLikesCount[publishId] > 0) {
                publishIdToDisLikesCount[publishId]--;
            }

            // Emit publihs undo-dislike event.
            emit PublishUndoDisLiked(
                publishId,
                publishIdToDisLikesCount[publishId],
                block.timestamp
            );
        }
    }

    /**
     * @inheritdoc IContentBaseLikeV1
     */
    function getProfileContract() external view override returns (address) {
        return _profileContractAddress;
    }

    /**
     * @inheritdoc IContentBaseLikeV1
     */
    function getPublishContract() external view override returns (address) {
        return _publishContractAddress;
    }

    /**
     * @inheritdoc IContentBaseLikeV1
     */
    function checkLikedPublish(
        uint256 profileId,
        uint256 publishId
    ) external view override returns (bool) {
        uint256 likeId = _publishIdToProfileIdToLikeId[publishId][profileId];

        return likeId != 0;
    }

    /**
     * @inheritdoc IContentBaseLikeV1
     */
    function checkDisLikedPublish(
        uint256 profileId,
        uint256 publishId
    ) external view override returns (bool) {
        return _publishIdToProfileIdToDislikeStatus[publishId][profileId];
    }

    /**
     * Override the parent burn function.
     * @dev Force `burn` function to use `deletePublish` function so we can update the related states.
     */
    function burn(uint256 tokenId) public view override {
        require(_exists(tokenId), "Like not found");
        revert("Use `like` function");
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
