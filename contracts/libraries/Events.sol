// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "./DataTypes.sol";

library Events {
    // Profile Events
    event ProfileCreated(
        uint256 indexed profileId,
        address indexed owner,
        string handle,
        string imageURI,
        bool isDefault,
        uint256 timestamp
    );

    event ProfileImageUpdated(
        uint256 indexed profileId,
        address indexed owner,
        string imageURI,
        uint256 timestamp
    );

    event DefaultProfileUpdated(
        uint256 indexed profileId,
        address indexed owner,
        uint256 timestamp
    );

    // Follow Events
    event FollowNFTMinted(
        uint256 indexed tokenId,
        uint256 indexed followerId,
        uint256 indexed followeeId,
        address owner,
        uint256 timestamp
    );
    event FollowNFTBurned(
        uint256 indexed tokenId,
        uint256 indexed followerId,
        uint256 indexed followeeId,
        address owner,
        uint256 timestamp
    );

    // Publish Events.
    event PublishCreated(
        uint256 indexed tokenId,
        uint256 indexed creatorId,
        address indexed owner,
        string imageURI,
        string contentURI,
        string metadataURI,
        string title,
        string description,
        DataTypes.Category primaryCategory,
        DataTypes.Category secondaryCategory,
        DataTypes.Category tertiaryCategory,
        uint256 timestamp
    );
    event PublishUpdated(
        uint256 indexed tokenId,
        uint256 indexed creatorId,
        address indexed owner,
        string imageURI,
        string contentURI,
        string metadataURI,
        string title,
        string description,
        DataTypes.Category primaryCategory,
        DataTypes.Category secondaryCategory,
        DataTypes.Category tertiaryCategory,
        uint256 timestamp
    );
    event PublishDeleted(
        uint256 indexed tokenId,
        uint256 indexed creatorId,
        address indexed owner,
        uint256 timestamp
    );

    // Comment Events.
    event CommentCreated(
        uint256 indexed tokenId,
        uint256 indexed targetId,
        uint256 indexed creatorId,
        address owner,
        string contentURI,
        uint256 timestamp
    );
    event CommentUpdated(
        uint256 indexed tokenId,
        uint256 indexed creatorId,
        address owner,
        string contentURI,
        uint256 timestamp
    );
    event CommentDeleted(
        uint256 indexed tokenId,
        uint256 indexed creatorId,
        address owner,
        uint256 timestamp
    );

    // Like Events (Publish).
    // For Publish like events, there will be Like NFT involve, a new Like NFT will be created when `like`, however when `unlike` the Like NFT will NOT be burned.
    event PublishLiked(
        uint256 indexed tokenId,
        uint256 indexed publishId,
        uint256 indexed profileId,
        address publishOwner,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 fee,
        uint256 timestamp
    );
    event PublishUnLiked(
        uint256 indexed publishId,
        uint256 indexed profileId,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );

    event PublishDisLiked(
        uint256 indexed publishId,
        uint256 indexed profileId,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );
    event PublishUndoDisLiked(
        uint256 indexed publishId,
        uint256 indexed profileId,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );

    // Like Events (Comment).
    // For Comment like events, there is no Like NFT involve.
    event CommentLiked(
        uint256 indexed commentId,
        uint256 indexed profileId,
        address commentOwner,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );
    event CommentUnLiked(
        uint256 indexed commentId,
        uint256 indexed profileId,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );
    event CommentDisLiked(
        uint256 indexed commentId,
        uint256 indexed profileId,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );
    event CommentUndoDisLiked(
        uint256 indexed commentId,
        uint256 indexed profileId,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );
}
