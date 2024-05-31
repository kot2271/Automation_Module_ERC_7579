// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "src/SCAFactory.sol";
import "src/SCA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployAndVerify is Script {
    address private scaImplementation;

    function setUp() public {}

    function run() public {
        // Load environment variables
        // string memory rpcUrl = vm.envString("POLYGON_MUMBAI_RPC_URL");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Set the deployer account using the private key
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the SCA contract
        scaImplementation = address(new SCA());
        console.log("SCA implementation deployed at:", scaImplementation);

        // Deploy the SCAFactory contract with the address of the SCA implementation
        SCAFactory scaFactory = new SCAFactory(scaImplementation);
        console.log("SCAFactory deployed at:", address(scaFactory));

        // Verify the contracts on PolygonScan
        verifyContract(scaImplementation, "src/SCA.sol:SCA", "");
        verifyContract(
            address(scaFactory),
            "src/SCAFactory.sol:SCAFactory",
            abi.encode(scaImplementation)
        );

        vm.stopBroadcast();
    }

    function verifyContract(
        address contractAddress,
        string memory contractName,
        bytes memory constructorArguments
    ) internal {
        // Verification logic here
        uint256 polygonScanApiKey = vm.envUint("POLYGONSCAN_API_KEY");
        string[] memory args = new string[](8);
        args[0] = "forge";
        args[1] = "verify-contract";
        args[2] = "--chain-id";
        args[3] = "80002"; // Polygon Mumbai Chain ID
        args[4] = "--compiler-version";
        args[5] = "v0.8.25+commit.d9974bed"; // Solidity compiler version
        args[6] = string(abi.encodePacked(contractAddress, ":", contractName));
        args[7] = Strings.toString(polygonScanApiKey);

        if (constructorArguments.length > 0) {
            string memory constructorArgsEncoded = string(
                abi.encodePacked(constructorArguments)
            );
            args[8] = constructorArgsEncoded;
        }

        // Execute the verification command
        vm.ffi(args);
    }
}
