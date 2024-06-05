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
    event RoleGrantedSuccessfully(
        bytes32 role,
        address account,
        address sender
    );

    // Errors
    error OnlyModuleInstallerCanAccess();

    function setUp() public {
        vm.startPrank(scaOwner);

        // Deployment of the ExecutorModule
        executorModule = new ExecutorModule();

        // Deployment of the DEP contract
        dep = new DEP(address(executorModule));

        // Deployment of the SCA contract
        sca = new SCA();
        factory = new SCAFactory(address(sca));
        sca.initialize(address(scaOwner));

        vm.stopPrank();
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
        vm.startPrank(scaOwner);

        // Creating a smart account
        bytes32 salt = keccak256("salt");
        bytes memory initCode = abi.encodeWithSignature(
            "initializeAccount(bytes)",
            "initData"
        );
        address scaAccountAddress = factory.createAccount(salt, initCode);

        scaAccount = SCA(payable(scaAccountAddress));

        // Module connection to SCA
        uint256 moduleTypeId = 2;
        bytes memory initData = abi.encodePacked("install", "data");

        vm.expectEmit(true, true, true, false);
        emit ModuleInstalled(moduleTypeId, address(executorModule));
        scaAccount.installModule(
            moduleTypeId,
            address(executorModule),
            initData
        );

        vm.stopPrank();

        assertTrue(executorModule.isInitialized(address(scaAccount)));
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

        vm.prank(address(scaOwner));
        scaAccount.installModule(
            moduleTypeId,
            address(executorModule),
            initData
        );

        assertTrue(executorModule.isInitialized(address(scaAccount)));

        // Preservation of automation data in the SCA module
        address recipient = makeAddr("RECIPIENT");
        assertEq(recipient.balance, 0);

        uint256 workflowId = 1;
        uint256 amount = 10 ether;
        bytes memory transferData = abi.encodeWithSignature(
            "transfer(address,uint256)",
            recipient,
            amount
        );

        vm.prank(address(scaOwner));
        vm.expectEmit(true, true, true, false);
        emit DataSaved(workflowId, transferData);
        scaAccount.saveWorkflowData(workflowId, transferData);

        // Registration of the workflow in DEP
        vm.prank(address(scaOwner));
        scaAccount.registerWorkflowInDep(workflowId, address(dep));

        deal(address(scaAccount), amount);
        assertEq(address(scaAccount).balance, amount);

        // Run of the workflow process
        vm.prank(address(scaOwner));
        vm.expectEmit(true, true, true, false);
        emit WorkflowExecuted(workflowId);
        dep.runWorkflow(address(scaAccount), workflowId);

        assertEq(recipient.balance, amount);
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
                bytes4(keccak256("OnlyModuleInstallerCanAccess"))
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
