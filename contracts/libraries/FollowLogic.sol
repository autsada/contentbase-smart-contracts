// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "./DataTypes.sol";
import {Events} from "./Events.sol";

library FollowLogic {
    /**
     * @param tokenId {uint256} - a Follow token id
     * @param followerId {uint256} - a follower profile id
     * @param followeeId {uint256}
     * @param _tokenIdToProfile {storage mapping}
     * @param _profileIdToFolloweeIdToTokenId {storage mapping}
     * @param _profileIdToFollowerIdToTokenId {storage mapping}
     */
    function _follow(
        uint256 tokenId,
        uint256 followerId,
        uint256 followeeId,
        mapping(uint256 => DataTypes.Profile) storage _tokenIdToProfile,
        mapping(uint256 => mapping(uint256 => uint256))
            storage _profileIdToFolloweeIdToTokenId,
        mapping(uint256 => mapping(uint256 => uint256))
            storage _profileIdToFollowerIdToTokenId
    ) internal {
        // Update the profile to followee mapping of the follower profile.
        _profileIdToFolloweeIdToTokenId[followerId][followeeId] = tokenId;
        // Update the profile to follower mapping of the followee profile.
        _profileIdToFollowerIdToTokenId[followeeId][followerId] = tokenId;

        // Update follower and followee profile structs.
        _tokenIdToProfile[followerId].following++;
        _tokenIdToProfile[followeeId].followers++;

        emit Events.FollowNFTMinted(
            tokenId,
            followerId,
            followeeId,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @param tokenId {uint256} - a Follow token id
     * @param followerId {uint256} - a follower profile id
     * @param followeeId {uint256}
     * @param _tokenIdToProfile {storage mapping}
     * @param _profileIdToFolloweeIdToTokenId {storage mapping}
     * @param _profileIdToFollowerIdToTokenId {storage mapping}
     */
    function _unFollow(
        uint256 tokenId,
        uint256 followerId,
        uint256 followeeId,
        mapping(uint256 => DataTypes.Profile) storage _tokenIdToProfile,
        mapping(uint256 => mapping(uint256 => uint256))
            storage _profileIdToFolloweeIdToTokenId,
        mapping(uint256 => mapping(uint256 => uint256))
            storage _profileIdToFollowerIdToTokenId
    ) internal {
        // Update the profile to followee mapping of the follower profile;
        _profileIdToFolloweeIdToTokenId[followerId][followeeId] = 0;
        // Update the profile to follower mapping of the followee profile;
        _profileIdToFollowerIdToTokenId[followeeId][followerId] = 0;

        // Update follower and followee profile structs.
        _tokenIdToProfile[followerId].following--;
        _tokenIdToProfile[followeeId].followers--;

        emit Events.FollowNFTBurned(
            tokenId,
            followerId,
            followeeId,
            msg.sender,
            block.timestamp
        );
    }
}
