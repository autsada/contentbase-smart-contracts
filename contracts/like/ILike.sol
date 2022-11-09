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
     * An external function to handle `like` and `unlike` logic for publish like.
     * @param owner {address} - an EOA address that owns the profile that performs the like (or unlike)
     * @return success {bool}
     * @return tokenId {uint256}
     */
    function like(address owner) external returns (bool, uint256);
}
