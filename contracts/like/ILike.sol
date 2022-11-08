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
     * An internal function to handle `like` and `unlike` logic.
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
}
