// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

library DataTypes {
    /**
     * An enum to use as a token type
     */
    enum TokenType {
        Profile,
        Publish,
        Follow,
        Like
    }

    /**
     * An enum for token visibility
     */
    enum Visibility {
        UNSET,
        OFF,
        ON
    }

    /**
     * A struct containing token data.
     * @dev There are 4 types of token.
     * - Profile token
     * - Publish token
     * - Follow token
     * - Like token
     * These tokens use the same struct with different properties value and meaning depending on its type. Refer to explanation below.
     * @param tokenId {uint256} - an id of the token
     * @param associatedId {uint256} - an id of the token as detail below
     * - For Profile token - same as tokenId
     * - For Publish token - same as tokenId
     * - For Follow token - a token id of the following profile
     * - For Like token - a token id of the liked publish
     * @param owner {address} - an address that owns the token
     * @param tokenType {enum} - a type of the token
     * @param visibility {enum} - visibility of the token, for Publish token it can be ON or OFF, for other tokens it must be UNSET
     * @param handle {string} - a handle that associate with the owner address
     * @param imageURI {string} - a uri of the image as detail below
     * - For Profile token - a uri of the profile image
     * - For Publish token - a uri of the publish's thumbnail image
     * - For Follow token - empty
     * - For Like token - empty
     * @param contentURI {string} - a uri of the token's content as detail below
     * - For Profile token - empty
     * - For Publish token - a uri of the publish's content
     * - For Follow token - empty
     * - For Like token - empty
     */
    struct Token {
        uint256 tokenId;
        uint256 associatedId;
        address owner;
        TokenType tokenType;
        Visibility visibility;
        string handle;
        string imageURI;
        string contentURI;
    }

    /**
     * A struct containing data required to create a profile token.
     * @param handle {string}
     * @param imageURI {string}
     */
    struct CreateProfileData {
        string handle;
        string imageURI;
    }

    /**
     * A struct containing data required to create a publish token.
     * @param visibility {enum}
     * @param handle {string}
     * @param imageURI {string}
     * @param contentURI {string}
     */
    struct CreatePublishData {
        Visibility visibility;
        string handle;
        string imageURI;
        string contentURI;
    }

    /**
     * A struct containing data required to create a publish token.
     * @param visibility {enum}
     * @param imageURI {string}
     * @param contentURI {string}
     */
    struct UpdatePublishData {
        Visibility visibility;
        string imageURI;
        string contentURI;
    }
}
