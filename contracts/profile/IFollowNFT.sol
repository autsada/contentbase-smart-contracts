// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {DataTypes} from "../../libraries/DataTypes.sol";
import {Constants} from "../../libraries/Constants.sol";

interface IFollowNFT {
    /**
     * An external function to set Profile Contract address.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function setProfileContractAddress(address profileAddress) external;

    /**
     * An external function to create a follow NFT.
     * @param owner {address} - the address that create a follow
     * @param followData - see DataTypes.FollowData
     * @return success {bool}
     * @return tokenId {uint256}
     */
    function follow(address owner, DataTypes.FollowData calldata followData)
        external
        returns (bool, uint256);

    /**
     * An external function to delete a follow (unFollow).
     * @param tokenId {uint256} - a follow id
     * @param owner {address} - an owner of the follow
     * @param followerId {uint256} - a follower profile id
     * @return success {bool}
     * @return followeeId {uint256}
     */
    function burn(
        uint256 tokenId,
        address owner,
        uint256 followerId
    ) external returns (bool, uint256);
}
