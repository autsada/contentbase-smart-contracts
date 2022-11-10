// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

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
     * @dev use this function for both `like` and `undo like`
     * @param likeData - see DataTypes.LikeData
     */
    function like(DataTypes.LikeData calldata likeData) external payable;

    /**
     * An external function to dislike a publish.
     * @dev use this function for both `dislike` and `undo dislike`
     * @param likeData - see DataTypes.LikeData
     */
    function disLike(DataTypes.LikeData calldata likeData) external;

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
     * An external function to burn a publish token.
     */
    function deletePublish(uint256 tokenId, address creatorId) external;

    /**
     * An external function to check if the publish exists.
     * @param tokenId {uint256}
     * @return exist {bool}
     */
    function publishExist(uint256 tokenId) external view returns (bool);
}
