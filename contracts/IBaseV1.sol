// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Constants} from "./libraries/Constants.sol";
import {DataTypes} from "./libraries/DataTypes.sol";

interface IBaseV1 {
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
}
