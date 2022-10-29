// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {DataTypes} from "../../libraries/DataTypes.sol";
import {Constants} from "../../libraries/Constants.sol";

interface IPublishNFT {
    /**
     * An external function to set Profile contract address.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function setProfileContractAddress(address profileContractAddress) external;

    /**
     * An external function to set Like contract address.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function setLikeContractAddress(address likeContractAddress) external;

    /**
     * An external function to set Comment contract address.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function setCommentContractAddress(address commentContractAddress) external;

    /**
     * An external function to set contract owner address.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     * @param owner - an address of the owner
     */
    function setContractOwner(address owner) external;

    /**
     * An external function to get contract owner address.
     * @return owner {address}
     */
    function getContractOwner() external view returns (address);

    /**
     * An external function to withdraw the contract's balance.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function withdraw() external;

    /**
     * An external function to set like fee.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     * @param fee {uint} - a fee to be sent when some profile likes a Publish
     */
    function setLikeFee(uint fee) external;

    /**
     * An external function to set operational fee for the platform.
     * @dev  make sure to add modifier to only ADMIN_ROLE.
     * @param fee - operational fee
     */
    function setPlatformFee(uint fee) external;

    /**
     * An external function to crate Publish NFT.
     * @param createPublishData {struct} - see DataTypes.CreatePublishData struct
     * @return tokenId {uint256}
     */
    function createPublish(
        DataTypes.CreatePublishData calldata createPublishData
    ) external returns (uint256);

    /**
     * An external function to update Publish NFT.
     * @param updatePublishData {struct} - see DataTypes.UpdatePublishData struct
     */
    function updatePublish(
        DataTypes.UpdatePublishData calldata updatePublishData
    ) external returns (uint256);

    /**
     * An external function to like a publish.
     * @param likeData - see DataTypes.LikeData
     * @return success {bool}
     */
    function like(DataTypes.LikeData calldata likeData)
        external
        payable
        returns (bool);

    /**
     * An external function to unlike a publish.
     * @param unLikeData - see DataTypes.UnLikeData
     * @return success {bool}
     */
    function unLike(DataTypes.UnLikeData calldata unLikeData)
        external
        returns (bool);

    /**
     * An external function to comment on a publish.
     * @param createCommentData - see DataTypes.CreateCommentData
     * @return commentId {uint256}
     */
    function comment(DataTypes.CreateCommentData calldata createCommentData)
        external
        returns (uint256);

    /**
     * An external function to update a comment.
     * @param updateCommentData - see DataTypes.UpdateCommentData
     * @return success {bool}
     */
    function updateComment(
        DataTypes.UpdateCommentData calldata updateCommentData
    ) external returns (bool);

    /**
     * An external function to delete a comment.
     * @param tokenId {uint256} - a comment id
     * @param profileId {uint256} - a profile that the comment belongs to
     * @return success {bool}
     */
    function deleteComment(uint256 tokenId, uint256 profileId)
        external
        returns (bool);

    /**
     * An external function to get a publish struct from a given id.
     * @param tokenId {uint256}
     * @return token {Publish}
     */
    function getPublishById(uint256 tokenId)
        external
        view
        returns (DataTypes.Publish memory);

    /**
     * An external function to get total NFTs count.
     * @return total {uint256} - total number of NFTs already minted
     */
    function publishesCount() external view returns (uint256);
}
