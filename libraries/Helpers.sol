// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {Constants} from "./Constants.sol";
import {DataTypes} from "./DataTypes.sol";

library Helpers {
    /**
     * A helper function to hash handle
     * @param handle {string}
     */
    function hashHandle(string calldata handle)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(bytes(handle));
    }

    /**
     * A helper function to check if handle is unique
     * @param handle {string} - a handle
     */
    function onlyUniqueHandle(
        string calldata handle,
        mapping(bytes32 => uint256) storage _profileIdByHandleHash
    ) internal view returns (bool) {
        if (_profileIdByHandleHash[Helpers.hashHandle(handle)] != 0)
            revert("Handle taken");

        return true;
    }

    /**
     * A helper function to check if handle is vaild
     * @param handle {string} - a handle
     */
    function onlyValidHandle(string calldata handle)
        internal
        pure
        returns (bool)
    {
        bytes memory bytesHandle = bytes(handle);

        if (
            bytesHandle.length < Constants.MIN_HANDLE_LENGTH ||
            bytesHandle.length > Constants.MAX_HANDLE_LENGTH
        ) revert("Handle is too short or too long.");

        for (uint256 i = 0; i < bytesHandle.length; ) {
            if (
                (bytesHandle[i] < "0" ||
                    bytesHandle[i] > "z" ||
                    (bytesHandle[i] > "9" && bytesHandle[i] < "a")) &&
                bytesHandle[i] != "." &&
                bytesHandle[i] != "-" &&
                bytesHandle[i] != "_"
            ) revert("Capital letters and special characters not allowed");
            unchecked {
                i++;
            }
        }

        return true;
    }

    /**
     * A Helper function to validate the uri is not too long
     * @param uri {string} - a uri to be validated
     */
    function notTooShortURI(string calldata uri) internal pure returns (bool) {
        bytes memory bytesURI = bytes(uri);

        if (Constants.MIN_URI_LENGTH > bytesURI.length)
            revert("URI is too short.");

        return true;
    }

    /**
     * A Helper function to validate the uri is not too long
     * @param uri {string} - a uri to be validated
     */
    function notTooLongURI(string calldata uri) internal pure returns (bool) {
        bytes memory bytesURI = bytes(uri);

        if (Constants.MAX_URI_LENGTH < bytesURI.length)
            revert("URI is too long.");

        return true;
    }

    /**
     * A helper function to validate publish's title
     * @param title {string} - a publish's title
     */
    function onlyValidTitle(string calldata title)
        internal
        pure
        returns (bool)
    {
        bytes memory bytesTitle = bytes(title);
        if (
            bytesTitle.length == 0 ||
            bytesTitle.length > Constants.MAX_PUBLISH_TITLE
        ) revert("Invalid title length.");

        return true;
    }

    /**
     * A helper function to validate publish's description
     * @param description {string} - a publish's description
     */
    function onlyValidDescription(string calldata description)
        internal
        pure
        returns (bool)
    {
        bytes memory bytesDescription = bytes(description);
        if (
            bytesDescription.length == 0 ||
            bytesDescription.length > Constants.MAX_PUBLISH_TITLE
        ) revert("Invalid description length.");

        return true;
    }

    /**
     * A helper function to validate publish's category
     * @param categories {enum} - refer to DataTypes.Category
     */
    function onlyValidCategories(DataTypes.Category[] calldata categories)
        internal
        pure
        returns (bool)
    {
        if (
            categories.length < Constants.MIN_PUBLISH_CATEGORY ||
            categories.length > Constants.MAX_PUBLISH_CATEGORY
        ) revert("At least 1 and at most 3 categories.");

        return true;
    }
}
