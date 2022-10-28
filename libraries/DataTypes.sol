// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

/**
 * Data Types for all contracts locate in this file to make it easy to manage.
 */

library DataTypes {
    /**
     * A struct containing data of Profile NFT.
     * @param owner {address} - an address that owns the token
     * @param tokenId {uint256} - a token id
     * @param following {uint256} - profile's following count
     * @param followers {uint256} - profile's followers count
     * @param handle {string} - a handle that associate with the owner address
     * @param imageURI {string} - a uri of the profile image
     */
    struct Profile {
        address owner;
        uint256 tokenId;
        uint256 following;
        uint256 followers;
        string handle;
        string imageURI;
    }

    /**
     * A struct containing data required to create Profile NFT.
     * @param handle {string} - a unique name of the profile
     * @param imageURI {string} - can be empty at the time of creation as the owner can set it later.
     */
    struct CreateProfileData {
        string handle;
        string imageURI;
    }

    /**
     * A struct containing data required to update profile image.
     * @param tokenId {uint256} - a token id to be updated
     * @param imageURI {string} - see ProfileStruct
     */
    struct UpdateProfileImageData {
        uint256 tokenId;
        string imageURI;
    }

    /**
     * A struct containing required data to follow a profile.
     * @param followerId {uint256} - a Profile id that follows followeeId.
     * @param followeeId {uint256} - a Profile id that is being followed by followerId.
     */
    struct FollowData {
        uint256 followerId;
        uint256 followeeId;
    }

    /**
     * Publish's Category
     * @dev The category information should be included in the metadataURI.
     * @dev when a publish is created, it must be classified to at least one category and at most 3 categories.
     */
    enum Category {
        Empty,
        Music,
        Movies,
        Entertainment,
        Sports,
        Food,
        Travel,
        Gaming,
        News,
        Animals,
        Education,
        Science,
        Technology,
        Programming,
        LifeStyle,
        Vehicles,
        Children,
        Women,
        Men,
        Other,
        NotExist
    }

    /**
     * A struct containing data of Publish NFT.
     * @param owner {address} - an address that owns the token
     * @param tokenId {uint256} - a token id
     * @param creatorId {uint256} - a profile token id of the creator
     * @param likes {uint256} - number of likes a publish has
     * @param imageURI {string} - a publish's thumbnail image uri
     * @param contentURI {string} - a publish's content uri, tipically it's a uri point to a video content
     * @param metadataURI {string} - a uri point to the publish's metadata json file that contain all information about a publish.
     *
     * @dev Metadata Guild: the metadata json object must have these below fields, additional fields can be added.
     * {
     *      name {string}: "A title of the publish",
     *      description {string}: "A description of the publish",
     *      image {string}: "A publish's thumbnail image, prefer ipfs storage"
     *      properties: {
     *          content: "A publish's content uri, prefer ipfs storage",
     *          primaryCategory {enum}: "See Category enum above - must NOT Empty",
     *          secondaryCategory {enum}: "See Category enum above - can be Empty",
     *          tertiaryCategory {enum}: "See Category enum above - can be Empty",
     *      }
     * }
     */
    struct Publish {
        address owner;
        uint256 tokenId;
        uint256 creatorId;
        uint256 likes;
        string imageURI;
        string contentURI;
        string metadataURI;
    }

    /**
     * A struct containing data required to create Publish NFT.
     * @param creatorId {uint256} - see PublishStruct
     * @param imageURI {string} - see PublishStruct
     * @param contentURI {string} - see PublishStruct
     * @param metadataURI {string} - see PublishStruct
     * @param title {string} - the publish's title
     * @param description {string} - the publish's description
     * @param primaryCategory {enum} - the publish's primary category
     * @param secondaryCategory {enum} - the publish's primary category
     * @param tertiaryCategory {enum} - the publish's primary category
     * @dev title, description, primaryCategory, secondaryCategory, and tertiaryCategory are not stored on the blockchain, they are required for event emitting to inform frontend the information of the created publish only.
     */
    struct CreatePublishData {
        uint256 creatorId;
        string imageURI;
        string contentURI;
        string metadataURI;
        string title;
        string description;
        Category primaryCategory;
        Category secondaryCategory;
        Category tertiaryCategory;
    }

    /**
     * A struct containing data required to update Publish NFT.
     * @param tokenId {uint256} - an id of the token to be updated
     * @param creatorId {uint256} - see PublishStruct
     * @param imageURI {string} - see PublishStruct
     * @param contentURI {string} - see PublishStruct
     * @param metadataURI {string} - see PublishStruct
     * @param title {string} - the publish's title
     * @param description {string} - the publish's description
     * @param primaryCategory {enum} - the publish's primary category
     * @param secondaryCategory {enum} - the publish's primary category
     * @param tertiaryCategory {enum} - the publish's primary category
     * @dev title, description, primaryCategory, secondaryCategory, and tertiaryCategory are not stored on-chain, they are required for event emitting to inform frontend the information of the updated publish only.
     */
    struct UpdatePublishData {
        uint256 tokenId;
        uint256 creatorId;
        string imageURI;
        string contentURI;
        string metadataURI;
        string title;
        string description;
        Category primaryCategory;
        Category secondaryCategory;
        Category tertiaryCategory;
    }

    /**
     * A struct containing data required to like a publish.
     * @param profileId {uint256} - an id of the profile that likes the publish
     * @param publishId {uint256} - an id of the publish
     */
    struct LikeData {
        uint256 profileId;
        uint256 publishId;
    }
}
