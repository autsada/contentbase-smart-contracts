// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "../libraries/DataTypes.sol";

interface IContentBaseFollowV1 {
    /**
     * An external function to update profile contract address.
     * @dev Make sure to allow only ADMIN_ROLE.
     */
    function updateProfileContract(address newContractAddress) external;

    /**
     * An external function to get the stored profile contract address.
     * @return contractAddress {address}
     */
    function getProfileContract() external view returns (address);

    /**
     * An external function for a profile to follow another profile.
     * @dev The caller must own the given follower id.
     * @dev Use this function for both `follow` and `unfollow`.
     * @dev A Follow NFT will be minted to the caller in the case of `follow`, the existing Follow NFT will be burned in the case of `unfollow`.
     * @param followerId {uint256}
     * @param followeeId {uint256}
     */
    function follow(uint256 followerId, uint256 followeeId) external;

    /**
     * An external function to get `following` and `followers` count of a profile.
     * @param profileId {uint256} - a profile token id
     * @return (followers, following)
     */
    function getFollowCounts(uint256 profileId)
        external
        view
        returns (uint256, uint256);
}
