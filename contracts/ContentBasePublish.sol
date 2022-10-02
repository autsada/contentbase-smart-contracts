// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {Helpers} from "../libraries/Helpers.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

abstract contract ContentBasePublish {
    event PublishCreated(uint256 tokenId, address owner);

    /**
     * A public function signature to mint publish nft that to be implemented by the derived contract.
     */
    function createPublish(
        string calldata tokenURI,
        DataTypes.CreatePublishParams calldata createPublishParams
    ) public virtual returns (uint256);

    /**
     * An internal function that contains the logic to create a publish.
     * @param owner {address} - an address to be set as an owner of the profile
     * @param publishId {uint256} - a token id of to be created publish
     * @param createPublishParams {struct} - refer to DataTypes.CreatePublishParams struct
     * @param _publishIdsByAddress {mapping}
     * @param _publishById {mapping}
     *
     */
    function _createPublish(
        address owner,
        uint256 publishId,
        DataTypes.CreatePublishParams calldata createPublishParams,
        mapping(address => uint256[]) storage _publishIdsByAddress,
        mapping(uint256 => DataTypes.Publish) storage _publishById
    ) internal returns (uint256) {
        // Create a publish struct in memory
        DataTypes.Publish memory publish = DataTypes.Publish({
            publishId: publishId,
            owner: owner,
            categories: createPublishParams.categories,
            handle: createPublishParams.handle,
            thumbnailURI: createPublishParams.thumbnailURI,
            contentURI: createPublishParams.contentURI,
            title: createPublishParams.title,
            description: createPublishParams.description
        });

        // Store the create publish in publish by id mapping
        _publishById[publishId] = publish;

        // Add the publish id to publish ids array by address
        _publishIdsByAddress[owner].push(publishId);

        // Emit publish created event
        emit PublishCreated(publishId, owner);

        return publishId;
    }
}
