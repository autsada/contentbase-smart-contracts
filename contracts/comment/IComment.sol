// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {DataTypes} from "../../libraries/DataTypes.sol";

interface IContentBaseComment {
    /**
     * An external function to update profile contract factory.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function updateFactoryContract(address factoryAddress) external;

    /**
     * An external function to update Publish Contract address.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function updatePublishContract(address publishAddress) external;

    /**
     * An external function to create a comment NFT.
     * @param createCommentData - see DataTypes.CreateCommentData
     */
    function createComment(
        DataTypes.CreateCommentData calldata createCommentData
    ) external;

    /**
     * An external function to update a comment
     * @param updateCommentData - see DataTypes.CreateCommentData
     */
    function updateComment(
        DataTypes.UpdateCommentData calldata updateCommentData
    ) external;

    /**
     * An external function to delete a comment.
     * @param tokenId {uint256} - a comment id
     * @param publishId {uint256} - the publish id that the comment is on
     * @param profileAddress {address} - a profile address that created the comment
     */
    function deleteComment(
        uint256 tokenId,
        uint256 publishId,
        address profileAddress
    ) external;

    /**
     * An external function to like a comment.
     * @param likeData - see DataTypes.LikeData
     */
    function likeComment(DataTypes.LikeData calldata likeData) external;

    /**
     * An external function to dislike a publish.
     * @dev use this function for both `dislike` and `undo dislike`
     * @param likeData - see DataTypes.LikeData
     */
    function disLikeComment(DataTypes.LikeData calldata likeData) external;

    /**
     * An external function to get a comment from the provided id.
     * @param tokenId {uint256} - a comment id
     * @return comment {DataTypes.Comment}
     */
    function getComment(uint256 tokenId)
        external
        view
        returns (DataTypes.Comment memory);
}
