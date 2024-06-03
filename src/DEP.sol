// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./interfaces/IDittoEntryPoint.sol";

/**
 * @title DEP (Ditto Entry Point) is a contract that acts as an entry point for the Ditto protocol.
 * @notice It provides functionality for registering and maintaining the security of the workflows (SCA) related to storage.
 * The DEP contract is responsible for validating the workflows, preventing unauthorized access, and ensuring the
 * security of the data stored in the workflows.
 */
contract DEP is IDittoEntryPoint {
    // Mapping to store data for each workflow
    mapping(uint256 => Workflow) private workflows;

    // The address of the ExecutorModule contract
    address public immutable executorModule;

    // Constructor of the contract
    constructor(address _executorModule) IDittoEntryPoint() {
        executorModule = _executorModule;
    }

    /**
     * Records the storage related workflow (SCA)
     * @param workflowId Unique workflow identifier
     */
    function registerWorkflow(uint256 workflowId) external override {
        require(
            workflows[workflowId].vaultAddress == address(0),
            "Workflow already registered"
        );

        workflows[workflowId] = Workflow(msg.sender, workflowId);

        emit WorkflowRegistered(
            workflows[workflowId].vaultAddress,
            workflows[workflowId].workflowId
        );
    }

    /**
     * Performs the workflow
     * @param vaultAddress Address storage (SCA)
     * @param workflowId Unique workflow identifier
     */
    function runWorkflow(
        address vaultAddress,
        uint256 workflowId
    ) external override {
        require(
            workflows[workflowId].vaultAddress == vaultAddress,
            "Invalid address for workflow"
        );

        // Call the execute function in the ExecutorModule
        (bool success, ) = executorModule.call(
            abi.encodeWithSignature(
                "startExecuteWorkflow(uint256,address)",
                workflowId,
                vaultAddress
            )
        );

        if (success) {
            emit WorkflowExecutedSuccessfully(workflowId);
        } else {
            revert WorkflowExecFailed(workflowId);
        }
    }

    /**
     * Cancels the workflow and removes it from active
     * @param workflowId Unique workflow identifier
     */
    function cancelWorkflow(uint256 workflowId) external override {
        Workflow memory workflow = workflows[workflowId];
        require(
            workflow.vaultAddress == msg.sender,
            "Only the vault can cancel its workflow"
        );

        delete workflows[workflowId];
    }
}
