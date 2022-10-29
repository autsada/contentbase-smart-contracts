// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {DataTypes} from "../../libraries/DataTypes.sol";
import {Constants} from "../../libraries/Constants.sol";

interface IProfileNFT {
    /**
     * An external function to set Follow Contract address.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function setFollowContractAddress(address followAddress) external;

    /**
     * An external function to create Profile NFT.
     * @param createProfileData {struct} - see DataTypes.CreateProfileData struct
     * @return tokenId {uint256}
     */
    function createProfile(
        DataTypes.CreateProfileData calldata createProfileData
    ) external returns (uint256);

    /**
     * An external to update profile image uri.
     * @param updateProfileImageData {struct} - see DataTypes.UpdateProfileImageData struct
     * @return tokenId {uint256}
     */
    function updateProfileImage(
        DataTypes.UpdateProfileImageData calldata updateProfileImageData
    ) external returns (uint256);

    /**
     * An external function to set default profile for a specific address.
     * @param tokenId - a token id
     */
    function setDefaultProfile(uint256 tokenId) external;

    /**
     * An external function to be called when some profile follows other profile.
     * @param followData - see DataTypes.FollowData
     * @return success {bool}
     */
    function follow(DataTypes.FollowData calldata followData)
        external
        returns (bool, uint256);

    /**
     * An external function to unfollow a profile.
     * @param tokenId {uint256} - a follow id
     * @param followerId {uint256} - a profile id that the follow belongs to
     * @return success {bool}
     */
    function unFollow(uint256 tokenId, uint256 followerId)
        external
        returns (bool);

    /**
     * An external function to get address's default profile.
     * @return token {Profile}
     */
    function getDefaultProfile()
        external
        view
        returns (DataTypes.Profile memory);

    /**
     * An external function to get a profile from a given id.
     * @param tokenId {uint256}
     * @return profile {Profile}
     */
    function getProfile(uint256 tokenId)
        external
        view
        returns (DataTypes.Profile memory);

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
