// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "../../libraries/DataTypes.sol";

interface IContentBaseLike {
    /**
     * An external function to update Publish Contract address.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function updatePublishContract(address contractAddress) external;

    /**
     * An external function to update Comment Contract address.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function updateCommentContract(address contractAddress) external;

    /**
     * An external function to handle `like` and `unlike` logic for publish like.
     * @param owner {address} - an EOA address that owns the profile that performs the like (or unlike)
     * @param likeData - see DataTypes.Likedata
     * @return success {bool}
     * @return tokenId {uint256}
     * @return likeType {LikeActionType enum}
     */
    function like(address owner, DataTypes.LikeData calldata likeData)
        external
        returns (
            bool,
            uint256,
            DataTypes.LikeActionType
        );

    /**
     * An external function to handle dislike a publish.
     * @param profile {address}
     * @param publishId {uint256}
     * @return success {bool}
     * @return isLiked {bool} - a boolean to indicate if the given profile has liked the given publish before.
     */
    function handleDislikePublish(address profile, uint256 publishId)
        external
        returns (bool, bool);

    /**
     * An external function to handle `like` and `unlike` logic for comment like.
     * @param owner {address} - an EOA address that owns the profile that performs the like (or unlike)
     * @param likeData - see DataTypes.Likedata
     * @return success {bool}
     * @return tokenId {uint256}
     * @return likeType {LikeActionType enum}
     */
    function likeComment(address owner, DataTypes.LikeData calldata likeData)
        external
        returns (
            bool,
            uint256,
            DataTypes.LikeActionType
        );
}
