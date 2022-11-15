// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "../libraries/DataTypes.sol";

interface IContentBasePublishV1 {
    /**
     * An external function to update the platform owner address.
     * @dev  make sure to add modifier to only ADMIN_ROLE.
     * @param ownerAddress {address} - the contract owner address
     */
    function updatePlatformOwner(address ownerAddress) external;

    /**
     * An external function to update the profile contract address for use to communicate with the profile contract.
     * @dev  make sure to add modifier to only ADMIN_ROLE.
     * @param contractAddress {address} - the profile contract address
     */
    function updateProfileContract(address contractAddress) external;

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
    function updatePlatformFee(uint256 fee) external;

    /**
     * An external function to withdraw the contract's balance.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function withdraw() external;

    /**
     * An external function to create Publish NFT.
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
     * An external function to burn a publish token.
     * @param tokenId {uint256} - a publish token id
     * @param creatorId {uint256} - the profile token id that created the publish
     */
    function deletePublish(uint256 tokenId, uint256 creatorId) external;

    /**
     * An external function to handle `like` and `unlike` logic for publish like.
     * @dev The caller is required to send a like fee so this function must be payable.
     * @param publishId {uint256} - a publish token id to be liked.
     * @param profileId {uint256} - a profile token id that performs like.
     */
    function likePublish(uint256 publishId, uint256 profileId) external payable;

    /**
     * An external function to handle `dislike` and `undoDislike` logic for publish like.
     * @param publishId {uint256} - a publish token id to be liked.
     * @param profileId {uint256} - a profile token id that performs like.
     */
    function disLikePublish(uint256 publishId, uint256 profileId) external;

    /**
     * An external function to get a publish struct by provided id.
     * @param tokenId {uint256} - a token id of the publish.
     * @return publish {Publish struct}
     */
    function getPublishById(uint256 tokenId)
        external
        view
        returns (DataTypes.Publish memory);

    /**
     * An external function to check if the publish token exists.
     * @param publishId {uint256}
     * @return exist {bool}
     */
    function publishExists(uint256 publishId) external view returns (bool);
}