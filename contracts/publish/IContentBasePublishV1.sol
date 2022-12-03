// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "../libraries/DataTypes.sol";

interface IContentBasePublishV1 {
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
     * An external function to get a publish struct by provided id.
     * @param tokenId {uint256} - a token id of the publish.
     * @return publish {Publish struct}
     */
    function getPublishById(uint256 tokenId)
        external
        view
        returns (DataTypes.Publish memory);

    /**
     * An external function to check if a given publish id exists.
     * @param publishId {uint256}
     * @return exist {bool}
     */
    function publishExist(uint256 publishId) external view returns (bool);

    /**
     * An external function to get the publish owner address.
     * @param publishId {uint256}
     * @return owner {address}
     */
    function publishOwner(uint256 publishId) external view returns (address);
}
