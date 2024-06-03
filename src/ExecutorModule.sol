// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC7579ExecutorBase} from "node_modules/@rhinestone/modulekit/src/Modules.sol";
import {IERC7579Account} from "node_modules/erc7579/src/interfaces/IERC7579Account.sol";
import {ModeLib} from "node_modules/erc7579/src/lib/ModeLib.sol";

/**
 * @title ExecutorModule
 * @dev This module is responsible for handling the execution of ERC7579
 * transactions. It is a part of the ERC7579 framework.
 */
contract ExecutorModule is ERC7579ExecutorBase {
    // Mapping to keep track of accounts that have been initialized with data
    mapping(address => bool) private initializedAccounts;

    // Mapping to store the installation data for each account
    mapping(address => InstallData) private installationData;

    /**
     * @dev Struct to store the installation data for each account.
     * @param data The data associated with the installation.
     */
    struct InstallData {
        bytes data;
    }

    /**
     * @dev Event emitted when a workflow is executed successfully.
     * @param workflowId The ID of the workflow that was executed.
     */
    event StartExecuteWorkflow(uint256 indexed workflowId);

    /**
     * @dev Error thrown when a workflow execution fails.
     * @param workflowId The ID of the workflow that failed to execute.
     */
    error StartExecuteWorkflowFailed(uint256 workflowId);

    /**
     * @dev Constructor for the ExecutorModule
     */
    constructor() ERC7579ExecutorBase() {}

    /**
     * Initializes the module with data
     * @param data Data to initialize the module
     */
    function onInstall(bytes calldata data) external override {
        initializedAccounts[msg.sender] = true;
        installationData[msg.sender].data = data;
    }

    /**
     * Deinisializes the module with data
     * @param data Data for deinocialization of the module
     */
    function onUninstall(bytes calldata data) external override {
        initializedAccounts[msg.sender] = false;
        bytes memory storedData = installationData[msg.sender].data;
        require(
            keccak256(storedData) == keccak256(data),
            "Invalid data for uninstallation"
        );
        delete installationData[msg.sender];
    }

    /**
     * @dev Executes a workflow on a vault contract.
     * @param workflowId The ID of the workflow to be executed.
     * @param vaultAddress The address of the vault contract.
     */
    function startExecuteWorkflow(
        uint256 workflowId,
        address vaultAddress
    ) external {
        require(initializedAccounts[vaultAddress], "Account not initialized");

        // Call the executeWorkflow function on the sca contract
        (bool success, ) = vaultAddress.call(
            abi.encodeWithSelector(
                bytes4(keccak256("executeWorkflow(uint256)")),
                workflowId
            )
        );

        if (success) {
            emit StartExecuteWorkflow(workflowId);
        } else {
            revert StartExecuteWorkflowFailed(workflowId);
        }
    }

    /**
     * Checks whether the module is initialized
     * @param smartAccount Smart account address for verification
     * @return true If the module initiated, inaccesses false
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        return initializedAccounts[smartAccount];
    }

    /**
     * @return name The name of the module
     */
    function name() external pure returns (string memory) {
        return "ExecutorModule";
    }

    /**
     * @return version The version of the module
     */
    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    /**
     * Checks whether a module of a certain type is a module
     * @param typeID Type identifier for verification
     * @return true If a module of this type, otherwise false
     */
    function isModuleType(
        uint256 typeID
    ) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }
}
