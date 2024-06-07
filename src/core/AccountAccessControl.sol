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
    error OnlyOwnerCanAccess();

    /**
     * @dev Error thrown when the registration of a workflow in the DEP contract fails
     * @param workflowId The ID of the workflow that failed to be registered
     */
    error RunWorkflowRegistrationFailed(uint256 workflowId);
}
