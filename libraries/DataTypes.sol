// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

library DataTypes {
    /**
     * A struct containing token data of Profile NFT
     * @param tokenId {uint256} - an id of the token
     * @param owner {address} - an address that owns the token
     * @param handle {string} - a handle that associate with the owner address
     * @param imageURI {string} - a uri of the profile image
     */
    struct ProfileStruct {
        uint256 tokenId;
        address owner;
        string handle;
        string imageURI;
    }

    /**
     * A struct containing data required to create a profile NFT.
     * @param tokenURI {string} - a uri of the token metadata's file
     * @param handle {string}
     * @param imageURI {string} - can be empty at the time of creation as the owner can set it later.
     */
    struct CreateProfileData {
        string tokenURI;
        string handle;
        string imageURI;
    }

    /**
     * A struct containing data required to update profile image.
     * @param tokenId {uint256} - a token id to be updated
     * @param tokenURI {string} - a uri of the token metadata's file
     * @param imageURI {string} - a profile's image uri, can be empty in the case that the uri isn't changed
     */
    struct UpdateProfileImageData {
        uint256 tokenId;
        string tokenURI;
        string imageURI;
    }

    /**
     * A struct containing token data of Publish NFT
     * @param tokenId {uint256} - an id of the token
     * @param creatorId {uint256} - a profile token id of the creator
     * @param owner {address} - an address that owns the token
     * @param imageURI {string} - a publish's thumbnail image uri
     * @param contentURI {string} - a publish's content uri
     */
    struct PublishStruct {
        uint256 tokenId;
        uint256 creatorId;
        address owner;
        string imageURI;
        string contentURI;
    }

    /**
     * A struct containing data required to create a publish NFT.
     * @param creatorId {uint256} - refer to PublishStruct
     * @param owner {address} - refer to PublishStruct
     * @param tokenURI {string} - a uri of the token metadata's file
     * @param imageURI {string} - refer to PublishStruct
     * @param contentURI {string} - refer to PublishStruct
     */
    struct CreatePublishData {
        uint256 creatorId;
        address owner;
        string tokenURI;
        string imageURI;
        string contentURI;
    }
}
