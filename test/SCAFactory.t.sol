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

    //Events
    event ModuleInstalled(uint256 moduleTypeId, address module);
    event DataSaved(uint256 workflowId, bytes data);
    event WorkflowRegistered(address vaultAddress, uint256 workflowId);
    event WorkflowExecuted(uint256 workflowId);

    function setUp() public {
        // Deployment of the DEP contract
        dep = new DEP();

        // Deployment of the SCA contract
        sca = new SCA();
        factory = new SCAFactory(address(sca));
        vm.prank(address(factory));
        sca.initialize(address(dep), address(factory));

        // Deployment of the ExecutorModule
        executorModule = new ExecutorModule();
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
        vm.prank(address(sca));
        address scaAccount = factory.createAccount(salt, initCode);

        // Module connection to SCA
        uint256 moduleTypeId = 2;
        bytes memory initData = abi.encodePacked("install", "data");

        vm.prank(address(dep));
        sca.installModule(moduleTypeId, address(executorModule), initData);

        // Preservation of automation data in the SCA module
        uint256 workflowId = 1;
        bytes memory data = abi.encodeWithSignature(
            "saveWorkflowData(uint256,bytes)",
            workflowId,
            "workflowData"
        );
        vm.prank(scaAccount);
        vm.expectEmit(true, true, true, false);
        emit DataSaved(workflowId, data);
        (bool success, ) = scaAccount.call(
            abi.encodeWithSelector(
                bytes4(keccak256("saveWorkflowData(uint256,bytes)")),
                workflowId,
                data
            )
        );
        require(success, "Save workflow_data failed");

        // Registration of the workflow in DEP
        vm.prank(scaAccount);
        dep.registerWorkflow(workflowId);

        // Run of the workflow process
        vm.prank(address(dep));
        vm.expectEmit(true, true, true, false);
        emit WorkflowExecuted(workflowId);
        dep.runWorkflow(scaAccount, workflowId);
    }
}
