// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IExchange {
    // =============================================================
    //                           ERRORS
    // =============================================================
    
    error ZeroAddress();
    error DeadlineExpired();
    error InsufficientEthProvided();
    error InsufficientEthReceived();
    error InsufficientTokensProvided();
    error InsufficientOutputTokens();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error InsufficientLiquidityProvided();
    error InsufficientReserves();
    error EthTransferFailed();
    error InvalidRecipient();
    error InvalidExchange();

    // =============================================================
    //                           EVENTS
    // =============================================================

    event AddLiquidity(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
    event RemoveLiquidity(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
    event TokenPurchase(address indexed buyer, uint256 ethSold, uint256 tokensBought);
    event EthPurchase(address indexed buyer, uint256 tokensSold, uint256 ethBought);

    // =============================================================
    //                          FUNCTIONS
    // =============================================================

    function addLiquidity(uint256 minLiquidity, uint256 maxTokens, uint256 deadline) external payable returns (uint256);
    function removeLiquidity(uint256 amount, uint256 minEth, uint256 minTokens, uint256 deadline) external returns (uint256, uint256);
    
    function ethToTokenSwap(uint minTokens, uint256 deadline) external payable;
    function ethToTokenTransfer(uint minTokens, uint256 deadline, address recipient) external payable;
    function tokenToEthSwap(uint256 tokenAmount, uint256 minEth, uint256 deadline) external;
    function tokenToEthTransfer(uint tokenAmount, uint256 minEth, uint256 deadline, address recipient) external;
    function tokenToTokenSwap(uint256 inputTokenAmount, uint256 minOutputTokenAmount, uint256 minEth, uint256 deadline, address outputToken) external;
    function tokenToTokenTransfer(uint256 inputTokenAmount, uint256 minOutputTokenAmount, uint256 minEth, uint256 deadline, address recipient, address outputToken) external;
    function tokenToExchangeSwap(uint256 inputTokenAmount, uint256 minOutputTokenAmount, uint256 minEth, uint256 deadline, address exchange) external;
    function tokenToExchangeTransfer(uint256 inputTokenAmount, uint256 minOutputTokenAmount, uint256 minEth, uint256 deadline, address recipient, address exchange) external;

    function getEthToTokenPrice(uint256 ethAmount) external view returns (uint256);
    function getTokenToEthPrice(uint256 tokenAmount) external view returns (uint256);
    function getTokenToTokenPrice(uint256 inputTokenAmount, address outputToken) external view returns (uint256);
    function getReserve() external view returns (uint256);
}
