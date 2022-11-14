// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "hardhat/console.sol";

import {ContentBaseStorageV1} from "./ContentBaseStorageV1.sol";
import {IBaseV1} from "./IBaseV1.sol";
import {Validations} from "./libraries/Validations.sol";
import {ProfileLogic} from "./libraries/ProfileLogic.sol";
import {FollowLogic} from "./libraries/FollowLogic.sol";
import {PublishLogic} from "./libraries/PublishLogic.sol";
import {CommentLogic} from "./libraries/CommentLogic.sol";
import {LikeLogic} from "./libraries/LikeLogic.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {Helpers} from "./libraries/Helpers.sol";

abstract contract BaseV1 is
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ContentBaseStorageV1,
    IBaseV1
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /**
     *  ***** ADMIN RELATED FUNCTIONS *****
     */

    /**
     * @inheritdoc IBaseV1
     */
    function updateLikeFee(uint256 fee) external override onlyRole(ADMIN_ROLE) {
        likeFee = fee;
    }

    /**
     * @inheritdoc IBaseV1
     */
    function updatePlatformFee(uint24 fee)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        platformFee = fee;
    }

    /**
     * @inheritdoc IBaseV1
     */
    function withdraw() external override onlyRole(ADMIN_ROLE) {
        require(platformOwner != address(0), "Owner address not set");
        payable(platformOwner).transfer(address(this).balance);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
