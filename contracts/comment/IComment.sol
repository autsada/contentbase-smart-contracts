// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "../../libraries/DataTypes.sol";

interface IContentBaseComment {
    /**
     * An external function to update Publish Contract address.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function updatePublishContract(address publishAddress) external;

    /**
     * An external function to create a comment NFT.
     * @param owner {address} - the address that create a comment
     * @param createCommentData - see DataTypes.CreateCommentData
     * @return success {bool}
     * @return tokenId {uint256}
     */
    function createComment(
        address owner,
        DataTypes.CreateCommentData calldata createCommentData
    ) external returns (bool, uint256);

    /**
     * An external function to update a comment.
     * @param owner {address} - the address that create a comment
     * @param updateCommentData - see DataTypes.CreateCommentData
     * @return success {bool}
     */
    function updateComment(
        address owner,
        DataTypes.UpdateCommentData calldata updateCommentData
    ) external returns (bool);

    /**
     * An external function to delete a comment.
     * @param tokenId {uint256} - a comment id
     * @param publishId {uint256} - the publish id that the comment is on
     * @param owner {address} - an EOA that owns the comment
     * @param profileAddress {address} - a profile address that created the comment
     * @return success {bool}
     */
    function burn(
        uint256 tokenId,
        uint256 publishId,
        address owner,
        address profileAddress
    ) external returns (bool);

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