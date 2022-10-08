// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {DataTypes} from "../../libraries/DataTypes.sol";
import {Constants} from "../../libraries/Constants.sol";

interface IPublishNFT {
    /**
     * An external function to set Profile contract.
     * @dev make sure to allow set modifier to only ADMIN_ROLE.
     */
    function setProfileContract(address profileContractAddress) external;

    /**
     * An external function that will be called to crate Publish NFT.
     * @dev make sure to allow call only from Profile contract.
     * @param createPublishData {struct} - refer to DataTypes.CreatePublishData struct
     * @return token {PublishStruct}
     *
     */
    function createPublish(
        DataTypes.CreatePublishData calldata createPublishData
    ) external returns (DataTypes.PublishStruct memory);

    /**
     * An external function to get Publish NFTs by ids.
     * @param tokenIds {uint256[]} - an array of token ids
     * @return tokens {PublishStruct[]} - an array of Publish structs
     */
    function publishesByIds(uint256[] calldata tokenIds)
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
    function totalPublishes() external view returns (uint256);
}
