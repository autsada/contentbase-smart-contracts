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

    /**
     * Publish's category
     * @dev when a pubish is created, it must be classified to at least one category and at most 3 categories
     */
    enum Category {
        Music,
        Entertainment,
        Sports,
        Food,
        Travel,
        Gaming,
        News,
        Animals,
        Education,
        Technology,
        LifeStyle,
        Vehicles,
        Children,
        Other
    }

    /**
     * Publis's visibility
     */
    enum Visibility {
        OFF,
        ON
    }

    /**
     * A struct containing publish struct data.
     * @param publishId {number} - a token id
     * @param owner {address} - an address that owns the publish
     * @param categories {enum[]} - a publish's categories
     * @param visibility {enum} - a publish's visibility
     * @param handle {string} - a handle that owns the publish
     * @param thumbnailURI {string} - a uri of the publish's thumbnail image
     * @param contentURI {string} - a uri of the publish's content
     * @param title {string} - a publish's title
     * @param description {string} - a publish's description
     */
    struct Publish {
        uint256 publishId;
        address owner;
        Category[] categories;
        Visibility visibility;
        string handle;
        string thumbnailURI;
        string contentURI;
        string title;
        string description;
    }

    struct CreatePublishParams {
        Category[] categories;
        Visibility visibility;
        string handle;
        string thumbnailURI;
        string contentURI;
        string title;
        string description;
    }
}
