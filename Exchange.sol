// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {ERC20} from "./ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IExchange} from "./interfaces/IExchange.sol";

/**
 * @author 0xHawkyne
 * @notice Streamlined UniswapV1 implementation in solidity
 * Documentation for original contract at: https://github.com/Uniswap/v1-contracts/blob/master/contracts/uniswap_exchange.vy
 * This contract only performs unidirectional trades, ie. get optimal output amount for a specified input amount
 */
contract Exchange is IExchange, ERC20 {
    using SafeERC20 for IERC20;

    address public immutable factory;
    address public immutable token;
    
    modifier ensure(uint256 deadline) {
        if(block.timestamp > deadline) revert DeadlineExpired();
        _;
    }

    constructor(address _token) ERC20("Liquidity Token", "LT", 18) {
        if(_token == address(0)) revert ZeroAddress();
        factory = msg.sender;
        token = _token;
    }

    // =============================================================
    //                         LIQUIDITY
    // =============================================================

    function addLiquidity(uint256 minLiquidity, uint256 maxTokens, uint256 deadline) public payable ensure(deadline) returns (uint256) {
        if(msg.value == 0 || maxTokens == 0) revert InsufficientLiquidityProvided();

        uint256 optimalTokenAmount; 
        uint256 liquidity;

        if(getReserve() > 0) {
            optimalTokenAmount = getReserve() * msg.value / address(this).balance;
            if(maxTokens < optimalTokenAmount) {
                revert InsufficientTokensProvided();
            }

            liquidity = totalSupply * msg.value / address(this).balance; 
            if(liquidity < minLiquidity) { 
                revert InsufficientLiquidityMinted();
            }
        } else {
            if(msg.value < 1 gwei) revert InsufficientEthProvided();
 
            optimalTokenAmount = maxTokens;
            liquidity = address(this).balance;
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), optimalTokenAmount);

        emit AddLiquidity(msg.sender, msg.value, optimalTokenAmount);

        _mint(msg.sender, liquidity);

        return liquidity;
    }

    function removeLiquidity(uint256 amount, uint256 minEth, uint256 minTokens, uint256 deadline) public ensure(deadline) returns (uint256, uint256) {
        uint256 ethAmount = address(this).balance * amount / totalSupply;
        uint256 tokenAmount = getReserve() * amount / totalSupply;
        
        if(ethAmount < minEth || tokenAmount < minTokens) revert InsufficientLiquidityBurned();

        _burn(msg.sender, amount);
        
        (bool success, ) = msg.sender.call{value: ethAmount}("");
        if(!success) revert EthTransferFailed();

        IERC20(token).safeTransfer(msg.sender, tokenAmount);
        
        emit RemoveLiquidity(msg.sender, ethAmount, tokenAmount);

        return (ethAmount, tokenAmount); 
    }
    
    // =============================================================
    //                           SWAP
    // =============================================================

    function ethToTokenSwap(uint256 minTokens, uint256 deadline) public payable ensure(deadline) {
        _ethToToken(minTokens, msg.sender);
    }

    function ethToTokenTransfer(uint256 minTokens, uint256 deadline, address recipient) public payable ensure(deadline) {
        if(recipient == address(this) || recipient == address(0)) revert InvalidRecipient();
        _ethToToken(minTokens, recipient);
    }

    function tokenToEthSwap(uint256 tokenAmount, uint256 minEth, uint256 deadline) public ensure(deadline) {
        _tokenToEth(tokenAmount, minEth, msg.sender);
    }

    function tokenToEthTransfer(uint256 tokenAmount, uint256 minEth, uint256 deadline, address recipient) public ensure(deadline) {
        if(recipient == address(this) || recipient == address(0)) revert InvalidRecipient();
        _tokenToEth(tokenAmount, minEth, recipient);
    }

    function tokenToTokenSwap(
        uint256 inputTokenAmount, 
        uint256 minOutputTokenAmount, 
        uint256 minEth, 
        uint256 deadline, 
        address outputToken
    ) public {
        address exchange = IFactory(factory).getExchange(outputToken);
        _tokenToToken(inputTokenAmount, minOutputTokenAmount, minEth, deadline, msg.sender, exchange);
    }

    function tokenToTokenTransfer(
        uint256 inputTokenAmount, 
        uint256 minOutputTokenAmount, 
        uint256 minEth, 
        uint256 deadline, 
        address recipient, 
        address outputToken
    ) public {
        if(recipient == address(this) || recipient == address(0)) revert InvalidRecipient();
        address exchange = IFactory(factory).getExchange(outputToken);
        _tokenToToken(inputTokenAmount, minOutputTokenAmount, minEth, deadline, recipient, exchange);
    }

    function tokenToExchangeSwap(
        uint256 inputTokenAmount, 
        uint256 minOutputTokenAmount, 
        uint256 minEth, 
        uint256 deadline, 
        address exchange
    ) public {
        _tokenToToken(inputTokenAmount, minOutputTokenAmount, minEth, deadline, msg.sender, exchange);
    }

    function tokenToExchangeTransfer(
        uint256 inputTokenAmount, 
        uint256 minOutputTokenAmount, 
        uint256 minEth, 
        uint256 deadline, 
        address recipient, 
        address exchange
    ) public {
        if(recipient == address(this) || recipient == address(0)) revert InvalidRecipient();
        _tokenToToken(inputTokenAmount, minOutputTokenAmount, minEth, deadline, recipient, exchange);
    }

    function _ethToToken(uint256 minTokens, address recipient) private {
        uint256 tokenAmount = _getPrice(msg.value, address(this).balance - msg.value, getReserve()); 
        // Subtracting msg.value for output calculation using existing reserves, that is, Eth reserve before this tx, 
        // Since Eth reserves of the contract already increased by msg.value with the function call
        if(tokenAmount < minTokens) revert InsufficientEthProvided();

        IERC20(token).safeTransfer(recipient, tokenAmount);

        emit TokenPurchase(recipient, msg.value, tokenAmount);
    }
    
    function _tokenToEth(uint256 tokenAmount, uint256 minEth, address recipient) private {
        uint256 ethAmount = getTokenToEthPrice(tokenAmount);
        if(ethAmount < minEth) revert InsufficientTokensProvided();

        IERC20(token).safeTransferFrom(recipient, address(this), tokenAmount);

        (bool success, ) = recipient.call{value: ethAmount}("");
        if(!success) revert EthTransferFailed();
        
        emit EthPurchase(recipient, tokenAmount, ethAmount);
    }

    function _tokenToToken(
        uint256 inputTokenAmount, 
        uint256 minOutputTokenAmount, 
        uint256 minEth, 
        uint256 deadline,
        address recipient, 
        address exchange
    ) private {
        if(exchange == address(this) || exchange == address(0)) revert InvalidExchange();
        // swap input token to eth
        uint256 ethAmount = getTokenToEthPrice(inputTokenAmount);
        if(ethAmount < minEth) revert InsufficientEthReceived();
        uint256 tokenAmountOut = IExchange(exchange).getEthToTokenPrice(ethAmount);
        if(tokenAmountOut < minOutputTokenAmount) revert InsufficientOutputTokens();

        // swap received eth to output token and transfer to recipient
        IExchange(exchange).ethToTokenTransfer{value: ethAmount}(minOutputTokenAmount, deadline, recipient);
    }

    // =============================================================
    //                       GETTER FUNCTIONS
    // =============================================================

    function getEthToTokenPrice(uint256 ethAmount) public view returns (uint256) {
        if(ethAmount == 0) revert InsufficientEthProvided();

        return _getPrice(ethAmount, address(this).balance, getReserve());
    }

    function getTokenToEthPrice(uint256 tokenAmount) public view returns (uint256) {
        if(tokenAmount == 0) revert InsufficientTokensProvided();

        return _getPrice(tokenAmount, getReserve(), address(this).balance);
    }

    function getTokenToTokenPrice(uint256 inputTokenAmount, address outputToken) public view returns (uint256) {
        if(inputTokenAmount == 0) revert InsufficientTokensProvided();

        uint256 ethAmount = _getPrice(inputTokenAmount, getReserve(), address(this).balance);
        address exchange = IFactory(factory).getExchange(outputToken);

        return IExchange(exchange).getEthToTokenPrice(ethAmount);
    }

    function getReserve() public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function _getPrice(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) private pure returns (uint256) {
        if(inputReserve == 0 || outputReserve == 0) revert InsufficientReserves();
        
        // Taking 0.3% swap fee
        uint256 inputAmountWithFee = inputAmount * 997;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 1000) + inputAmountWithFee;

        return numerator / denominator;

        // return ( outputReserve * inputAmount ) / (inputReserve + inputAmount ); // no fee
    }
}
