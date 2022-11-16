// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "../libraries/DataTypes.sol";

interface IContentBaseProfileV1 {
    /**
     * An external function to create a ContentBase profile. This function is to be called by EOA addresses to create their profiles.
     * @param handle {string} - the handle of a profile.
     * @param imageURI {string} - the imageURI of a profile, this can be empty as profiles can update their profile images later.
     * @param originalHandle {string} - the unformatted handle used to display on the UI.
     */
    function createProfile(
        string calldata handle,
        string calldata imageURI,
        string calldata originalHandle
    ) external;

    /**
     * An external to update a profile image uri. The function must only be called by an owner of the profile.
     * @param tokenId {uint256} - a profile token id.
     * @param newImageURI {string} - a new image uri.
     */
    function updateProfileImage(uint256 tokenId, string calldata newImageURI)
        external;

    /**
     * An external function to set a default profile of the caller (EOA).
     * @param handle {string} - a handle of the profile to be set as the default.
     */
    function setDefaultProfile(string calldata handle) external;

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
     * An external function to validate handle - validate length, special characters and uniqueness.
     * @param handle {string} - a handle to be validated/
     * @return valid {bool} - `true` of the given handle is valid
     */
    function validateHandle(string calldata handle)
        external
        view
        returns (bool);

    /**
     * A function to get the default profile of the caller.
     * @return tokenId {uint256}
     * @return handle {string}
     */
    function getDefaultProfile()
        external
        view
        returns (uint256 tokenId, DataTypes.Profile memory);

    /**
     * An external function to get profile owner address.
     * @param profileId {uint256}
     * @return owner {address}
     */
    function profileOwner(uint256 profileId) external view returns (address);
}
