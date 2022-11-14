// SPDX-License-Identifier: MIT
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
    function handleUnique(
        string calldata handle,
        mapping(bytes32 => uint256) storage _HandleHashToProfileId
    ) internal view returns (bool) {
        require(
            _HandleHashToProfileId[Helpers.hashHandle(handle)] == 0,
            "Handle taken"
        );

        return true;
    }

    /**
     * A helper function to check if handle is vaild
     * @param handle {string} - a handle
     */
    function validateHandle(string calldata handle)
        internal
        pure
        returns (bool)
    {
        bytes memory bytesHandle = bytes(handle);

        // Check the length
        require(
            bytesHandle.length >= Constants.MIN_HANDLE_LENGTH &&
                bytesHandle.length <= Constants.MAX_HANDLE_LENGTH,
            "Handle length invalid"
        );

        // Check if the handle contains invalid characters (Capital letters, spcecial characters).
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
     * A helper function to validate the uri is not too short.
     * @param uri {string} - a uri to be validated
     */
    function notTooShortURI(string calldata uri) internal pure returns (bool) {
        bytes memory bytesURI = bytes(uri);

        require(Constants.MIN_URI_LENGTH <= bytesURI.length, "URI too short");

        return true;
    }

    /**
     * A helper function to validate a uri is not too long.
     * @param uri {string} - a uri to be validated
     * @return boolean
     */
    function notTooLongURI(string calldata uri) internal pure returns (bool) {
        bytes memory bytesURI = bytes(uri);

        require(Constants.MAX_URI_LENGTH >= bytesURI.length, "URI too long");

        return true;
    }

    /**
     * A helper function to validate a publish's title is not too short.
     * @param title {string} - a publish title.
     * @return boolean
     */
    function notTooShortTitle(string calldata title)
        internal
        pure
        returns (bool)
    {
        bytes memory bytesTitle = bytes(title);

        require(
            Constants.MIN_PUBLISH_TITLE <= bytesTitle.length,
            "Title too short"
        );

        return true;
    }

    /**
     * A helper function to validate a publish's title is not too long.
     * @param title {string} - a publish title.
     * @return boolean
     */
    function notTooLongTitle(string calldata title)
        internal
        pure
        returns (bool)
    {
        bytes memory bytesTitle = bytes(title);

        require(
            Constants.MAX_PUBLISH_TITLE >= bytesTitle.length,
            "Title too long"
        );

        return true;
    }

    /**
     * A helper function to validate a publish's description is not too long.
     * @param description {string} - a publish description.
     * @return boolean
     */
    function notTooLongDescription(string calldata description)
        internal
        pure
        returns (bool)
    {
        bytes memory bytesDescription = bytes(description);

        require(
            Constants.MAX_PUBLISH_DESCRIPTION >= bytesDescription.length,
            "Description too long"
        );

        return true;
    }

    /**
     * A helper function to validate a publish's primary category.
     * @notice primary category must not Empty
     * @param category {enum} - a publish primary category.
     * @return boolean
     */
    function validPrimaryCategory(DataTypes.Category category)
        internal
        pure
        returns (bool)
    {
        require(
            category > DataTypes.Category.Empty &&
                category < DataTypes.Category.NotExist,
            "Invalid primary category"
        );

        return true;
    }

    /**
     * A helper function to validate a publish's secondary/tertiary category.
     * @dev secondary and tertiary can be of Empty enum.
     * @param category {enum} - a publish secondary/tertiary category.
     * @return boolean
     */
    function validCategory(DataTypes.Category category)
        internal
        pure
        returns (bool)
    {
        require(
            category >= DataTypes.Category.Empty &&
                category < DataTypes.Category.NotExist,
            "Invalid category"
        );

        return true;
    }
}
