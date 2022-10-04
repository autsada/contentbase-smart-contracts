// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {Helpers} from "../libraries/Helpers.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Constants} from "../libraries/Constants.sol";

abstract contract ContentBasePublish {
    event PublishCreated(uint256 tokenId, address owner);
    event PublishUpdated(uint256 tokenId, address owner);

    /**
     * An external function signature to mint a publish nft that to be implemented by the derived contract.
     * @param uri {string} - a uri of the token's metadata file
     * @param createPublishData {struct} - refer to DataTypes.CreatePublishData struct
     */
    function createPublish(
        string calldata uri,
        DataTypes.CreatePublishData calldata createPublishData
    ) external virtual returns (uint256);

    /**
     * An internal function that contains the logic to create a publish token.
     * @param owner {address} - an address to be set as an owner of the profile
     * @param tokenId {uint256} - an id of the token
     * @param createPublishData {struct} - refer to DataTypes.CreatePublishData struct
     * @param _tokenById {mapping}
     *
     */
    function _createPublish(
        address owner,
        uint256 tokenId,
        DataTypes.CreatePublishData calldata createPublishData,
        mapping(uint256 => DataTypes.Token) storage _tokenById
    ) internal returns (uint256) {
        // Create a new token struct in memory
        DataTypes.Token memory newPublish = DataTypes.Token({
            tokenId: tokenId,
            associatedId: tokenId,
            owner: owner,
            tokenType: DataTypes.TokenType.Publish,
            visibility: createPublishData.visibility,
            handle: createPublishData.handle,
            imageURI: createPublishData.imageURI,
            contentURI: createPublishData.contentURI
        });

        // Store the created publish in the mapping
        _tokenById[tokenId] = newPublish;

        // Emit publish created event
        emit PublishCreated(tokenId, owner);

        return tokenId;
    }

    /**
     * An external function signature to update a publish that to be implemented by the derived contract.
     * @param tokenId {uint256} - an id of the token to be updated
     * @param uri {string} - a new uri of the token's metadata
     * @param updatePublishData {struct} - refer to DataTypes.UpdatePublishData struct
     */
    function updatePublish(
        uint256 tokenId,
        string calldata uri,
        DataTypes.UpdatePublishData calldata updatePublishData
    ) external virtual returns (uint256);

    /**
     * An internal function that contains the logic to update a publish token.
     * @param owner {address}
     * @param tokenId {uint256} - an id of the token
     * @param updatePublishData {struct} - refer to DataTypes.UpdatePublishData struct
     * @param _tokenById {mapping}
     *
     */
    function _updatePublish(
        address owner,
        uint256 tokenId,
        DataTypes.UpdatePublishData calldata updatePublishData,
        mapping(uint256 => DataTypes.Token) storage _tokenById
    ) internal returns (uint256) {
        // Update the token
        _tokenById[tokenId].visibility = updatePublishData.visibility;
        _tokenById[tokenId].imageURI = updatePublishData.imageURI;
        _tokenById[tokenId].contentURI = updatePublishData.contentURI;

        // Emit publish created event
        emit PublishUpdated(tokenId, owner);

        return tokenId;
    }
}
