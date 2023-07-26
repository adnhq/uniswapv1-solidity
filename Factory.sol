// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Exchange} from "./Exchange.sol";
import {IFactory} from "./interfaces/IFactory.sol";

contract Factory is IFactory {
    uint256 public tokenCount;

    mapping(address => address) private _tokenToExchange;
    mapping(address => address) private _exchangeToToken;
    mapping(uint256 => address) private _idToToken;

    function createExchange(address token) public returns (address) {
        if(token == address(0)) revert ZeroAddress();
        if(_tokenToExchange[token] != address(0)) revert ExchangeAlreadyExists();
        
        address exchange = address(new Exchange(token));

        _tokenToExchange[token] = exchange;
        _exchangeToToken[exchange] = token;
        _idToToken[++tokenCount] = token;

        emit NewExchange(token, exchange);

        return exchange;
    }

    function getExchange(address token) public view returns (address) {
        return _tokenToExchange[token];
    }

    function getToken(address exchange) public view returns (address) {
        return _exchangeToToken[exchange];
    }

    function getTokenWithId(uint256 id) public view returns (address) {
        return _idToToken[id];
    }
}
