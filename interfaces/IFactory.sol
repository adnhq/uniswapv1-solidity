// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IFactory {
    error ZeroAddress();
    error ExchangeAlreadyExists();

    event NewExchange(address indexed token, address indexed exchange);

    function createExchange(address token) external returns (address);
    function getExchange(address token) external view returns (address);
    function getToken(address exchange) external view returns (address);
    function getTokenWithId(uint256 id) external view returns (address);
}
