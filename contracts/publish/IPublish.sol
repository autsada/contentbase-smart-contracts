// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "../../libraries/DataTypes.sol";

interface IContentBasePublish {
    /**
     * An external function to update contract owner address.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     * @param owner - an address of the owner
     */
    function updateContractOwner(address owner) external;

    /**
     * An external function to update profile contract factory.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function updateFactoryContract(address factoryAddress) external;

    /**
     * An external function to update Like contract address.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function updateLikeContract(address contractAddress) external;

    /**
     * An external function to update Comment contract address.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function updateCommentContract(address contractAddress) external;

    /**
     * An external function to withdraw the contract's balance.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function withdraw() external;

    /**
     * An external function to update like fee.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     * @param fee {uint} - a fee to be sent when some profile likes a Publish
     */
    function updateLikeFee(uint256 fee) external;

    /**
     * An external function to update operational fee for the platform.
     * @dev  make sure to add modifier to only ADMIN_ROLE.
     * @param fee - operational fee
     */
    function updatePlatformFee(uint24 fee) external;

    /**
     * An external function to crate Publish NFT.
     * @param createPublishData {struct} - see DataTypes.CreatePublishData struct
     */
    function createPublish(
        DataTypes.CreatePublishData calldata createPublishData
    ) external;

    /**
     * An external function to update Publish NFT.
     * @param updatePublishData {struct} - see DataTypes.UpdatePublishData struct
     */
    function updatePublish(
        DataTypes.UpdatePublishData calldata updatePublishData
    ) external;

    /**
     * An external function to like a publish.
     * @param likeData - see DataTypes.LikeData
     */
    function like(DataTypes.LikeData calldata likeData) external payable;

    /**
     * An external function to comment on a publish.
     * @param createCommentData - see DataTypes.CreateCommentData
     */
    function comment(DataTypes.CreateCommentData calldata createCommentData)
        external;

    /**
     * An external function to update a comment.
     * @param updateCommentData - see DataTypes.UpdateCommentData
     */
    function updateComment(
        DataTypes.UpdateCommentData calldata updateCommentData
    ) external;

    /**
     * An external function to delete a comment.
     * @param tokenId {uint256} - a comment id
     * @param publishId {uint256} - the publish id that the comment is on
     * @param profileAddress {address} - a profile address that created the comment
     * @return success {bool}
     */
    function deleteComment(
        uint256 tokenId,
        uint256 publishId,
        address profileAddress
    ) external returns (bool);

    /**
     * An external function to get a publish struct from a given id.
     * @param tokenId {uint256}
     * @return token {Publish}
     */
    function getPublishById(uint256 tokenId)
        external
        view
        returns (DataTypes.Publish memory);
}
