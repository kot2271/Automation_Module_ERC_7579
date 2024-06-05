// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IDittoEntryPoint} from "src/interfaces/IDittoEntryPoint.sol";

/**
 * @title AccountAccessControl
 * @dev Provides modifiers for restricting access control to the contract and its entry points.
 */
contract AccountAccessControl {
    /**
     * @dev Event emitted when data is saved for a workflow
     * @param workflowId The ID of the workflow
     * @param data The data saved for the workflow
     */
    event DataSaved(uint256 workflowId, bytes data);

    /**
     * @dev Event emitted when a workflow is executed
     * @param workflowId The ID of the workflow
     */
    event WorkflowExecuted(uint256 workflowId);

    /**
     * @dev Emitted when an implementation is authorized to be upgraded to.
     * @param implementation The address of the new implementation that is authorized to be upgraded to.
     */
    event UpgradeAuthorized(address implementation);

    /**
     * @dev Event emitted when a role is granted to an account by another account.
     * @param role The role that was granted.
     * @param account The account that received the role.
     * @param sender The account that granted the role.
     */
    event RoleGrantedSuccessfully(
        bytes32 role,
        address account,
        address sender
    );

    /**
     * @dev Event emitted when a workflow is registered in the DEP contract.
     * @param dep The address of the DEP contract.
     * @param workflowId The ID of the workflow that was registered.
     */
    event RunWorkflowRegistrationInDep(address dep, uint256 workflowId);

    // Error thrown when the caller is not authorized.
    error AccountAccessControlUnauthorized();

    /**
     * @dev Error thrown when a workflow execution fails
     */
    error WorkflowExecutionFailed();

    /**
     * @dev Error thrown when workflow data is empty
     */
    error EmptyWorkflowData();

    /**
     * @dev Error thrown when an attempt is made to grant a role by an account other than the owner.
     */
    error OnlyOwnerCanGrantRole();

    /**
     * @dev Error thrown when an attempt is made to access a function that is meant to be accessed only by the module installer.
     */
    error OnlyModuleInstallerCanAccess();

    /**
     * @dev Error thrown when the registration of a workflow in the DEP contract fails
     * @param workflowId The ID of the workflow that failed to be registered
     */
    error RunWorkflowRegistrationFailed(uint256 workflowId);

    /**
     * @dev Modifier that allows the function to be called only by the entry point or the contract itself.
     * @param entryPoint Address of the entry point.
     */
    modifier onlyEntryPointOrSelf_(address entryPoint) virtual {
        if (
            !(msg.sender == getEntryPointAddress(entryPoint) ||
                msg.sender == address(this))
        ) {
            revert AccountAccessControlUnauthorized();
        }
        _;
    }

    /**
     * @dev Modifier that allows the function to be called only by the entry point.
     * @param entryPoint Address of the entry point.
     */
    modifier onlyEntryPoint_(address entryPoint) virtual {
        if (msg.sender != getEntryPointAddress(entryPoint)) {
            revert AccountAccessControlUnauthorized();
        }
        _;
    }

    /**
     * @dev Returns the address of the entry point.
     * @param entryPoint Address of the entry point.
     * @return The address of the entry point.
     */
    function getEntryPointAddress(
        address entryPoint
    ) public view virtual returns (address) {
        return address(entryPoint);
    }
}
