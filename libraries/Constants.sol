// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library Constants {
    uint8 internal constant MIN_HANDLE_LENGTH = 3;
    uint8 internal constant MAX_HANDLE_LENGTH = 31;
    uint8 internal constant MIN_URI_LENGTH = 1;
    uint16 internal constant MAX_URI_LENGTH = 4000;
    uint8 internal constant TOKEN_QUERY_LIMIT = 40;
    uint8 internal constant MIN_PUBLISH_TITLE = 1;
    uint8 internal constant MAX_PUBLISH_TITLE = 100;
    uint16 internal constant MAX_PUBLISH_DESCRIPTION = 5000;
}
