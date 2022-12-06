// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DataTypes} from "../libraries/DataTypes.sol";

interface IContentBaseLikeV1 {
    /**
     * An external function to update the platform owner address.
     * @dev  make sure to add modifier to only ADMIN_ROLE.
     * @param ownerAddress {address} - the contract owner address
     */
    function updatePlatformOwner(address ownerAddress) external;

    /**
     * An external function to update the profile contract address for use to communicate with the profile contract.
     * @dev  make sure to add modifier to only ADMIN_ROLE.
     * @param contractAddress {address} - the profile contract address
     */
    function updateProfileContract(address contractAddress) external;

    /**
     * An external function to get the stored profile contract address.
     * @return contractAddress {address}
     */
    function getProfileContract() external view returns (address);

    /**
     * An external function to update the publish contract address for use to communicate with the publish contract.
     * @dev  make sure to add modifier to only ADMIN_ROLE.
     * @param contractAddress {address} - the publish contract address
     */
    function updatePublishContract(address contractAddress) external;

    /**
     * An external function to get the stored publish contract address.
     * @return contractAddress {address}
     */
    function getPublishContract() external view returns (address);

    /**
     * An external function to update like fee.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     * @param fee {uint} - an amount in ether
     */
    function updateLikeFee(uint256 fee) external;

    /**
     * An external function to update operational fee for the platform.
     * @dev  make sure to add modifier to only ADMIN_ROLE.
     * @param fee - a percentage for use to calcuate platform operational fee.
     */
    function updatePlatformFee(uint256 fee) external;

    /**
     * An external function to withdraw the contract's balance.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function withdraw() external;

    /**
     * An external function to handle `like` and `unlike` logic for publish like.
     * @dev The caller is required to send a like fee so this function must be payable.
     * @param publishId {uint256} - a publish token id to be liked.
     * @param profileId {uint256} - a profile token id that performs like.
     */
    function likePublish(uint256 publishId, uint256 profileId) external payable;

    /**
     * An external function to handle `dislike` and `undoDislike` logic for publish like.
     * @param publishId {uint256} - a publish token id to be liked.
     * @param profileId {uint256} - a profile token id that performs like.
     */
    function disLikePublish(uint256 publishId, uint256 profileId) external;

    /**
     * An external function to check if a profile liked the publish.
     * @param profileId {uint256} - a token id of the profile
     * @param publishId {uint256} - a token id of the publish
     * @return liked {bool}
     */
    function checkLikedPublish(
        uint256 profileId,
        uint256 publishId
    ) external view returns (bool);

    /**
     * An external function to check if a profile dis-liked the publish.
     * @param profileId {uint256} - a token id of the profile
     * @param publishId {uint256} - a token id of the publish
     * @return disLiked {bool}
     */
    function checkDisLikedPublish(
        uint256 profileId,
        uint256 publishId
    ) external view returns (bool);
}
