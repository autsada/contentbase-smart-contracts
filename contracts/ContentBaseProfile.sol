// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {Helpers} from "../libraries/Helpers.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

abstract contract ContentBaseProfile {
    event ProfileCreated(uint256 tokenId, bool isDefault, address owner);
    event ProfileImageUpdated(uint256 tokenId, string imageURI, address owner);
    event DefaultProfileUpdated(uint256 tokenId, address owner);

    /**
     * A public function signature to mint profile nft that to be implemented by the derived contract.
     */
    function createProfile(
        string calldata tokenURI,
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
        // Store profile id to handle hash.
        _profileIdByHandleHash[
            Helpers.hashString(createProfileParams.handle)
        ] = profileId;

        // Create a profile struct in memory
        DataTypes.Profile memory profile = DataTypes.Profile({
            profileId: profileId,
            isDefault: _profileIdsByAddress[owner].length == 0 ? true : false, // If it's user's first profile set to true, otherwise false.
            owner: owner,
            handle: createProfileParams.handle,
            imageURI: createProfileParams.imageURI
        });

        // Store the created profile in mapping
        _profileById[profileId] = profile;

        // Push the profile id to user's profile ids array.
        _profileIdsByAddress[owner].push(profileId);

        // Emit create profile event.
        emit ProfileCreated(profileId, profile.isDefault, owner);

        return profileId;
    }

    /**
     * A public function signature to update profile image that will be implemented by the derived contract.
     * @param updateProfileImageParams - refer to DataTypes.UpdateProfileImageParams
     */
    function updateProfileImage(
        DataTypes.UpdateProfileImageParams calldata updateProfileImageParams
    ) public virtual returns (uint256);

    /**
     * An interal function to update profile image.
     * @param owner {address} - An owner address of the profile
     * @param profileId {uint256} - An id of the profile to be updated
     * @param imageURI {string} - new image uri
     * @param _profileById {mapping}
     *
     */
    function _updateProfileImage(
        address owner,
        uint256 profileId,
        string calldata imageURI,
        mapping(uint256 => DataTypes.Profile) storage _profileById
    ) internal returns (uint256) {
        // Update the profile
        _profileById[profileId].imageURI = imageURI;

        // Emit update profile event.
        emit ProfileImageUpdated(
            profileId,
            _profileById[profileId].imageURI,
            owner
        );

        return profileId;
    }

    /**
     * A public function signature to set profile as default that will be implemented by the derived contract.
     * @param profileId {uint256}
     */
    function setDefaultProfile(uint256 profileId) public virtual;

    /**
     * An internal function that contain the logic to set profile as default
     * @param owner {address}
     * @param profileId {uint256}
     * @param _profileIdsByAddress {mapping}
     * @param _profileById {mapping}
     */
    function _setDefaultProfile(
        address owner,
        uint256 profileId,
        mapping(address => uint256[]) storage _profileIdsByAddress,
        mapping(uint256 => DataTypes.Profile) storage _profileById
    ) internal {
        // Get profile ids array of the owner
        uint256[] memory profileIds = _profileIdsByAddress[owner];

        // Loop through the ids array and update isDefault field
        for (uint256 i = 0; i < profileIds.length; i++) {
            if (profileId == profileIds[i]) {
                // This is the id to be set as default
                _profileById[profileId].isDefault = true;
            } else {
                // Other ids to be set as false
                _profileById[profileIds[i]].isDefault = false;
            }
        }

        emit DefaultProfileUpdated(profileId, owner);
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
}
