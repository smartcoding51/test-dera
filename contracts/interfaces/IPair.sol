// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
}