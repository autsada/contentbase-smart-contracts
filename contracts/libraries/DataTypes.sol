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
    }

    enum PublishKind {
        Video,
        Short,
        Audio,
        Blog,
        Post
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
     * @param owner {address} - an address that owns the token.
     * @param creatorId {uint256} - a profile token id that creates the publish.
     * @param imageURI {string} - a publish's thumbnail image uri.
     * @param contentURI {string} - a publish's content uri, tipically it's a uri point to a video content.
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
        uint256 creatorId;
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
     * @param kind {enum} - the publish's kind
     * @dev title, description, primaryCategory, secondaryCategory, tertiaryCategory, and kind are not stored on the blockchain, they are required for event emitting to inform frontend the information of the created publish only.
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
        PublishKind kind;
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

    enum CommentType {
        PUBLISH,
        COMMENT
    }

    /**
     * A struct containing data of Comment NFT.
     * @param owner {address} - an owner of the profile address that owns the token.
     * @param creatorId {uint256} - a profile token id that comments a publish.
     * @param parentId {uint256} - a publish or comment token id that the comment belongs to.
     * @param commentType {enum} - "PUBLISH" | "COMMENT"
     * @param contentURI {string} - a uri point to the comment metadata json object that contains the detail of the comment.
     * @dev The contentURI should be in the following format.
     * {
     *      name: "ContentBase Comment NFT",
     *      description: "the text input of the comment",
     *      properties: {
     *          // Other info if any
     *      }
     * }
     */
    struct Comment {
        address owner;
        uint256 creatorId;
        uint256 parentId;
        CommentType commentType;
        string contentURI;
    }

    /**
     * A struct containing data required to create a comment.
     * @param parentId {uint256} - a publish or comment token id to be commented on
     * @param creatorId {uint256} - see Comment struct
     * @param contentURI {string} - see Comment struct
     * @param text {string} - a text comment
     * @dev We don't store `text` on on-chain, they are required for event emitting to inform the UIs so they can do what ever they want with this data. At least one of `text` or `mediaURI` must not empty.
     */
    struct CreateCommentData {
        uint256 parentId;
        uint256 creatorId;
        string contentURI;
        string text;
    }

    /**
     * A struct containing data required to update a comment on a publish.
     * @param tokenId {uint256} - an id of the comment to be updated
     * @param creatorId {uint256} - see Comment struct
     * @param contentURI {string} - an updated content uri
     * @param text {string} - an updated text
     */
    struct UpdateCommentData {
        uint256 tokenId;
        uint256 creatorId;
        string contentURI;
        string text;
    }

    /**
     *  struct containing data required for `PublishLiked` event.
     * @param tokenId {uint256} - a like token id
     * @param publishId {uint256} - a publish token id
     * @param profileId {uint256} - a profile token id
     * @param totalAmount {uint256} - a total ethers sent by the profile
     * @param fee {uint256} - a fee to deduct from total amount for the platform
     */
    struct PublishLikedEventArgs {
        uint256 tokenId;
        uint256 publishId;
        uint256 profileId;
        uint256 totalAmount;
        uint256 fee;
    }
}
