// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {DataTypes} from "../../libraries/DataTypes.sol";
import {Constants} from "../../libraries/Constants.sol";

interface ICommentNFT {
    /**
     * An external function to set Publish Contract address.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function setPublishContractAddress(address publishAddress) external;

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
     * @param owner {address} - an owner of the comment
     * @param profileId {uint256} - a profile that the comment belongs to
     * @return success {bool}
     */
    function burn(
        uint256 tokenId,
        address owner,
        uint256 profileId
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
