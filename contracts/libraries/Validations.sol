// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "./DataTypes.sol";
import {Helpers} from "./Helpers.sol";

library Validations {
    function _createProfileValidation(
        string calldata handle,
        string calldata imageURI,
        mapping(bytes32 => uint256) storage _handleHashToProfileId
    ) internal view returns (bool) {
        // Validate handle length and special characters, the helper function will revert with an error message if the check failed so we don't have to set the error message here.
        require(Helpers.validateHandle(handle));

        // Require handle to be unique, the helper function will revert with an error message if the check failed.
        require(Helpers.handleUnique(handle, _handleHashToProfileId));

        // The imageURI can be empty so we don't have to validate min length.
        require(Helpers.notTooLongURI(imageURI));

        return true;
    }

    function _updateProfileImageValidation(
        uint256 tokenId,
        string calldata newImageURI,
        mapping(uint256 => DataTypes.Profile) storage _tokenIdToProfile
    ) internal view returns (bool) {
        // Validate the image uri.
        require(Helpers.notTooShortURI(newImageURI));
        require(Helpers.notTooLongURI(newImageURI));

        // Compare existing image uri to the new uri.
        require(
            keccak256(abi.encodePacked(newImageURI)) !=
                keccak256(
                    abi.encodePacked(_tokenIdToProfile[tokenId].imageURI)
                ),
            "No change"
        );

        return true;
    }

    function _createPublishValidation(
        DataTypes.CreatePublishData calldata createPublishData
    ) internal pure returns (bool) {
        // Validate imageURI.
        require(Helpers.notTooShortURI(createPublishData.imageURI));
        require(Helpers.notTooLongURI(createPublishData.imageURI));

        // Validate contentURI.
        require(Helpers.notTooShortURI(createPublishData.contentURI));
        require(Helpers.notTooLongURI(createPublishData.contentURI));

        // Validate metadataURI.
        require(Helpers.notTooShortURI(createPublishData.metadataURI));
        require(Helpers.notTooLongURI(createPublishData.metadataURI));

        // Validate title.
        require(Helpers.notTooShortTitle(createPublishData.title));
        require(Helpers.notTooLongTitle(createPublishData.title));

        // Validate description.
        // Description can be empty so no need to validate min length.
        require(Helpers.notTooLongDescription(createPublishData.description));

        // Validate categories.
        require(
            Helpers.validPrimaryCategory(createPublishData.primaryCategory)
        );
        require(Helpers.validCategory(createPublishData.secondaryCategory));
        require(Helpers.validCategory(createPublishData.tertiaryCategory));

        // If the secondary category is Empty, the tertiary category must also Empty.
        if (createPublishData.secondaryCategory == DataTypes.Category.Empty) {
            require(
                createPublishData.tertiaryCategory == DataTypes.Category.Empty,
                "Invalid category"
            );
        }

        return true;
    }

    function _updatePublishValidation(
        DataTypes.UpdatePublishData calldata updatePublishData
    ) internal pure returns (bool) {
        // Validate imageURI
        require(Helpers.notTooShortURI(updatePublishData.imageURI));
        require(Helpers.notTooLongURI(updatePublishData.imageURI));

        // Validate contentURI.
        require(Helpers.notTooShortURI(updatePublishData.contentURI));
        require(Helpers.notTooLongURI(updatePublishData.contentURI));

        // Validate metadataURI.
        require(Helpers.notTooShortURI(updatePublishData.metadataURI));
        require(Helpers.notTooLongURI(updatePublishData.metadataURI));

        // Validate title.
        require(Helpers.notTooShortTitle(updatePublishData.title));
        require(Helpers.notTooLongTitle(updatePublishData.title));

        // Validate description.
        require(Helpers.notTooLongDescription(updatePublishData.description));

        // Validate categories.
        require(
            Helpers.validPrimaryCategory(updatePublishData.primaryCategory)
        );
        require(Helpers.validCategory(updatePublishData.secondaryCategory));
        require(Helpers.validCategory(updatePublishData.tertiaryCategory));

        // If the secondary category is Empty, the tertiary category must also Empty.
        if (updatePublishData.secondaryCategory == DataTypes.Category.Empty) {
            require(
                updatePublishData.tertiaryCategory == DataTypes.Category.Empty,
                "Invalid category"
            );
        }

        return true;
    }
}
