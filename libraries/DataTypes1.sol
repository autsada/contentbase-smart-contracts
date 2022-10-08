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
     * @param profileId {uint256} - a profile token id the caller
     * @param imageURI {string}
     * @param contentURI {string}
     */
    struct CreatePublishData {
        uint256 profileId;
        string imageURI;
        string contentURI;
    }

    /**
     * A struct containing data required to create a publish token.
     * @param imageURI {string}
     * @param contentURI {string}
     */
    struct UpdatePublishData {
        string imageURI;
        string contentURI;
    }
}
