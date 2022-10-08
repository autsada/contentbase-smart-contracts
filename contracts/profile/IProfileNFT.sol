// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {DataTypes} from "../../libraries/DataTypes.sol";
import {Constants} from "../../libraries/Constants.sol";

interface IProfileNFT {
    /**
     * An external function to set Publish contract for use to create Publish NFT.
     * @dev only allow ADMIN_ROLE
     */
    function setPublishContract(address publishContractAddress) external;

    /**
     * An external function to create Profile NFT.
     * @param createProfileData {struct} - refer to DataTypes.CreateProfileData struct
     *
     */
    function createProfile(
        DataTypes.CreateProfileData calldata createProfileData
    ) external returns (uint256);

    /**
     * An external to update profile image.
     * @param updateProfileImageData {struct} - refer to DataTypes.UpdateProfileImageData struct
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
     * An external function to list user's profiles.
     * @param tokenIds {uint256[]} - An array of token ids, limit to 10 ids
     */
    function ownerProfiles(uint256[] calldata tokenIds)
        external
        view
        returns (DataTypes.ProfileStruct[] memory);

    /**
     * An external function to get user's default profile.
     */
    function defaultProfile()
        external
        view
        returns (DataTypes.ProfileStruct memory);

    /**
     * An external function get profile struct by id.
     */
    function profileById(uint256 tokenId)
        external
        view
        returns (DataTypes.ProfileStruct memory);

    /**
     * An external function to validate handle - validate length, special characters and uniqueness.
     * @param handle {string}
     */
    function validateHandle(string calldata handle)
        external
        view
        returns (bool);
}
