// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

library DataTypes {
    /**
     * A struct containing profile data.
     * @param  profileId {number} - a token id
     * @param isDefault {boolean} - to identify if the profile is a default
     * @param owner {address} - an address that owns the profile
     * @param handle {string} - a user given name which must be unique
     * @param imageURI {string} - a url of the profile image stored on cloud storage
     *
     */
    struct Profile {
        uint256 profileId;
        bool isDefault;
        address owner;
        string handle;
        string imageURI;
    }

    /**
     * A struct containing the required parameters for the "createProfile" function.
     * @param handle {string} - a user given name which must be unique
     * @param imageURI {string} - a uri of the profile image
     * @param tokenURI {string} - a uri of token's metadata
     */
    struct CreateProfileParams {
        string handle;
        string imageURI;
    }

    /**
     * A struct containing the required parameters for the "createProfile" function.
     * @param profileId {number} - a token id to be updated
     * @param imageURI {string} - a uri of the profile image
     * @param tokenURI {string} - a uri of token's metadata
     */
    struct UpdateProfileImageParams {
        uint256 profileId;
        string imageURI;
        string tokenURI;
    }

    struct Publish {
        uint256 publishId;
        string owner;
        string handle;
        string thumbnailURI;
        string contentURI;
    }
}
