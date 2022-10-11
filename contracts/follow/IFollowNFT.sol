// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {DataTypes} from "../../libraries/DataTypes.sol";
import {Constants} from "../../libraries/Constants.sol";

interface IFollowNFT {
    /**
     * An external function to set Profile contract.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function setProfileContract(address profileContractAddress) external;

    /**
     * An external function to follow Profile NFT.
     * @dev This funtion will create a Follow NFT.
     * @param createFollowData {struct} - see DataTypes.CreateFollowData struct
     * @return tokenId {uint256}
     */
    function follow(DataTypes.CreateFollowData calldata createFollowData)
        external
        returns (uint256);

    /**
     * An external function to get following count of a Profile NFT.
     * @param profileId {uint256}
     * @return count {uint256}
     */
    function followingCount(uint256 profileId) external view returns (uint256);

    /**
     * An external function to get followers count of a Profile NFT.
     * @param profileId {uint256}
     * @return count {uint256}
     */
    function followersCount(uint256 profileId) external view returns (uint256);

    /**
     * An external function to get Follow structs from a given ids array.
     * @param tokenIds {uint256[]}
     * @return tokens {Follow[]}
     */
    function getFollows(uint256[] calldata tokenIds)
        external
        view
        returns (DataTypes.Follow[] memory);
}
