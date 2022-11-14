// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Constants} from "./libraries/Constants.sol";
import {DataTypes} from "./libraries/DataTypes.sol";

interface IContentBaseV1 {
    /**
     * An external function to update like fee.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     * @param fee {uint} - a fee to be sent when some profile likes a Publish
     */
    function updateLikeFee(uint256 fee) external;

    /**
     * An external function to update operational fee for the platform.
     * @dev  make sure to add modifier to only ADMIN_ROLE.
     * @param fee - operational fee
     */
    function updatePlatformFee(uint24 fee) external;

    /**
     * An external function to withdraw the contract's balance.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function withdraw() external;

    /**
     * An external function to create a ContentBase profile. This function is to be called by EOA addresses to create their profiles.
     * @param handle {string} - the handle of a profile.
     * @param imageURI {string} - the imageURI of a profile, this can be empty as profiles can update their profile images later.
     */
    function createProfile(string calldata handle, string calldata imageURI)
        external;

    /**
     * An external to update a profile image uri. The function must only be called by an owner of the profile.
     * @param tokenId {uint256} - a profile token id.
     * @param newImageURI {string} - a new image uri.
     */
    function updateProfileImage(uint256 tokenId, string calldata newImageURI)
        external;

    /**
     * An external function to set a default profile of the caller (EOA).
     * @param handle {string} - a handle of the profile to be set as the default.
     */
    function setDefaultProfile(string calldata handle) external;

    /**
     * An external function to validate handle - validate length, special characters and uniqueness.
     * @param handle {string} - a handle to be validated/
     * @return valid {bool} - `true` of the given handle is valid
     */
    function validateHandle(string calldata handle)
        external
        view
        returns (bool);

    /**
     * The function to get the default profile of the caller.
     * @return tokenId {uint256}
     * @return handle {string}
     */
    function getDefaultProfile()
        external
        view
        returns (uint256 tokenId, string memory);

    /**
     * An external function for a profile to follow another profile. The caller must own the given follower id.
     * @param followerId {uint256}
     * @param followeeId {uint256}
     */
    function follow(uint256 followerId, uint256 followeeId) external;

    /**
     * An external function to create Publish NFT.
     * @param createPublishData {struct} - see DataTypes.CreatePublishData struct
     */
    function createPublish(
        DataTypes.CreatePublishData calldata createPublishData
    ) external;

    /**
     * An external function to update Publish NFT.
     * @param updatePublishData {struct} - see DataTypes.UpdatePublishData struct
     */
    function updatePublish(
        DataTypes.UpdatePublishData calldata updatePublishData
    ) external;

    /**
     * An external function to burn a publish token.
     * @param tokenId {uint256} - a publish token id
     * @param creatorId {uint256} - the profile token id that created the publish
     */
    function deletePublish(uint256 tokenId, uint256 creatorId) external;

    /**
     * An external function to create a comment NFT.
     * @param createCommentData - see DataTypes.CreateCommentData
     */
    function createComment(
        DataTypes.CreateCommentData calldata createCommentData
    ) external;

    /**
     * An external function to update a comment
     * @param updateCommentData - see DataTypes.CreateCommentData
     */
    function updateComment(
        DataTypes.UpdateCommentData calldata updateCommentData
    ) external;

    /**
     * An external function to delete a comment.
     * @param tokenId {uint256} - a comment id
     * @param creatorId {uint256} - a profile token id that created the comment
     */
    function deleteComment(uint256 tokenId, uint256 creatorId) external;

    /**
     * An external function to handle `like` and `unlike` logic for publish like.
     * @param publishId {uint256} - a publish token id to be liked.
     * @param profileId {uint256} - a profile token id that performs like.
     */
    function likePublish(uint256 publishId, uint256 profileId) external payable;

    /**
     * An external function to handle `dislike` and `undoDislike` logic for publish like.
     * @param publishId {uint256} - a publish token id to be liked.
     * @param profileId {uint256} - a profile token id that performs like.
     */
    function disLikePublish(uint256 publishId, uint256 profileId) external;

    /**
     * An external function to get a publish struct by provided id.
     * @param tokenId {uint256} - a token id of the publish.
     * @return publish {Publish struct}
     */
    function getPublishById(uint256 tokenId)
        external
        view
        returns (DataTypes.Publish memory);

    /**
     * An external function to like a comment.
     * @param commentId {uint256}
     * @param profileId {uint256}
     */
    function likeComment(uint256 commentId, uint256 profileId) external;

    /**
     * An external function to dislike a comment.
     * @param commentId {uint256}
     * @param profileId {uint256}
     */
    function disLikeComment(uint256 commentId, uint256 profileId) external;
}
