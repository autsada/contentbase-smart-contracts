// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {Helpers} from "../libraries/Helpers.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

abstract contract ContentBaseProfile {
    event ProfileCreated(DataTypes.Token token, address owner);
    event ProfileImageUpdated(DataTypes.Token token, address owner);
    event DefaultProfileUpdated(DataTypes.Token token, address owner);

    /**
     * An external function signature to mint a profile nft that to be implemented by the derived contract.
     * @param uri {string} - a uri of the token's metadata file
     * @param createProfileData {struct} - refer to DataTypes.CreateProfileData struct
     */
    function createProfile(
        string calldata uri,
        DataTypes.CreateProfileData calldata createProfileData
    ) external virtual returns (uint256);

    /**
     * An internal function that contains the logic to create a profile.
     * @param owner {address} - an address to be set as an owner of the profile
     * @param tokenId {uint256} - an id of the token
     * @param createProfileData {struct} - refer to DataTypes.CreateProfileData struct
     * @param _profileIdByHandleHash {mapping}
     * @param _tokenById {mapping}
     *
     */
    function _createProfile(
        address owner,
        uint256 tokenId,
        DataTypes.CreateProfileData calldata createProfileData,
        mapping(bytes32 => uint256) storage _profileIdByHandleHash,
        mapping(uint256 => DataTypes.Token) storage _tokenById
    ) internal returns (uint256) {
        // Store profile id (token id) to handle hash.
        _profileIdByHandleHash[
            Helpers.hashHandle(createProfileData.handle)
        ] = tokenId;

        // Create a new token struct in memory
        DataTypes.Token memory newProfile = DataTypes.Token({
            tokenId: tokenId,
            associatedId: tokenId,
            owner: owner,
            tokenType: DataTypes.TokenType.Profile,
            visibility: DataTypes.Visibility.UNSET,
            handle: createProfileData.handle,
            imageURI: createProfileData.imageURI,
            contentURI: ""
        });

        // Store the created profile in the mapping
        _tokenById[tokenId] = newProfile;

        // Emit create profile event.
        emit ProfileCreated(newProfile, owner);

        return tokenId;
    }

    /**
     * An external function signature to update profile image that will be implemented by the derived contract.
     * @param tokenId {uint256} - an id of the token to be updated
     * @param uri {string} - a new uri of the token's metadata
     * @param imageURI {string} - a new image uri
     */
    function updateProfileImage(
        uint256 tokenId,
        string calldata uri,
        string calldata imageURI
    ) external virtual returns (uint256);

    /**
     * An interal function to update profile image.
     * @param owner {address}
     * @param tokenId {uint256} - An id of the token to be updated
     * @param imageURI {string} - new image uri
     * @param _tokenById {mapping}
     *
     */
    function _updateProfileImage(
        address owner,
        uint256 tokenId,
        string calldata imageURI,
        mapping(uint256 => DataTypes.Token) storage _tokenById
    ) internal returns (uint256) {
        // Update the profile
        _tokenById[tokenId].imageURI = imageURI;

        // Emit update profile event.
        emit ProfileImageUpdated(_tokenById[tokenId], owner);

        return tokenId;
    }

    /**
     * An external function signature to set profile as default that will be implemented by the derived contract.
     * @param tokenId {uint256}
     */
    function setDefaultProfile(uint256 tokenId) external virtual;

    /**
     * An internal function that contain the logic to set profile as default
     * @param owner {address}
     * @param tokenId {uint256}
     * @param _defaultProfileIdByAddress {mapping}
     * @param _tokenById {mapping}
     */
    function _setDefaultProfile(
        address owner,
        uint256 tokenId,
        mapping(address => uint256) storage _defaultProfileIdByAddress,
        mapping(uint256 => DataTypes.Token) storage _tokenById
    ) internal {
        // Update the mapping
        _defaultProfileIdByAddress[owner] = tokenId;

        // Emit an event
        emit DefaultProfileUpdated(_tokenById[tokenId], owner);
    }
}
