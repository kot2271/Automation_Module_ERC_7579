// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// Interface for the DittoEntryPoint DEP contract
interface IDittoEntryPoint {
    // Defines the structure for tracking workflows in the system
    struct Workflow {
        address vaultAddress; // Address of the vault (SCA) associated with the workflow
        uint256 workflowId; // Unique identifier for the workflow
    }

    /**
     * @dev Event emitted when a workflow is registered.
     * @param vaultAddress The address of the vault (SCA) associated with the workflow.
     * @param workflowId The unique identifier for the workflow.
     */
    event WorkflowRegistered(
        address indexed vaultAddress,
        uint256 indexed workflowId
    );

    /**
     * @dev Event emitted when a workflow is executed.
     * @param workflowId The unique identifier for the workflow.
     */
    event WorkflowExecuted(uint256 indexed workflowId);

    /**
     * @dev Error thrown when a workflow execution fails.
     * @param workflowId The unique identifier for the workflow.
     */
    error WorkflowExecFailed(uint256 workflowId);

    // Registers a workflow associated with a vault
    function registerWorkflow(uint256 workflowId) external;

    // Executes a workflow
    function runWorkflow(address vaultAddress, uint256 workflowId) external;

    // Cancels a workflow and removes it from active workflows
    function cancelWorkflow(uint256 workflowId) external;
}
