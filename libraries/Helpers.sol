// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {Constants} from "./Constants.sol";

library Helpers {
    /**
     * A helper function to hash string
     * @param str {string} - string to be hashed
     */
    function hashString(string calldata str) internal pure returns (bytes32) {
        return keccak256(bytes(str));
    }

    /**
     * A helper function to check if handle is unique
     * @param handle {string} - a handle
     */
    function handleUnique(
        string calldata handle,
        mapping(bytes32 => uint256) storage _profileIdByHandleHash
    ) internal view returns (bool) {
        return _profileIdByHandleHash[Helpers.hashString(handle)] == 0;
    }

    /**
     * A Helper function to check if handle has correct length
     * @param handle {string}
     */
    function onlyValidHandleLen(string calldata handle)
        internal
        pure
        returns (bool)
    {
        bytes memory bytesHandle = bytes(handle);

        if (
            bytesHandle.length < Constants.MIN_HANDLE_LENGTH ||
            bytesHandle.length > Constants.MAX_HANDLE_LENGTH
        ) revert("Handle is too short or too long.");

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
}
