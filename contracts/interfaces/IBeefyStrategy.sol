// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBeefyStrategy {
    function vault() external view returns (address);
    function want() external view returns (IERC20);
    function unirouter() external view returns (address);
    function lpToken0() external view returns (address);
    function lpToken1() external view returns (address);
    function outputToLp0Route() external view returns (address[] memory);
    function outputToLp1Route() external view returns (address[] memory);
}
