// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
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
    // The percentage to be deducted from the like fee (as the platform commission) before transfering the like fee to the publish's owner, need to store it as a whole number and do division when using it.
    uint256 public platformFee;
    // Chainlink ETH/USD price feed contract address for use to calculate like fee.
    address public ethToUsdPriceFeedContract;

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

    // Events.
    event PublishLiked(
        uint256 indexed tokenId,
        uint256 indexed publishId,
        uint256 indexed profileId,
        uint256 totalAmount,
        uint256 fee,
        uint256 timestamp
    );
    event PublishUnLiked(uint256 indexed likeId, uint256 timestamp);
    event PublishDisLiked(
        uint256 indexed publishId,
        uint256 indexed profileId,
        uint256 timestamp
    );
    event PublishUndoDisLiked(
        uint256 indexed publishId,
        uint256 indexed profileId,
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
        platformFee = 10;
        ethToUsdPriceFeedContract = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;
        _profileContractAddress = profileContractAddress;
        _publishContractAddress = publishContractAddress;
    }

    /**
     * A modifier to check if the contract is ready for use.
     * @dev Extract code inside the modifier to a private function to reduce contract size.
     */
    function _onlyReady() private view {
        require(platformOwner != address(0), "Platform owner not set");
        require(
            ethToUsdPriceFeedContract != address(0),
            "Price feed contract not set"
        );
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
    function updatePriceFeedContract(
        address contractAddress
    ) external override onlyRole(ADMIN_ROLE) {
        ethToUsdPriceFeedContract = contractAddress;
    }

    /**
     * @inheritdoc IContentBaseLikeV1
     */
    function updatePlatformFee(
        uint256 fee
    ) external override onlyRole(ADMIN_ROLE) {
        // fee is a percentage value between 1 - 100
        require(fee > 0 && fee <= 100, "Invalid input");
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

            // Validate like fee sent by the caller.
            require(_validateLikeFee(msg.value), "Incorrect fee");

            // Transfer the like fee (after deducting operational fee for the platform) to the publish owner.
            uint256 fee = (msg.value * platformFee) / 100;
            uint256 netTransfer = msg.value - fee;
            payable(
                IContentBasePublishV1(_publishContractAddress).publishOwner(
                    publishId
                )
            ).transfer(netTransfer);

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
            }

            // Update the publish's total received.
            publishIdToTotalReceived[publishId] += netTransfer;

            // Update the profile's Like NFT count.
            profileIdToLikeNFTCount[profileId]++;

            // Emit publish liked event.
            _emitPublishLiked(
                DataTypes.PublishLikedEventArgs({
                    tokenId: tokenId,
                    publishId: publishId,
                    profileId: profileId,
                    totalAmount: msg.value,
                    fee: fee
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

            // Emit publish unliked event.
            emit PublishUnLiked(likeId, block.timestamp);
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
            vars.totalAmount,
            vars.fee,
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

            // Emit publihs dislike event.
            emit PublishDisLiked(publishId, profileId, block.timestamp);
        } else {
            // UNDO DISLIKE

            // Update the disliked mapping.
            _publishIdToProfileIdToDislikeStatus[publishId][profileId] = false;

            // Emit publihs undo-dislike event.
            emit PublishUndoDisLiked(publishId, profileId, block.timestamp);
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
     * A private function to get ETH price in USD from Chainlink.
     * @dev the returned value is a usd amount with decimals and the decimals, for exmaple if the returned value is (118735000000, 8) it means 1 eth = 1187.35000000 usd.
     */
    function _getEthPrice() private view returns (int, uint8) {
        require(ethToUsdPriceFeedContract != address(0), "Not ready");

        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            ethToUsdPriceFeedContract
        );

        // Get ETH/USD price from Chainlink price feed.
        (, int price, , , ) = priceFeed.latestRoundData();

        return (price, priceFeed.decimals());
    }

    /**
     * A public helper function to calculate like fee.
     * @dev The fee is 10% of 1 usd in wei.
     */
    function calculateLikeFee() public view returns (uint256) {
        (int256 price, uint8 decimals) = _getEthPrice();

        // Calculate 1 usd in wei.
        uint256 usdToWei = (1e18 * (10 ** uint256(decimals))) / uint256(price);

        // Like fee is 10% on 1 usd in wei.
        uint256 fee = (usdToWei * 10) / 100;

        return fee;
    }

    /**
     * A helper function to check if the like fee sent by the caller when they like the publish is correct.
     * @dev To validate we convert the sent fee to `usd for 1 eth` and compare it to `usd for 1 eth` that is calculated from the price feed.
     * @dev We use the whole number for comparision, for example if the price feed is `118735000000` we devide this number by the decimals (8 for example) so we get 1187 and then compare it to the whole number received from the calculation of the fee.
     * @dev `fee` is an amount of wei that equals to 0.1 usd.
     */
    function _validateLikeFee(uint256 fee) private view returns (bool) {
        // Calculate how much usd for 1 eth (1e18 wei) from the fee.
        uint256 feeToEthInUsd = 1e18 / (fee * 10);

        // Calculate how much usd for 1 eth from the price feed.
        (int256 price, uint8 decimals) = _getEthPrice();
        uint256 priceFeedToEthInUsd = uint256(price) /
            (10 ** uint256(decimals));

        return feeToEthInUsd == priceFeedToEthInUsd;
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
