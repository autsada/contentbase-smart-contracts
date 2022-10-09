// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {DataTypes} from "../../libraries/DataTypes.sol";
import {Constants} from "../../libraries/Constants.sol";

interface IPublishNFT {
    /**
     * An external function to set Profile contract.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function setProfileContract(address profileContractAddress) external;

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
     * An external function to get user's Publish NFTs.
     * @param tokenIds {uint256[]} - an array of token ids
     * @return tokens {PublishStruct[]} - an array of Publish structs
     */
    function ownerPublishes(uint256[] calldata tokenIds)
        external
        view
        returns (DataTypes.PublishStruct[] memory);

    /**
     * An external function to get Publish NFTs by ids.
     * @param tokenIds {uint256[]} - an array of token ids
     * @return tokens {PublishStruct[]} - an array of Publish structs
     */
    function getPublishes(uint256[] calldata tokenIds)
        external
        view
        returns (DataTypes.PublishStruct[] memory);

    /**
     * An external function to get a Publish NFT.
     * @param tokenId {uint256}
     * @return token {PublishStruct}
     */
    function publishById(uint256 tokenId)
        external
        view
        returns (DataTypes.PublishStruct memory);

    /**
     * An external function to get total NFTs count.
     * @return total {uint256} - total number of NFTs already minted
     */
    function publishesCount() external view returns (uint256);
}
