// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

/**
 * Data Types for all contracts locate in this file to make it easy to manage.
 */

library DataTypes {
    /**
     * A struct containing data of Profile NFT.
     * @param tokenId {uint256} - a token id
     * @param owner {address} - an address that owns the token
     * @param handle {string} - a handle that associate with the owner address
     * @param imageURI {string} - a uri of the profile image
     */
    struct Profile {
        uint256 tokenId;
        address owner;
        string handle;
        string imageURI;
    }

    /**
     * A struct containing data required to create Profile NFT.
     * @param handle {string}
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
     * Publish's Category
     * @dev The category information must be included in the contentURI.
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
     *      title {string}: "A title of the publish",
     *      description {string}: "A description of the publish",
     *      primaryCategory {enum}: "See Category enum above - must NOT Empty",
     *      secondaryCategory {enum}: "See Category enum above - can be Empty",
     *      tertiaryCategory {enum}: "See Category enum above - can be Empty",
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
     * @param title {string} - see contentURI Guild
     * @param description {string} - see contentURI Guild
     * @param primaryCategory {enum} - see contentURI Guild
     * @param secondaryCategory {enum} - see contentURI Guild
     * @param tertiaryCategory {enum} - see contentURI Guild
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
     * @param title {string} - see contentURI Guild
     * @param description {string} - see contentURI Guild
     * @param primaryCategory {enum} - see contentURI Guild
     * @param secondaryCategory {enum} - see contentURI Guild
     * @param tertiaryCategory {enum} - see contentURI Guild
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
     * A struct containing data of Follow NFT.
     * @param owner {address} - an address that owns the token.
     * @param tokenId {uint256} - a token id
     * @param followerId {uint256} - a Profile NFT id that follows followeeId.
     * @param followeeId {uint256} - a Profile NFT id that is being followed by followerId.
     */
    struct Follow {
        address owner;
        uint256 tokenId;
        uint256 followerId;
        uint256 followeeId;
    }

    /**
     * A struct containing data required to create Follow NFT.
     * @param followerId {uint256} - see FollowStruct
     * @param followeeId {uint256} - see FollowStruct
     */
    struct CreateFollowData {
        uint256 followerId;
        uint256 followeeId;
    }

    /**
     * A struct containing data of Like NFT.
     * @param owner {address} - an address that owns the token.
     * @param tokenId {uint256} - a token id
     * @param profileId {uint256} - a Profile NFT id that performs a like.
     * @param publishId {uint256} - a Publish NFT id that is being liked.
     */
    struct Like {
        address owner;
        uint256 tokenId;
        uint256 profileId;
        uint256 publishId;
    }

    /**
     * A struct containing data required to create Like NFT.
     * @param profileId {uint256} - see LikeStruct
     * @param publishId {uint256} - see LikeStruct
     */
    struct CreateLikeData {
        uint256 profileId;
        uint256 publishId;
    }
}
