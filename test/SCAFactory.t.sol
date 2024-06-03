// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "lib/forge-std/src/Test.sol";
import "lib/forge-std/src/console.sol";
import "../src/SCAFactory.sol";
import "../src/SCA.sol";
import "../src/ExecutorModule.sol";
import "../src/DEP.sol";

contract SCAFactoryTest is Test {
    SCAFactory factory;
    SCA sca;
    ExecutorModule executorModule;
    DEP dep;
    SCA scaAccount;
    address scaOwner = makeAddr("SCA_OWNER");

    //Events
    event ModuleInstalled(uint256 moduleTypeId, address module);
    event DataSaved(uint256 workflowId, bytes data);
    event WorkflowRegistered(
        address indexed vaultAddress,
        uint256 indexed workflowId
    );
    event WorkflowExecuted(uint256 workflowId);

    error AccountAccessControlUnauthorized();

    function setUp() public {
        // Deployment of the ExecutorModule
        executorModule = new ExecutorModule();

        // Deployment of the DEP contract
        dep = new DEP(address(executorModule));

        // Deployment of the SCA contract
        sca = new SCA();
        factory = new SCAFactory(address(sca), address(dep));
        vm.prank(address(factory));
        sca.initialize(address(dep), address(factory));
    }

    function testDeployScaAndFactory() public view {
        // Check that the sca contract was deployed successfully
        console.logAddress(address(sca));
        assert(address(sca) != address(0));

        // Check that the factory contract was deployed successfully
        console.logAddress(address(factory));
        assert(address(factory) != address(0));
    }

    function testDeployModule() public view {
        // Check that the executorModule contract was deployed successfully
        console.logAddress(address(executorModule));
        assert(address(executorModule) != address(0));
    }

    function testInstallModuleInSca() public {
        // Module connection to SCA
        uint256 moduleTypeId = 2;
        bytes memory initData = abi.encodePacked("install", "data");

        vm.prank(address(dep));

        vm.expectEmit(true, true, true, false);
        emit ModuleInstalled(moduleTypeId, address(executorModule));

        sca.installModule(moduleTypeId, address(executorModule), initData);
    }

    function testCreateAndExecuteAutomation() public {
        // Creating a smart account
        bytes32 salt = keccak256("salt");
        bytes memory initCode = abi.encodeWithSignature(
            "initializeAccount(bytes)",
            "initData"
        );
        vm.prank(address(scaOwner));
        address scaAccountAddress = factory.createAccount(salt, initCode);

        scaAccount = SCA(payable(scaAccountAddress));

        // Module connection to SCA
        uint256 moduleTypeId = 2;
        bytes memory initData = abi.encodePacked("install", "data");

        vm.prank(address(dep));
        scaAccount.installModule(
            moduleTypeId,
            address(executorModule),
            initData
        );

        assertTrue(executorModule.isInitialized(address(scaAccount)));

        // Preservation of automation data in the SCA module
        uint256 workflowId = 1;
        bytes memory data = abi.encodeWithSignature(
            "saveWorkflowData(uint256,bytes)",
            workflowId,
            "workflowData"
        );
        vm.prank(address(scaOwner));
        vm.expectEmit(true, true, true, false);
        emit DataSaved(workflowId, data);
        scaAccount.saveWorkflowData(workflowId, data);

        // Registration of the workflow in DEP
        vm.prank(address(scaAccount));
        dep.registerWorkflow(workflowId);

        // Run of the workflow process
        vm.prank(address(scaAccount));
        vm.expectEmit(true, true, true, false);
        emit WorkflowExecuted(workflowId);
        dep.runWorkflow(address(scaAccount), workflowId);
    }

    function testFailureInstallModuleInSca() public {
        // Creating a smart account
        bytes32 salt = keccak256("salt");
        bytes memory initCode = abi.encodeWithSignature(
            "initializeAccount(bytes)",
            "initData"
        );
        vm.prank(address(scaOwner));
        address scaAccountAddress = factory.createAccount(salt, initCode);

        scaAccount = SCA(payable(scaAccountAddress));

        // Module connection to SCA
        uint256 moduleTypeId = 2;
        bytes memory initData = abi.encodePacked("install", "data");

        vm.prank(address(sca));
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("AccountAccessControlUnauthorized"))
            )
        );
        scaAccount.installModule(
            moduleTypeId,
            address(executorModule),
            initData
        );

        assertFalse(executorModule.isInitialized(address(scaAccount)));
    }
}
