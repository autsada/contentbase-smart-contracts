// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "./libraries/DataTypes.sol";

abstract contract ContentBaseStorageV1 {
    // ContentBase owner address.
    address public platformOwner;
    // The amount that a profile will send to the owner of the publish they like.
    uint256 public likeFee;
    // The percentage to be deducted from the like fee (as the platform commission) before transfering the like fee to the publish's owner, need to store it as a whole number and do division when using it.
    uint24 public platformFee;

    // Token Collections.
    uint256 public constant PROFILE = 1;
    uint256 public constant FOLLOW = 2;
    uint256 public constant PUBLISH = 3;
    uint256 public constant COMMENT = 4;
    uint256 public constant LIKE = 5;

    // Mappping to track token id to token collection.
    mapping(uint256 => uint256) internal _tokenIdToCollection;

    // ===== Profile NTFs Storage ===== //

    // Mapping (tokenId => profile struct).
    mapping(uint256 => DataTypes.Profile) internal _tokenIdToProfile;
    // Mapping (hash => profile id) of handle hash to profile id.
    mapping(bytes32 => uint256) internal _handleHashToProfileId;
    // Mapping (owner => profile id) of owner to their default profile id.
    mapping(address => uint256) internal _ownerToDefaultProfileId;

    // // ===== Follow NTFs Storage ===== //

    // Mapping (profile id => (followee id => follow token id)) to tract the following profiles of a profile.
    mapping(uint256 => mapping(uint256 => uint256))
        internal _profileIdToFolloweeIdToTokenId;
    // Mapping (profile id => (follower id => follow token id)) to tract the follower profiles of a profile.
    mapping(uint256 => mapping(uint256 => uint256))
        internal _profileIdToFollowerIdToTokenId;

    // // ===== Publish NTFs Storage ===== //

    // Mapping (tokenId => publish struct).
    mapping(uint256 => DataTypes.Publish) internal _tokenIdToPublish;
    // Mapping of (publishId => (profileId => likeId)) to track if a specific profile id liked a publish, for example (1 => (2 => 3)) means publish token id 1 has been liked by profile token id 2, and like token id 3 has been minted to the profile id 2.
    mapping(uint256 => mapping(uint256 => uint256))
        internal _publishIdToProfileIdToLikeId;
    // Mapping of (publishId => (profileId => bool)) to track if a specific profile disliked a publish, for example (1 => (2 => true)) means publish token id 1 has been dis-liked by profile token id 2.
    mapping(uint256 => mapping(uint256 => bool))
        internal _publishIdToProfileIdToDislikeStatus;

    // ===== Comment NTFs Storage ===== //

    // Mapping (tokenId => like struct).
    mapping(uint256 => DataTypes.Comment) internal _tokenIdToComment;
    // Mapping of (commentId => (profileId => bool)) to track if a specific profile liked a comment.
    mapping(uint256 => mapping(uint256 => bool))
        internal _commentIdToProfileIdToLikeStatus;
    // Mapping of (commentId => (profileId => bool)) to track if a specific profile disliked the comment.
    mapping(uint256 => mapping(uint256 => bool))
        internal _commentIdToProfileIdToDislikeStatus;

    // ===== Like NTFs Storage ===== //

    // Mapping to track how many Like NFT a profile has.
    mapping(uint256 => uint256) internal _profileIdToLikeNFTCount;
}
