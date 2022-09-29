// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

library DataTypes {
    event TokenCreated(uint256 tokenId, address owner);
    event TokenUpdated(uint256 tokenId, address owner);

    /**
     * A struct containing profile data.
     * @param  profileId {number} - a token id
     * @param isDefault {boolean} - to identify if the profile is a default
     * @param owner {address} - an address that owns the profile
     * @param handle {string} - a user given name which must be unique
     * @param tokenURI {string} - a url point the metadata.json containing the token data consist of:
     * - name {string} - "Content Base Profile"
     * - description {string} - "A profile of ${handle}", handle is the name who owns the profile
     * - image {string} - An ipfs uri point to an image stored on ipfs
     * - properties {object} - Other additional information of the token
     * @param imageURI {string} - a url point to an image stored on off-chain storage, can be empty string
     */
    struct Profile {
        uint256 profileId;
        bool isDefault;
        address owner;
        string handle;
        string tokenURI;
        string imageURI;
    }

    /**
     * @dev A struct containing the required parameters for the "createProfile" function.
     * @param handle {string} - a user given name which must be unique
     * @param tokenURI {string} - a url point the metadata.json containing the token data consist of:
     * - name {string} - "Content Base Profile"
     * - description {string} - "A profile of ${handle}", handle is the name who owns the profile
     * - image {string} - An ipfs uri point to an image stored on ipfs
     * - properties {object} - Other additional information of the token
     * @param imageURI {string} - a url point to an image stored on off-chain storage, can be empty string
     */
    struct CreateProfileParams {
        string handle;
        string tokenURI;
        string imageURI;
    }

    /**
     * @dev A struct containing the required parameters for the "updateProfileImage" function.
     * @param tokenURI {string} - a url point the metadata.json containing the token data consist of:
     * - name {string} - "Content Base Profile"
     * - description {string} - "A profile of ${handle}", handle is the name who owns the profile
     * - image {string} - An ipfs uri point to an image stored on ipfs
     * - properties {object} - Other additional information of the token
     * @param imageURI {string} - a url point to an image stored on off-chain storage - must be NON-empty
     */
    struct UpdateProfileParams {
        string tokenURI;
        string imageURI;
    }
}
