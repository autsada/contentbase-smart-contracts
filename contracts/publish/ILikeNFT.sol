// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {DataTypes} from "../../libraries/DataTypes.sol";
import {Constants} from "../../libraries/Constants.sol";

interface ILikeNFT {
    /**
     * An external function to set Publish Contract address.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function setPublishContractAddress(address publishAddress) external;

    /**
     * An external function to create a like NFT.
     * @param owner {address} - the address that create a like
     * @param likeData - see DataTypes.LikeData
     * @return success {bool}
     * @return tokenId {uint256}
     */
    function createLike(address owner, DataTypes.LikeData calldata likeData)
        external
        returns (bool, uint256);

    /**
     * An external function to unLike.
     * @param tokenId {uint256} - a like id
     * @param owner {address} - an owner of the like
     * @param profileId {uint256} - a profile that the like belongs to
     * @return success {bool}
     */
    function burn(
        uint256 tokenId,
        address owner,
        uint256 profileId
    ) external returns (bool);

    /**
     * An external function to get a like from the provided id.
     * @param tokenId {uint256} - a like id
     * @return like {DataTypes.Like}
     */
    function getLike(uint256 tokenId)
        external
        view
        returns (DataTypes.Like memory);
}
