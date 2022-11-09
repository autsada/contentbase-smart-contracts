// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * Data Types for all contracts locate in this file to make it easy to manage.
 */

library DataTypes {
    /**
     * A struct containing data of Profile NFT.
     * @param owner {address} - an address that owns the token
     * @param handle {string} - a handle that associate with the owner address
     * @param imageURI {string} - a uri of the profile image
     * @param followers {uint32} - number of followers
     * @param following {uint32} - number of following
     */
    struct Profile {
        address owner;
        string handle;
        string imageURI;
        uint32 followers;
        uint32 following;
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
     * A strunct containing the data of Follow NFT.
     * @param owner {address} - an EOA that owns the follower address
     * @param follower {address} - a profile address of the follower.
     * @param issuer {address} - a profie address that issues the token (followee).
     */
    struct Follow {
        address owner;
        address follower;
        address issuer;
    }

    /**
     * An enum to identify the type of the call in the `follow` function.
     */
    enum FollowType {
        FOLLOW,
        UNFOLLOW
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
     * @param creatorId {adress} - a profile address that creates the publish
     * @param likes {uint256} - number of likes a publish has
     * @param disLikes {uint256} - number of dis-likes a publish has
     * @param imageURI {string} - a publish's thumbnail image uri
     * @param contentURI {string} - a publish's content uri, tipically it's a uri point to a video content
     * @param metadataURI {string} - a uri point to the publish's metadata json file that contain all information about a publish.
     *
     * @dev Metadata Guild: the metadata json object must have these below fields, additional fields can be added.
     * {
     *      name: "A title of the publish",
     *      description: "A description of the publish",
     *      image: "A publish's thumbnail image, prefer ipfs storage"
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
        address creatorId;
        uint32 likes;
        uint32 disLikes;
        string imageURI;
        string contentURI;
        string metadataURI;
    }

    /**
     * A struct containing data required to create Publish NFT.
     * @param creatorId {address} - see PublishStruct
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
        address creatorId;
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
     * @param creatorId {address} - see PublishStruct
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
        address creatorId;
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
     * A struct containing the data of Like NFT.
     * @param owner {address} - an owner of the like token
     * @param profileAddress {address} - a profile address that performs like
     * @param publishId {uint256} - a publish id to be liked, for the case of `like comment` the `publishId` refers to a comment id
     */
    struct Like {
        address owner;
        address profileAddress;
        uint256 publishId;
    }

    /**
     * A struct containing data required to like a publish.
     * @param profileAddress {address} - an address of the profile that performs like
     * @param publishId {uint256} - an id of the publish
     */
    struct LikeData {
        address profileAddress;
        uint256 publishId;
    }

    /**
     * An enum to identify the type of the like action - either `like` or `unlike`.
     */
    enum LikeActionType {
        LIKE,
        UNLIKE
    }

    /**
     * A struct containing data of Comment NFT.
     * @param owner {address} - an owner of the profile address that owns the token
     * @param profileAddress {address} - the profile address that comments a publish
     * @param publishId {uint256} - the publish id to be commented
     * @param commentId {uint256} - the comment id to be commented, it can be 0 meaning that the comment is made on the publish itself, otherwise it is made on other comment (that is the given commentId).
     * @param likes - number of likes the comment has
     * @param text {string} - text input in the comment, can be empty
     * @param contentURI {string} - a uri point to the comment metadata json object, can be empty
     * @dev The contentURI should be in the following format.
     * {
     *      name: "for example 'The comment of the publish id 1'",
     *      description: "the text input of the comment",
     *      image: "If the comment as a media file, this is the uri point to that file",
     *      properties: {
     *          // Other info if any
     *      }
     * }
     */
    struct Comment {
        address owner;
        address profileAddress;
        uint256 publishId;
        uint256 commentId;
        uint32 likes;
        string text;
        string contentURI;
    }

    /**
     * A struct containing data required to comment on a publish.
     * @param publishId {uint256} - see Comment struct
     * @param commentId {uint256} - see Comment struct
     * @param profileAddress {address} - see Comment struct
     * @param text {string} - see Comment struct, can be empty
     * @param contentURI {string} - see Comment struct, can be empty
     * @dev at least one of text and medaiURI must not empty.
     */
    struct CreateCommentData {
        uint256 publishId;
        uint256 commentId;
        address profileAddress;
        string text;
        string contentURI;
    }

    /**
     * A struct containing data required to update a comment on a publish.
     * @param tokenId {uint256} - an id of the comment to be updated
     * @param publishId {uint256} - see Comment struct
     * @param profileAddress {address} - see Comment struct
     * @param text {string} - see Comment struct, can be empty
     * @param contentURI {string} - see Comment struct, can be empty
     * @dev if no change, the existing data of the text and mediaURI must be provided.
     */
    struct UpdateCommentData {
        uint256 tokenId;
        uint256 publishId;
        address profileAddress;
        string text;
        string contentURI;
    }
}
