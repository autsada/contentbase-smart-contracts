// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {Constants} from "../libraries/Constants.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

interface IContentBaseProfileFactory {
    /**
     * The function to create a proxy of ContentBase Profile Contract.
     * @param createProfileData - see DataTypes.CreateProfileData
     */
    function createProfile(
        DataTypes.CreateProfileData calldata createProfileData
    ) external;

    /**
     * An external function to set default profile for a specific address.
     * @param handle {string} - a handle of the profile
     */
    function setDefaultProfile(string calldata handle) external;

    /**
     * The function to get EOA's default profile.
     */
    function getDefaultProfile()
        external
        view
        returns (address, DataTypes.Profile memory);

    /**
     * An external function to validate handle - validate length, special characters and uniqueness.
     * @param handle {string}
     * @return boolean
     */
    function validateHandle(string calldata handle)
        external
        view
        returns (bool);

    /**
     * An external function to get an owner of the profile.
     * @param profile {address} - an address to be checked
     * @return owner {address} - an owner of the profile
     */
    function getProfileOwner(address profile) external view returns (address);
}
