// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IDittoEntryPoint} from "src/interfaces/IDittoEntryPoint.sol";

/**
 * @title AccountAccessControl
 * @dev Provides modifiers for restricting access control to the contract and its entry points.
 */
contract AccountAccessControl {
    // Error thrown when the caller is not authorized.
    error AccountAccessControlUnauthorized();

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
