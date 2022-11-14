// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "./DataTypes.sol";
import {Events} from "./Events.sol";
import {Helpers} from "./Helpers.sol";

library ProfileLogic {
    /**
     * @param tokenId {uint256} - A Profile token id
     * @param handle {string} - a profile handle
     * @param imageURI {string} - a profile image uri
     * @param _tokenIdToProfile {storage mapping}
     * @param _handleHashToProfileId {storage mapping}
     * @param _ownerToDefaultProfileId {storage mapping}
     */
    function _createProfile(
        uint256 tokenId,
        string calldata handle,
        string calldata imageURI,
        mapping(uint256 => DataTypes.Profile) storage _tokenIdToProfile,
        mapping(bytes32 => uint256) storage _handleHashToProfileId,
        mapping(address => uint256) storage _ownerToDefaultProfileId
    ) internal {
        // Update handle hash to profile id mapping.
        _handleHashToProfileId[Helpers.hashHandle(handle)] = tokenId;

        // Set the default profile if not already.
        if (_ownerToDefaultProfileId[msg.sender] == 0) {
            _ownerToDefaultProfileId[msg.sender] = tokenId;
        }

        // Create a new profile struct and store it in the state.
        _tokenIdToProfile[tokenId] = DataTypes.Profile({
            owner: msg.sender,
            handle: handle,
            imageURI: imageURI,
            followers: 0,
            following: 0
        });

        // Emit a profile created event.
        emit Events.ProfileCreated(
            tokenId,
            msg.sender,
            handle,
            imageURI,
            _ownerToDefaultProfileId[msg.sender] == tokenId,
            block.timestamp
        );
    }

    /**
     * @param tokenId {uint256}
     * @param newImageURI {string}
     * @param profileOwner {address}
     * @param _tokenIdToProfile {storage mapping}
     */
    function _updateProfileImage(
        uint256 tokenId,
        string calldata newImageURI,
        address profileOwner,
        mapping(uint256 => DataTypes.Profile) storage _tokenIdToProfile
    ) internal {
        // Update the profile struct.
        _tokenIdToProfile[tokenId].imageURI = newImageURI;

        // Emit an event.
        emit Events.ProfileImageUpdated(
            tokenId,
            profileOwner,
            newImageURI,
            block.timestamp
        );
    }

    /**
     * @param profileId {uint256}
     * @param _ownerToDefaultProfileId {storage mapping}
     */
    function _setDefaultProfile(
        uint256 profileId,
        mapping(address => uint256) storage _ownerToDefaultProfileId
    ) internal {
        // Update the default profile mapping.
        _ownerToDefaultProfileId[msg.sender] = profileId;

        // Emit a set default profile event.
        emit Events.DefaultProfileUpdated(
            profileId,
            msg.sender,
            block.timestamp
        );
    }
}
