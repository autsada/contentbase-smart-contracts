// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "../libraries/DataTypes.sol";

interface IContentBaseCommentV1 {
    /**
     * An external function to update profile contract address for use to communicate with the profile contract.
     * @dev  make sure to add modifier to only ADMIN_ROLE.
     * @param contractAddress {address} - the profile contract address
     */
    function updateProfileContract(address contractAddress) external;

    /**
     * An external function to update publish contract address for use to communicate with the publish contract.
     * @dev  make sure to add modifier to only ADMIN_ROLE.
     * @param contractAddress {address} - the publish contract address
     */
    function updatePublishContract(address contractAddress) external;

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
     * @param creatorId {uint256} - a profile token id that created the comment
     */
    function deleteComment(uint256 tokenId, uint256 creatorId) external;

    /**
     * An external function to like a comment.
     * @dev Use this function for both `like` and `unlike`.
     * @dev No Like NFT involve for this function.
     * @param commentId {uint256}
     * @param profileId {uint256}
     */
    function likeComment(uint256 commentId, uint256 profileId) external;

    /**
     * An external function to dislike a comment.
     * @dev Use this function for both `dislike` and `undoDislike`.
     * @dev No Like NFT involve for this function.
     * @param commentId {uint256}
     * @param profileId {uint256}
     */
    function disLikeComment(uint256 commentId, uint256 profileId) external;
}
