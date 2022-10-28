// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.9;

import {DataTypes} from "../../libraries/DataTypes.sol";
import {Constants} from "../../libraries/Constants.sol";

interface ILikeNFT {
    /**
     * An external function to set Profile contract.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     * @param profileContractAddress - an address of the Profile contract
     */
    function setProfileContract(address profileContractAddress) external;

    /**
     * An external function to set Publish contract.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     * @param publishContractAddress - an address of the Publish contract
     */
    function setPublishContract(address publishContractAddress) external;

    /**
     * An external function to set contract owner address.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     * @param owner - an address of the owner
     */
    function setOwnerAddress(address owner) external;

    /**
     * An external function to get contract owner address.
     * @return owner {address}
     */
    function getContractOwnerAddress() external view returns (address);

    /**
     * An external function to withdraw the contract's balance.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     */
    function withdraw() external;

    /**
     * An external function to set like fee.
     * @dev make sure to add modifier to only ADMIN_ROLE.
     * @param amount {uint} - an amount to be sent when some profile likes a Publish
     */
    function setLikeFee(uint amount) external;

    /**
     * An external function to get like fee.
     * @return amount {uint}
     */
    function getLikeFee() external view returns (uint);

    /**
     * An external function to set operational fee for the platform.
     * @dev  make sure to add modifier to only ADMIN_ROLE.
     * @param fee - operational fee
     */
    function setPlatformFee(uint fee) external;

    /**
     * An external function to get operational fee for the platform.
     * @return fee {uint}
     */
    function getPlatformFee() external view returns (uint);

    // /**
    //  * An external function to check contract's balance.
    //  * @dev  make sure to add modifier to only ADMIN_ROLE.
    //  * @return balance {uint}
    //  */
    // function getContractBalance() external view returns (uint);

    /**
     * An external function to receive like fee for a Publish NFT.
     * @param createLikeData {DataTypes.CreateLikeData}
     */
    function like(DataTypes.CreateLikeData calldata createLikeData)
        external
        payable;
}
