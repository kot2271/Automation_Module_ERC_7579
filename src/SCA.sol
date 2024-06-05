// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "node_modules/@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "node_modules/erc7579/src/lib/ModeLib.sol";
import {ExecutionLib} from "node_modules/erc7579/src/lib/ExecutionLib.sol";
import {ExecutionHelper} from "node_modules/erc7579/src/core/ExecutionHelper.sol";
import {IERC7579Account} from "node_modules/erc7579/src/interfaces/IERC7579Account.sol";
import {IMSA} from "node_modules/erc7579/src/interfaces/IMSA.sol";
import "node_modules/erc7579/src/interfaces/IERC7579Module.sol";
import {ModuleManager} from "node_modules/erc7579/src/core/ModuleManager.sol";
import {IDittoEntryPoint} from "./interfaces/IDittoEntryPoint.sol";
import {AccountAccessControl} from "src/core/AccountAccessControl.sol";

/**
 * @title SCA (Smart Account Contract)
 * @dev Implementation of the SCA contract
 *
 * It is a contract designed to automate the execution of multiple smart contracts.
 * The contract is designed to be flexible and customizable.
 * It allows users to define the workflows and the order of execution of the contracts.
 *
 * The contract is designed to be secure and reliable. It uses the OpenZeppelin
 * library for initializable and the ERC7579 standard for module management.
 * It also uses the ERC7579 library for execution management.
 */
contract SCA is
    IMSA,
    ExecutionHelper,
    ModuleManager,
    AccountAccessControl,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    using ExecutionLib for bytes;
    using ModeLib for ModeCode;

    // The owner role identifier
    // Only the owner has the right to initialize the contract, grant roles and execute workflows
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    // The module installer role identifier
    // Only the module installer has the right to install modules
    bytes32 private constant MODULE_INSTALLER_ROLE =
        keccak256("INITIALIZER_ROLE");

    // The payer role identifier
    // Only the payer has the right to pay for the execution of contracts
    bytes32 public constant PAYER_ROLE = keccak256("PAYER_ROLE");

    // Mapping to store data for each workflow
    mapping(uint256 => DataStorage) private workflowsData;

    /**
     * @dev Struct to hold data for each workflow
     */
    struct DataStorage {
        bytes data;
    }

    /**
     * @dev The address of the owner of the contract.
     * The owner has the right to initialize the contract, grant roles and execute workflows.
     */
    address private _owner;

    /**
     * @dev Modifier that checks if the caller has the role of module installer.
     * Only the module installer role has the right to install modules.
     */
    modifier _OnlyModuleInstaller() {
        if (!hasRole(MODULE_INSTALLER_ROLE, msg.sender)) {
            revert OnlyModuleInstallerCanAccess();
        }
        _;
    }

    /**
     * @dev Modifier that checks if the caller has the role of owner.
     * Only the owner has the right to grant roles.
     */
    modifier _onlyOwner() {
        if (!hasRole(OWNER_ROLE, msg.sender)) {
            revert OnlyOwnerCanGrantRole();
        }
        _;
    }

    /**
     * @dev Initializes the contract with the entrypoint and owner addresses
     * @param _initialOwner The address of the owner of the contract
     */
    function initialize(address _initialOwner) public initializer {
        require(
            msg.sender == _initialOwner,
            "SCA: Only owner can initialize the contract"
        );
        _owner = _initialOwner;
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        _grantRole(OWNER_ROLE, _owner);
        _grantRole(PAYER_ROLE, address(this));
    }

    /**
     * @dev Grants the module installer role to the specified account.
     * @param account The address to grant the module installer role to.
     */
    function grantModuleInstallerRole(address account) external _onlyOwner {
        _grantRole(MODULE_INSTALLER_ROLE, account);
        emit RoleGrantedSuccessfully(
            MODULE_INSTALLER_ROLE,
            account,
            msg.sender
        );
    }

    /**
     * @dev Registers a workflow in the DEP contract.
     * @param workflowId The unique identifier of the workflow.
     * @param dep The address of the DEP contract.
     */
    function registerWorkflowInDep(uint256 workflowId, address dep) external {
        (bool success, ) = dep.call(
            abi.encodeWithSignature("registerWorkflow(uint256)", workflowId)
        );
        if (success) {
            emit RunWorkflowRegistrationInDep(dep, workflowId);
        } else {
            revert RunWorkflowRegistrationFailed(workflowId);
        }
    }

    /**
     * @dev Transfer the specified amount of Ether to the recipient.
     * @param recipient The address of the recipient.
     * @param amount The amount of Ether to transfer.
     */
    function transfer(address recipient, uint256 amount) external payable {
        require(
            hasRole(PAYER_ROLE, msg.sender),
            "SCA: Only payer can transfer"
        );
        require(address(this).balance >= amount, "SCA: Insufficient balance");
        payable(recipient).transfer(amount);
    }

    /**
     * Saves data for automation
     * @param workflowId Unique workflow identifier
     * @param data Data for automation
     */
    function saveWorkflowData(
        uint256 workflowId,
        bytes calldata data
    ) external {
        workflowsData[workflowId].data = data;
        emit DataSaved(workflowId, workflowsData[workflowId].data);
    }

    /**
     * Performs saved automation data
     * @param workflowId Unique workflow identifier
     */
    function executeWorkflow(uint256 workflowId) external {
        bytes memory data = workflowsData[workflowId].data;
        if (data.length > 0) {
            (bool success, ) = address(this).call(data);
            if (success) {
                // delete workflowsData[workflowId];
                emit WorkflowExecuted(workflowId);
            } else {
                revert WorkflowExecutionFailed();
            }
        } else {
            revert EmptyWorkflowData();
        }
    }

    /**
     * @inheritdoc IERC7579Account
     */
    function execute(
        ModeCode mode,
        bytes calldata executionCalldata
    ) external payable onlyEntryPointOrSelf {
        CallType callType = mode.getCallType();

        if (callType == CALLTYPE_BATCH) {
            Execution[] calldata executions = executionCalldata.decodeBatch();
            _execute(executions);
        } else if (callType == CALLTYPE_SINGLE) {
            (
                address target,
                uint256 value,
                bytes calldata callData
            ) = executionCalldata.decodeSingle();
            _execute(target, value, callData);
        } else {
            revert UnsupportedCallType(callType);
        }
    }

    /**
     * @inheritdoc IERC7579Account
     */
    function executeFromExecutor(
        ModeCode mode,
        bytes calldata executionCalldata
    ) external payable onlyExecutorModule returns (bytes[] memory returnData) {
        CallType callType = mode.getCallType();

        if (callType == CALLTYPE_BATCH) {
            Execution[] calldata executions = executionCalldata.decodeBatch();
            returnData = _execute(executions);
        } else if (callType == CALLTYPE_SINGLE) {
            (
                address target,
                uint256 value,
                bytes calldata callData
            ) = executionCalldata.decodeSingle();
            returnData = new bytes[](1);
            returnData[0] = _execute(target, value, callData);
        } else {
            revert UnsupportedCallType(callType);
        }
    }

    /**
     * @dev ERC-4337 executeUserOp according to ERC-4337 v0.7
     *         This function is intended to be called by ERC-4337 EntryPoint.sol
     * @dev Ensure adequate authorization control: i.e. onlyEntryPointOrSelf
     *      The implementation of the function is OPTIONAL
     *
     * @param userOp PackedUserOperation struct (see ERC-4337 v0.7+)
     */
    function executeUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external payable override onlyEntryPoint {
        bytes calldata callData = userOp.callData[4:];
        (bool success, ) = address(this).delegatecall(callData);
        if (!success) revert ExecutionFailed();
    }

    /**
     * @inheritdoc IERC7579Account
     */
    function installModule(
        uint256 moduleTypeId,
        address module,
        bytes calldata initData
    ) external payable _OnlyModuleInstaller {
        if (!IModule(module).isModuleType(moduleTypeId))
            revert MismatchModuleTypeId(moduleTypeId);

        if (moduleTypeId == MODULE_TYPE_VALIDATOR)
            _installValidator(module, initData);
        else if (moduleTypeId == MODULE_TYPE_EXECUTOR)
            _installExecutor(module, initData);
        else if (moduleTypeId == MODULE_TYPE_FALLBACK)
            _installFallbackHandler(module, initData);
        else revert UnsupportedModuleType(moduleTypeId);
        emit ModuleInstalled(moduleTypeId, module);
    }

    /**
     * @inheritdoc IERC7579Account
     */
    function uninstallModule(
        uint256 moduleTypeId,
        address module,
        bytes calldata deInitData
    ) external payable onlyEntryPointOrSelf {
        if (moduleTypeId == MODULE_TYPE_VALIDATOR) {
            _uninstallValidator(module, deInitData);
        } else if (moduleTypeId == MODULE_TYPE_EXECUTOR) {
            _uninstallExecutor(module, deInitData);
        } else if (moduleTypeId == MODULE_TYPE_FALLBACK) {
            _uninstallFallbackHandler(module, deInitData);
        } else {
            revert UnsupportedModuleType(moduleTypeId);
        }
        emit ModuleUninstalled(moduleTypeId, module);
    }

    /**
     * @inheritdoc IERC7579Account
     * @param additionalContext is not needed here. It is only used in cases where the modules are
     * stored in more complex mappings
     */
    function isModuleInstalled(
        uint256 moduleTypeId,
        address module,
        bytes calldata additionalContext
    ) external view override returns (bool isInstalled) {
        if (moduleTypeId == MODULE_TYPE_VALIDATOR) {
            return _isValidatorInstalled(module);
        } else if (moduleTypeId == MODULE_TYPE_EXECUTOR) {
            return _isExecutorInstalled(module);
        } else if (moduleTypeId == MODULE_TYPE_FALLBACK) {
            return
                _isFallbackHandlerInstalled(
                    abi.decode(additionalContext, (bytes4)),
                    module
                );
        } else {
            return false;
        }
    }

    /**
     * @dev ERC-4337 validateUserOp according to ERC-4337 v0.7
     *         This function is intended to be called by ERC-4337 EntryPoint.sol
     * this validation function should decode / sload the validator module to validate the userOp
     * and call it.
     *
     * @dev MSA MUST implement this function signature.
     * @param userOp PackedUserOperation struct (see ERC-4337 v0.7+)
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        payable
        virtual
        onlyEntryPoint
        payPrefund(missingAccountFunds)
        returns (uint256 validSignature)
    {
        address validator;
        // @notice validator encoding in nonce is just an example!
        // @notice this is not part of the standard!
        // Account Vendors may choose any other way to implement validator selection
        uint256 nonce = userOp.nonce;
        assembly {
            validator := shr(96, nonce)
        }

        // check if validator is enabled. If not terminate the validation phase.
        if (!_isValidatorInstalled(validator)) return VALIDATION_FAILED;

        // bubble up the return value of the validator module
        validSignature = IValidator(validator).validateUserOp(
            userOp,
            userOpHash
        );
    }

    /**
     * @dev ERC-1271 isValidSignature
     *         This function is intended to be used to validate a smart account signature
     * and may forward the call to a validator module
     *
     * @param hash The hash of the data that is signed
     * @param data The data that is signed
     */
    function isValidSignature(
        bytes32 hash,
        bytes calldata data
    ) external view virtual override returns (bytes4) {
        address validator = address(bytes20(data[0:20]));
        if (!_isValidatorInstalled(validator)) revert InvalidModule(validator);
        return
            IValidator(validator).isValidSignatureWithSender(
                msg.sender,
                hash,
                data[20:]
            );
    }

    /**
     * @inheritdoc IERC7579Account
     */
    function accountId()
        external
        view
        virtual
        override
        returns (string memory)
    {
        return "sca.base.v0.0.1";
    }

    /**
     * @inheritdoc IERC7579Account
     */
    function supportsExecutionMode(
        ModeCode mode
    ) external view virtual override returns (bool) {
        CallType callType = mode.getCallType();
        if (callType == CALLTYPE_BATCH) return true;
        else if (callType == CALLTYPE_SINGLE) return true;
        else return false;
    }

    /**
     * @inheritdoc IERC7579Account
     */
    function supportsModule(
        uint256 modulTypeId
    ) external view virtual override returns (bool) {
        if (modulTypeId == MODULE_TYPE_VALIDATOR) return true;
        else if (modulTypeId == MODULE_TYPE_EXECUTOR) return true;
        else if (modulTypeId == MODULE_TYPE_FALLBACK) return true;
        else return false;
    }

    /**
     * @dev Initializes the account. Function might be called directly, or by a Factory
     * @param data. encoded data that can be used during the initialization phase
     */
    function initializeAccount(bytes calldata data) public payable virtual {
        // checks if already initialized and reverts before setting the state to initialized
        _initModuleManager();

        // this is just implemented for demonstration purposes. You can use any other initialization
        // logic here.
        (address bootstrap, bytes memory bootstrapCall) = abi.decode(
            data,
            (address, bytes)
        );
        (bool success, ) = bootstrap.delegatecall(bootstrapCall);
        if (!success) revert AccountInitializationFailed();
    }

    /**
     * @dev Internal function to authorize the upgrade of the contract implementation.
     * Only the owner can call this function.
     * @param newImplementation The address of the new implementation to be authorized.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {
        require(
            newImplementation != address(0),
            "Invalid implementation address"
        );

        emit UpgradeAuthorized(newImplementation);
    }
}
