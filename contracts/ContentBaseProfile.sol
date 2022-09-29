// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {Helpers} from "../libraries/Helpers.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

abstract contract ContentBaseProfile {
    // A public function signature to mint profile nft that to be implemented by the derived contract.
    function createProfile(
        DataTypes.CreateProfileParams calldata createProfileParams
    ) public virtual returns (uint256);

    /**
     * An internal function that actually contains the logic to create a profile.
     * @param owner {address} - an address to be set as an owner of the profile
     * @param profileId {uint256} - an id of to be created profile
     * @param createProfileParams {struct} - refer to DataTypes.CreateProfileParams struct
     * @param _profileIdsByAddress {mapping}
     * @param _profileIdByHandleHash {mapping}
     * @param _profileById {mapping}
     *
     */
    function _createProfile(
        address owner,
        uint256 profileId,
        DataTypes.CreateProfileParams calldata createProfileParams,
        mapping(address => uint256[]) storage _profileIdsByAddress,
        mapping(bytes32 => uint256) storage _profileIdByHandleHash,
        mapping(uint256 => DataTypes.Profile) storage _profileById
    ) internal returns (uint256) {
        // Get the profiles array of the owner.
        DataTypes.Profile[] memory profiles = _fetchProfilesByAddress(
            owner,
            _profileIdsByAddress,
            _profileById
        );

        // Link profile id to handle hash.
        _profileIdByHandleHash[
            Helpers.hashString(createProfileParams.handle)
        ] = profileId;

        // Create a profile struct and assign it to the newProfileId in the mapping.
        _profileById[profileId] = DataTypes.Profile({
            profileId: profileId,
            isDefault: profiles.length > 0 ? false : true, // If it's the user's first profile set to true, otherwise false.
            owner: owner,
            handle: createProfileParams.handle,
            tokenURI: createProfileParams.tokenURI,
            imageURI: createProfileParams.imageURI
        });

        // Push the profile id to user's profile ids array.
        _profileIdsByAddress[owner].push(profileId);

        // Emit creaete profile event.
        emit DataTypes.TokenCreated(profileId, owner);

        return profileId;
    }

    /**
     * A public function signature to fetch profiles of a specific address that will be implemented by the derived contract.
     * @param owner {address} - an address
     */
    function fetchProfilesByAddress(address owner)
        public
        view
        virtual
        returns (DataTypes.Profile[] memory);

    /**
     * A function to fetch profiles of a specific address.
     * @param owner {address} - an address
     * @param _profileIdsByAddress {mapping}
     * @param _profileById {mapping}
     */
    function _fetchProfilesByAddress(
        address owner,
        mapping(address => uint256[]) storage _profileIdsByAddress,
        mapping(uint256 => DataTypes.Profile) storage _profileById
    ) internal view returns (DataTypes.Profile[] memory) {
        // Get the profile ids array of the owner.
        uint256[] memory profileIds = _profileIdsByAddress[owner];

        // Create a profiles array in memory with the fix size of ids array length.
        DataTypes.Profile[] memory profiles = new DataTypes.Profile[](
            profileIds.length
        );

        // Loop through the ids array and get the profile for each id.
        for (uint256 i = 0; i < profileIds.length; i++) {
            profiles[i] = _profileById[profileIds[i]];
        }

        return profiles;
    }

    /**
     * A public function signature to update profile image that will be implemented by the derived contract.
     * @param profileId {uint256} - A token id of the profile to be updated
     */
    function updateProfileImage(
        uint256 profileId,
        DataTypes.UpdateProfileParams calldata updateProfileParams
    ) public virtual returns (uint256);

    /**
     * An interal function to update profile image.
     * @param owner {address} - An owner address of the profile
     * @param profileId {uint256} - An id of the profile to be updated
     * @param updateProfileParams {struct} - refer to DataTypes.UpdateProfileParams
     * @param _profileById {mapping}
     */
    function _updateProfileImage(
        address owner,
        uint256 profileId,
        DataTypes.UpdateProfileParams calldata updateProfileParams,
        mapping(uint256 => DataTypes.Profile) storage _profileById
    ) internal returns (uint256) {
        // Validate if the tokenURI changed.
        // Don't have to validate the imageURI as it might not be changed even the image changed.
        bytes32 oldTokenURIHash = keccak256(
            bytes(_profileById[profileId].tokenURI)
        );

        require(
            oldTokenURIHash != Helpers.hashString(updateProfileParams.tokenURI),
            "Nothing change"
        );

        // Update tokenURI and imageURI.
        _profileById[profileId].tokenURI = updateProfileParams.tokenURI;
        _profileById[profileId].imageURI = updateProfileParams.imageURI;

        // Emit update profile event.
        emit DataTypes.TokenUpdated(profileId, owner);

        return profileId;
    }
}
