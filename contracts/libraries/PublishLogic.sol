// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "./DataTypes.sol";
import {Events} from "./Events.sol";

library PublishLogic {
    /**
     * @param tokenId {uint256} - a publish token id.
     * @param createPublishData see DataTypes.CreatePublishData.
     * @param _tokenIdToPublish - storage mapping.
     */
    function _createPublish(
        uint256 tokenId,
        DataTypes.CreatePublishData calldata createPublishData,
        mapping(uint256 => DataTypes.Publish) storage _tokenIdToPublish
    ) internal {
        // Update the publish struct mapping.
        _tokenIdToPublish[tokenId] = DataTypes.Publish({
            owner: msg.sender,
            creatorId: createPublishData.creatorId,
            likes: 0,
            disLikes: 0,
            imageURI: createPublishData.imageURI,
            contentURI: createPublishData.contentURI,
            metadataURI: createPublishData.metadataURI
        });

        // Emit publish created event.
        _emitPublishCreated(tokenId, msg.sender, createPublishData);
    }

    /**
     * @param updatePublishData see DataTypes.UpdatePublishData.
     * @param _tokenIdToPublish - storage mapping.
     */
    function _updatePublish(
        DataTypes.UpdatePublishData calldata updatePublishData,
        mapping(uint256 => DataTypes.Publish) storage _tokenIdToPublish
    ) internal {
        uint256 tokenId = updatePublishData.tokenId;

        // Only update imageURI if it's changed.
        if (
            keccak256(abi.encodePacked(_tokenIdToPublish[tokenId].imageURI)) !=
            keccak256(abi.encodePacked(updatePublishData.imageURI))
        ) {
            _tokenIdToPublish[tokenId].imageURI = updatePublishData.imageURI;
        }

        // Only update contentURI if it's changed.
        if (
            keccak256(
                abi.encodePacked(_tokenIdToPublish[tokenId].contentURI)
            ) != keccak256(abi.encodePacked(updatePublishData.contentURI))
        ) {
            _tokenIdToPublish[tokenId].contentURI = updatePublishData
                .contentURI;
        }

        // Only update metadataURI if it's changed.
        if (
            keccak256(
                abi.encodePacked(_tokenIdToPublish[tokenId].metadataURI)
            ) != keccak256(abi.encodePacked(updatePublishData.metadataURI))
        ) {
            _tokenIdToPublish[tokenId].metadataURI = updatePublishData
                .metadataURI;
        }

        // Emit publish updated event
        _emitPublishUpdated(msg.sender, updatePublishData);
    }

    /**
     * @param tokenId {uint256} - a publish token id.
     * @param creatorId {uint256} - a profile token id of the creator.
     * @param _tokenIdToPublish - storage mapping.
     */
    function _deletePublish(
        uint256 tokenId,
        uint256 creatorId,
        mapping(uint256 => DataTypes.Publish) storage _tokenIdToPublish
    ) internal {
        // Remove the publish from the struct mapping.
        delete _tokenIdToPublish[tokenId];

        emit Events.PublishDeleted(
            tokenId,
            creatorId,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * A helper function to emit a create publish event that accepts a create publish data struct in memory to avoid a stack too deep error.
     * @param tokenId {uint256}
     * @param owner {address}
     * @param createPublishData {struct}
     */
    function _emitPublishCreated(
        uint256 tokenId,
        address owner,
        DataTypes.CreatePublishData memory createPublishData
    ) internal {
        emit Events.PublishCreated(
            tokenId,
            createPublishData.creatorId,
            owner,
            createPublishData.imageURI,
            createPublishData.contentURI,
            createPublishData.metadataURI,
            createPublishData.title,
            createPublishData.description,
            createPublishData.primaryCategory,
            createPublishData.secondaryCategory,
            createPublishData.tertiaryCategory,
            block.timestamp
        );
    }

    /**
     * A helper function to emit a update publish event that accepts a update publish data struct in memory to avoid a stack too deep error.
     * @param owner {address}
     * @param updatePublishData {struct}
     */
    function _emitPublishUpdated(
        address owner,
        DataTypes.UpdatePublishData memory updatePublishData
    ) internal {
        emit Events.PublishUpdated(
            updatePublishData.tokenId,
            updatePublishData.creatorId,
            owner,
            updatePublishData.imageURI,
            updatePublishData.contentURI,
            updatePublishData.metadataURI,
            updatePublishData.title,
            updatePublishData.description,
            updatePublishData.primaryCategory,
            updatePublishData.secondaryCategory,
            updatePublishData.tertiaryCategory,
            block.timestamp
        );
    }
}
