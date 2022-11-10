// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Constants} from "./Constants.sol";
import {DataTypes} from "./DataTypes.sol";

library Events {
    // Factory Events
    event ProfileCreated(
        address indexed owner,
        address indexed profileAddress,
        string handle,
        string imageURI,
        bool isDefault,
        uint256 timestamp
    );
    event DefaultProfileUpdated(
        address indexed proxy,
        address indexed owner,
        uint256 timestamp
    );

    // Profile Events
    event ProfileImageUpdated(
        address indexed owner,
        address indexed proxy,
        string imageURI,
        uint256 timestamp
    );
    /**
     * @dev `follower` and `followee` are proxy profile addresses, `followerOwner` is an EOA that owns the follower proxy contract, `tokenId` is a token id.
     */
    event FollowNFTMinted(
        uint256 indexed tokenId,
        address indexed follower,
        address indexed followerOwner,
        address followee,
        uint256 timestamp
    );
    event FollowNFTBurned(
        uint256 indexed tokenId,
        address indexed follower,
        address indexed followerOwner,
        address followee,
        uint256 timestamp
    );

    // Publish Events.
    event PublishCreated(
        uint256 indexed tokenId,
        address indexed creatorId,
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
        address creatorId,
        address owner,
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
        address indexed owner,
        address profileAddress,
        uint256 timestamp
    );

    // Like Events.
    event PublishLiked(
        uint256 indexed likeId,
        uint256 indexed publishId,
        address indexed publishOwner,
        address profileAddress,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 fee,
        uint256 timestamp
    );
    event PublishUnLiked(
        uint256 indexed likeId,
        uint256 publishId,
        address profileAddress,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );

    // DisLike Events.
    event PublishDisLiked(
        uint256 indexed publishId,
        address indexed profileAddress,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );
    event PublishUndoDisLiked(
        uint256 indexed publishId,
        address indexed profileAddress,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );

    /**
     * @dev the `commentId` if not 0, it means the newly created comment was made on that commentId (this is the case where profile comments on other comments).
     */
    event CommentCreated(
        uint256 indexed tokenId,
        uint256 indexed publishId,
        address indexed profileAddress,
        address owner,
        string text,
        string contentURI,
        uint256 commentId,
        uint256 timestamp
    );
    event CommentUpdated(
        uint256 indexed tokenId,
        uint256 indexed publishId,
        address indexed profileAddress,
        address owner,
        string text,
        string contentURI,
        uint256 timestamp
    );
    event CommentDeleted(
        uint256 indexed tokenId,
        uint256 publishId,
        uint256 timestamp
    );

    // Comment Events
    event CommentLiked(
        uint256 indexed commentId,
        address commentOwner,
        address profileAddress,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );
    event CommentUnLiked(
        uint256 indexed commentId,
        address profileAddress,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );
    event CommentDisLiked(
        uint256 indexed commentId,
        address indexed profileAddress,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );
    event CommentUndoDisLiked(
        uint256 indexed commentId,
        address indexed profileAddress,
        address profileOwner,
        uint32 likes,
        uint32 disLikes,
        uint256 timestamp
    );
}
