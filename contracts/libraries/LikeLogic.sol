// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "./DataTypes.sol";
import {Events} from "./Events.sol";

library LikeLogic {
    struct LikePublishData {
        uint256 tokenId;
        uint256 publishId;
        address publishOwner;
        uint256 profileId;
        uint netFee;
    }

    /**
     * @param likePublishData - LikePublishData struct
     * @param _tokenIdToPublish - storage mapping
     * @param _profileIdToLikeNFTCount - storage mapping
     * @param _publishIdToProfileIdToLikeId - storage mapping
     * @param _publishIdToProfileIdToDislikeStatus - storage mapping
     */
    function _likePublish(
        LikePublishData memory likePublishData,
        mapping(uint256 => DataTypes.Publish) storage _tokenIdToPublish,
        mapping(uint256 => uint256) storage _profileIdToLikeNFTCount,
        mapping(uint256 => mapping(uint256 => uint256))
            storage _publishIdToProfileIdToLikeId,
        mapping(uint256 => mapping(uint256 => bool))
            storage _publishIdToProfileIdToDislikeStatus
    ) internal {
        // Update the profile's Like NFT count.
        _profileIdToLikeNFTCount[likePublishData.profileId]++;

        // Increase `likes` count of the publish struct.
        _tokenIdToPublish[likePublishData.publishId].likes++;

        // Update publish to profile to like mapping.
        _publishIdToProfileIdToLikeId[likePublishData.publishId][
            likePublishData.profileId
        ] = likePublishData.tokenId;

        // If the profile disliked the publish before, we need to update all related states.
        if (
            _publishIdToProfileIdToDislikeStatus[likePublishData.publishId][
                likePublishData.profileId
            ]
        ) {
            _publishIdToProfileIdToDislikeStatus[likePublishData.publishId][
                likePublishData.profileId
            ] = false;

            if (_tokenIdToPublish[likePublishData.publishId].disLikes > 0) {
                _tokenIdToPublish[likePublishData.publishId].disLikes--;
            }
        }

        // Emit publish liked event.
        emit Events.PublishLiked(
            likePublishData.tokenId,
            likePublishData.publishId,
            likePublishData.profileId,
            likePublishData.publishOwner,
            msg.sender,
            _tokenIdToPublish[likePublishData.publishId].likes,
            _tokenIdToPublish[likePublishData.publishId].disLikes,
            likePublishData.netFee,
            block.timestamp
        );
    }

    /**
     * @param publishId {uint256}
     * @param profileId {uint256}
     * @param _tokenIdToPublish - storage mapping
     * @param _profileIdToLikeNFTCount - storage mapping
     * @param _publishIdToProfileIdToLikeId - storage mapping
     */
    function _unLikePublish(
        uint256 publishId,
        uint256 profileId,
        mapping(uint256 => DataTypes.Publish) storage _tokenIdToPublish,
        mapping(uint256 => uint256) storage _profileIdToLikeNFTCount,
        mapping(uint256 => mapping(uint256 => uint256))
            storage _publishIdToProfileIdToLikeId
    ) internal {
        // Update the profile's Like NFT count.
        // Make sure the count is greater than 0.
        if (_profileIdToLikeNFTCount[profileId] > 0) {
            _profileIdToLikeNFTCount[profileId]--;
        }

        // Decrease `likes` count of the publish struct.
        // Make sure the count is greater than 0.
        if (_tokenIdToPublish[publishId].likes > 0) {
            _tokenIdToPublish[publishId].likes--;
        }

        // Remove the like id from the publish to profile to like mapping, this will make this profile can like the given publish id again.
        _publishIdToProfileIdToLikeId[publishId][profileId] = 0;

        // Emit publish unliked event.
        emit Events.PublishUnLiked(
            publishId,
            profileId,
            msg.sender,
            _tokenIdToPublish[publishId].likes,
            _tokenIdToPublish[publishId].disLikes,
            block.timestamp
        );
    }

    /**
     * @param publishId {uint256}
     * @param profileId {uint256}
     * @param _tokenIdToPublish - storage mapping
     * @param _publishIdToProfileIdToLikeId - storage mapping
     * @param _publishIdToProfileIdToDislikeStatus - storage mapping
     */
    function _disLikePublish(
        uint256 publishId,
        uint256 profileId,
        mapping(uint256 => DataTypes.Publish) storage _tokenIdToPublish,
        mapping(uint256 => mapping(uint256 => uint256))
            storage _publishIdToProfileIdToLikeId,
        mapping(uint256 => mapping(uint256 => bool))
            storage _publishIdToProfileIdToDislikeStatus
    ) internal {
        // Update the disliked mapping.
        _publishIdToProfileIdToDislikeStatus[publishId][profileId] = true;

        // Increase the publish struct disLikes.
        _tokenIdToPublish[publishId].disLikes++;

        // If the profile liked the publish before, we need to update the liked mapping and decrease the publish's likes count as well.
        if (_publishIdToProfileIdToLikeId[publishId][profileId] != 0) {
            _publishIdToProfileIdToLikeId[publishId][profileId] = 0;

            if (_tokenIdToPublish[publishId].likes > 0) {
                _tokenIdToPublish[publishId].likes--;
            }
        }

        // Emit publihs dislike event.
        emit Events.PublishDisLiked(
            publishId,
            profileId,
            msg.sender,
            _tokenIdToPublish[publishId].likes,
            _tokenIdToPublish[publishId].disLikes,
            block.timestamp
        );
    }

    /**
     * @param publishId {uint256}
     * @param profileId {uint256}
     * @param _tokenIdToPublish - storage mapping
     * @param _publishIdToProfileIdToDislikeStatus - storage mapping
     */
    function _undoDisLikePublish(
        uint256 publishId,
        uint256 profileId,
        mapping(uint256 => DataTypes.Publish) storage _tokenIdToPublish,
        mapping(uint256 => mapping(uint256 => bool))
            storage _publishIdToProfileIdToDislikeStatus
    ) internal {
        // Update the disliked mapping.
        _publishIdToProfileIdToDislikeStatus[publishId][profileId] = false;

        // Decrease dislikes count.
        // Make sure the count is greater than 0.
        if (_tokenIdToPublish[publishId].disLikes > 0) {
            _tokenIdToPublish[publishId].disLikes--;
        }

        // Emit publihs undo-dislike event.
        emit Events.PublishUndoDisLiked(
            publishId,
            profileId,
            msg.sender,
            _tokenIdToPublish[publishId].likes,
            _tokenIdToPublish[publishId].disLikes,
            block.timestamp
        );
    }

    struct LikeCommentData {
        uint256 commentId;
        uint256 profileId;
        address commentOwner;
    }

    /**
     * @param likeCommentData - LikeCommentData
     * @param _tokenIdToComment - storage mapping
     * @param _commentIdToProfileIdToLikeStatus - storage mapping
     * @param _commentIdToProfileIdToDislikeStatus - storage mapping
     */
    function _likeComment(
        LikeCommentData memory likeCommentData,
        mapping(uint256 => DataTypes.Comment) storage _tokenIdToComment,
        mapping(uint256 => mapping(uint256 => bool))
            storage _commentIdToProfileIdToLikeStatus,
        mapping(uint256 => mapping(uint256 => bool))
            storage _commentIdToProfileIdToDislikeStatus
    ) internal {
        uint256 commentId = likeCommentData.commentId;
        uint256 profileId = likeCommentData.profileId;
        address commentOwner = likeCommentData.commentOwner;

        // Update the comment to profile to like status mapping.
        _commentIdToProfileIdToLikeStatus[commentId][profileId] = true;

        // Update the comment struct `likes` count.
        _tokenIdToComment[commentId].likes++;

        // If the profile `dislike` the comment before, update the dislike states.
        if (_commentIdToProfileIdToDislikeStatus[commentId][profileId]) {
            _commentIdToProfileIdToDislikeStatus[commentId][profileId] = false;

            // Update the comment `dislikes` count.
            if (_tokenIdToComment[commentId].disLikes > 0) {
                _tokenIdToComment[commentId].disLikes--;
            }
        }

        // Emit comment liked event.
        emit Events.CommentLiked(
            commentId,
            profileId,
            commentOwner,
            msg.sender,
            _tokenIdToComment[commentId].likes,
            _tokenIdToComment[commentId].disLikes,
            block.timestamp
        );
    }

    /**
     * @param commentId {uint256}
     * @param profileId {uint256}
     * @param _tokenIdToComment - storage mapping
     * @param _commentIdToProfileIdToLikeStatus - storage mapping
     */
    function _unLikeComment(
        uint256 commentId,
        uint256 profileId,
        mapping(uint256 => DataTypes.Comment) storage _tokenIdToComment,
        mapping(uint256 => mapping(uint256 => bool))
            storage _commentIdToProfileIdToLikeStatus
    ) internal {
        // Update the comment to profile to like mapping.
        _commentIdToProfileIdToLikeStatus[commentId][profileId] = false;

        // Update the comment struct `likes` count.
        if (_tokenIdToComment[commentId].likes > 0) {
            _tokenIdToComment[commentId].likes--;
        }

        // Emit comment unliked event.
        emit Events.CommentUnLiked(
            commentId,
            profileId,
            msg.sender,
            _tokenIdToComment[commentId].likes,
            _tokenIdToComment[commentId].disLikes,
            block.timestamp
        );
    }

    /**
     * @param commentId {uint256}
     * @param profileId {uint256}
     * @param _tokenIdToComment - storage mapping
     * @param _commentIdToProfileIdToLikeStatus - storage mapping
     * @param _commentIdToProfileIdToDislikeStatus - storage mapping
     */
    function _disLikeComment(
        uint256 commentId,
        uint256 profileId,
        mapping(uint256 => DataTypes.Comment) storage _tokenIdToComment,
        mapping(uint256 => mapping(uint256 => bool))
            storage _commentIdToProfileIdToLikeStatus,
        mapping(uint256 => mapping(uint256 => bool))
            storage _commentIdToProfileIdToDislikeStatus
    ) internal {
        // Update the comment to profile to dislike status mapping.
        _commentIdToProfileIdToDislikeStatus[commentId][profileId] = true;

        // Update the comment struct `disLikes` count.
        _tokenIdToComment[commentId].disLikes++;

        // If the profile `like` the comment before, update the like states.
        if (_commentIdToProfileIdToLikeStatus[commentId][profileId]) {
            _commentIdToProfileIdToLikeStatus[commentId][profileId] = false;

            // Update the comment `likes` count.
            if (_tokenIdToComment[commentId].likes > 0) {
                _tokenIdToComment[commentId].likes--;
            }
        }

        // Emit comment disliked event.
        emit Events.CommentDisLiked(
            commentId,
            profileId,
            msg.sender,
            _tokenIdToComment[commentId].likes,
            _tokenIdToComment[commentId].disLikes,
            block.timestamp
        );
    }

    /**
     * @param commentId {uint256}
     * @param profileId {uint256}
     * @param _tokenIdToComment - storage mapping
     * @param _commentIdToProfileIdToDislikeStatus - storage mapping
     */
    function _undoDislikeComment(
        uint256 commentId,
        uint256 profileId,
        mapping(uint256 => DataTypes.Comment) storage _tokenIdToComment,
        mapping(uint256 => mapping(uint256 => bool))
            storage _commentIdToProfileIdToDislikeStatus
    ) internal {
        // Update the comment to profile to dislike status mapping.
        _commentIdToProfileIdToDislikeStatus[commentId][profileId] = false;

        // Update the comment struct `disLikes` count.
        if (_tokenIdToComment[commentId].disLikes > 0) {
            _tokenIdToComment[commentId].disLikes--;
        }

        // Emit comment disliked event.
        emit Events.CommentUndoDisLiked(
            commentId,
            profileId,
            msg.sender,
            _tokenIdToComment[commentId].likes,
            _tokenIdToComment[commentId].disLikes,
            block.timestamp
        );
    }
}
