// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "./DataTypes.sol";
import {Events} from "./Events.sol";

library CommentLogic {
    /**
     * @param tokenId {uint256}
     * @param createCommentData - see DataTypes.CreateCommentData
     * @param _tokenIdToComment - storage mapping
     */
    function _createComment(
        uint256 tokenId,
        DataTypes.CreateCommentData calldata createCommentData,
        mapping(uint256 => DataTypes.Comment) storage _tokenIdToComment
    ) internal {
        // Create and store a new comment struct in the mapping.
        _tokenIdToComment[tokenId] = DataTypes.Comment({
            owner: msg.sender,
            creatorId: createCommentData.creatorId,
            targetId: createCommentData.targetId,
            likes: 0,
            disLikes: 0,
            contentURI: createCommentData.contentURI
        });

        // Emit comment created event.
        emit Events.CommentCreated(
            tokenId,
            createCommentData.targetId,
            createCommentData.creatorId,
            msg.sender,
            createCommentData.contentURI,
            block.timestamp
        );
    }

    /**
     * @param updateCommentData - see DataTypes.UpdateCommentData
     * @param _tokenIdToComment - storage mapping
     */
    function _updateComment(
        DataTypes.UpdateCommentData calldata updateCommentData,
        mapping(uint256 => DataTypes.Comment) storage _tokenIdToComment
    ) internal {
        uint256 tokenId = updateCommentData.tokenId;

        // The given creatorId must be the profile id that created the comment.
        require(
            _tokenIdToComment[tokenId].creatorId == updateCommentData.creatorId,
            "Not allow"
        );

        // Check if there is any change.
        require(
            keccak256(abi.encodePacked(updateCommentData.newContentURI)) !=
                keccak256(
                    abi.encodePacked(_tokenIdToComment[tokenId].contentURI)
                ),
            "Nothing change"
        );

        // Update the comment struct.
        _tokenIdToComment[tokenId].contentURI = updateCommentData.newContentURI;

        emit Events.CommentUpdated(
            updateCommentData.tokenId,
            updateCommentData.creatorId,
            msg.sender,
            updateCommentData.newContentURI,
            block.timestamp
        );
    }

    /**
     * @param tokenId {uint256}
     * @param creatorId {uint256}
     * @param _tokenIdToComment - storage mapping
     */
    function _deleteComment(
        uint256 tokenId,
        uint256 creatorId,
        mapping(uint256 => DataTypes.Comment) storage _tokenIdToComment
    ) internal {
        // Remove the struct from the mapping.
        delete _tokenIdToComment[tokenId];

        emit Events.CommentDeleted(
            tokenId,
            creatorId,
            msg.sender,
            block.timestamp
        );
    }
}
