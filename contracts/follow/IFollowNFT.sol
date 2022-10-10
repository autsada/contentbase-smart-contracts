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
     * An external function to follow other profile, this funtion will create a Follow NFT.
     * @param createFollowData {struct} - see DataTypes.CreateFollowData struct
     * @return tokenId {uint256}
     */
    function follow(DataTypes.CreateFollowData calldata createFollowData)
        external
        returns (uint256);

    /**
     * An external function to unfollow other profile, this funtion will burn a Follow NFT.
     * @param tokenId {uint256} - a Follow NFT token id
     * @return success {boolean}
     */
    function unFollow(uint256 tokenId) external returns (bool);

    /**
     * An external function to get follower count of a specific profile id.
     * @param profileId {uint256} - a token id of the Profile NFT
     * @return count {uint256}
     */
    function followerByProfile(uint256 profileId)
        external
        view
        returns (uint256);

    /**
     * An external function to get following count of a specific profile id.
     * @param profileId {uint256} - a token id of the Profile NFT
     * @return count {uint256}
     */
    function followingByProfile(uint256 profileId)
        external
        view
        returns (uint256);
}
