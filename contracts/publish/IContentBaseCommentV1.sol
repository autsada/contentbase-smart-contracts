// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "../libraries/DataTypes.sol";

interface IContentBaseCommentV1 {
    /**
     * An external function to update the profile contract address for use to communicate with the profile contract.
     * @dev  make sure to add modifier to only ADMIN_ROLE.
     * @param contractAddress {address} - the profile contract address
     */
    function updateProfileContract(address contractAddress) external;

    /**
     * An external function to get the stored profile contract address.
     * @return contractAddress {address}
     */
    function getProfileContract() external view returns (address);

    /**
     * An external function to update the publish contract address for use to communicate with the publish contract.
     * @dev  make sure to add modifier to only ADMIN_ROLE.
     * @param contractAddress {address} - the publish contract address
     */
    function updatePublishContract(address contractAddress) external;

    /**
     * An external function to get the stored publish contract address.
     * @return contractAddress {address}
     */
    function getPublishContract() external view returns (address);

    /**
     * An external function to comment on a publish (and mint Comment NFT).
     * @param createCommentOnPublishData - see DataTypes.CreateCommentOnPublishData
     */
    function commentOnPublish(
        DataTypes.CreateCommentOnPublishData calldata createCommentOnPublishData
    ) external;

    /**
     * An external function to comment on a comment (and mint Comment NFT).
     * @param createCommentOnCommentData - see DataTypes.CreateCommentOnCommentData
     */
    function commentOnComment(
        DataTypes.CreateCommentOnCommentData calldata createCommentOnCommentData
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

    /**
     * An external function to get a comment struct by provided id.
     * @param tokenId {uint256} - a token id of the publish.
     * @return comment {Comment struct}
     */
    function getCommentById(uint256 tokenId)
        external
        view
        returns (DataTypes.Comment memory);
}
