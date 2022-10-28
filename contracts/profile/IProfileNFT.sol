// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {DataTypes} from "../../libraries/DataTypes.sol";
import {Constants} from "../../libraries/Constants.sol";

interface IProfileNFT {
    /**
     * An external function to set Follow contract address.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function setFollowContractAddress(address followContractAddress) external;

    /**
     * An external function to create Profile NFT.
     * @param createProfileData {struct} - refer to DataTypes.CreateProfileData struct
     * @return tokenId {uint256}
     */
    function createProfile(
        DataTypes.CreateProfileData calldata createProfileData
    ) external returns (uint256);

    /**
     * An external to update profile image.
     * @param updateProfileImageData {struct} - refer to DataTypes.UpdateProfileImageData struct
     * @return tokenId {uint256}
     */
    function updateProfileImage(
        DataTypes.UpdateProfileImageData calldata updateProfileImageData
    ) external returns (uint256);

    /**
     * An external function to set default profile.
     * @param tokenId - a token id
     */
    function setDefaultProfile(uint256 tokenId) external;

    /**
     * An external function to get user's default profile.
     * @return token {Profile}
     */
    function defaultProfile() external view returns (DataTypes.Profile memory);

    /**
     * An external function to update following and followers of the follower and followee when a profile follows another profile.
     * @dev must be only called from the Follow Contract.
     * @param followerId {uint256} - a profile token id that follows another profile (followeeId)
     * @param followeeId {uint256} - a profile token id that has been followed by another profile (followerId)
     */
    function follow(uint256 followerId, uint256 followeeId)
        external
        returns (bool);

    /**
     * An external function to update following and followers of the follower and followee when a profile unfollows one of their following.
     * @dev must be only called from the Follow Contract.
     * @param followerId {uint256} - a profile token id that unfollows another profile (followeeId)
     * @param followeeId {uint256} - a profile token id that has been unfollowed by another profile (followerId)
     */
    function unFollow(uint256 followerId, uint256 followeeId)
        external
        returns (bool);

    /**
     * An external function to get total profiles count.
     * @return count {uint256}
     */
    function totalProfiles() external view returns (uint256);

    /**
     * An external function to get a Profile NFT owner.
     * @param tokenId {uint256} - a token id of the Profile NFT
     * @return owner {address}
     */
    function ownerOfProfile(uint256 tokenId) external view returns (address);

    /**
     * An external function to check if profile exist.
     * @dev use this function when want to check if profile exists in other contracts.
     * @param tokenId {uint256} - a token id of the Profile NFT
     * @return boolean
     */
    function exists(uint256 tokenId) external view returns (bool);

    /**
     * An external function to validate handle - validate length, special characters and uniqueness.
     * @param handle {string}
     * @return boolean
     */
    function validateHandle(string calldata handle)
        external
        view
        returns (bool);
}
