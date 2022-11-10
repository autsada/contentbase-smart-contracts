// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {DataTypes} from "../libraries/DataTypes.sol";
import {Constants} from "../libraries/Constants.sol";

interface IContentBaseProfile {
    /**
     * An external to update profile image uri.
     * @param imageURI {string} - an updated image uri
     *
     */
    function updateProfileImage(string calldata imageURI) external;

    /**
     * An external function that will be called by the profile owner (EOA) to request to follow other profile.
     * @param taregetProfileAddress {address} - a profile address that the caller wants to follow
     */
    function requestFollow(address taregetProfileAddress) external;

    /**
     * An external function that will be called by other profiles to request to follow the profile of a specific address.
     * @return success {bool}
     * @return tokenId {uint256}
     * @return followStruct {Follow Struct}
     * @return followType {FollowType Enum}
     */
    function follow()
        external
        returns (
            bool,
            DataTypes.Follow memory,
            uint256,
            DataTypes.FollowType
        );

    /**
     * An external function to get EOA's profile.
     * @return addr {address} - the profile address
     * @return profile {Profile} - see DataTypes.Profile
     */
    function getProfile()
        external
        view
        returns (address, DataTypes.Profile memory);
}
