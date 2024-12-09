// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title PredictionMarket
 * @notice A single-instance prediction market with initialization tied directly to the provided ETH.
 */

contract PredictionMarket {
    address public owner;
    bool public marketResolved;
    bool public outcomeYes;

    uint256 public yesPool;
    uint256 public noPool;

    mapping(address => uint256) public yesBalances;
    mapping(address => uint256) public noBalances;

    uint256 public totalYesSupply;
    uint256 public totalNoSupply;

    uint256 public initialLiquidity;
    bool public initialized;

    // Optional: Add metadata about the market
    string public marketQuestion;
    string public marketDescription;

    event BoughtYes(
        address indexed buyer,
        uint256 ethSpent,
        uint256 yesReceived
    );
    event BoughtNo(address indexed buyer, uint256 ethSpent, uint256 noReceived);
    event SoldYes(address indexed seller, uint256 yesSold, uint256 ethReceived);
    event SoldNo(address indexed seller, uint256 noSold, uint256 ethReceived);
    event MarketResolved(bool outcomeYes);
    event Redeemed(address indexed redeemer, uint256 amount, bool outcomeYes);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notResolved() {
        require(!marketResolved, "Market already resolved");
        _;
    }

    constructor(
        address _owner,
        string memory _marketQuestion,
        string memory _marketDescription
    ) {
        owner = _owner;
        marketQuestion = _marketQuestion;
        marketDescription = _marketDescription;
    }

    function initializeMarket() external payable onlyOwner {
        require(!initialized, "Already initialized");
        require(msg.value > 0, "Must provide collateral");

        initialLiquidity = msg.value;

        yesPool = initialLiquidity / 2;
        noPool = initialLiquidity / 2;

        yesBalances[msg.sender] = initialLiquidity / 2;
        noBalances[msg.sender] = initialLiquidity / 2;

        totalYesSupply = initialLiquidity / 2;
        totalNoSupply = initialLiquidity / 2;

        initialized = true;
    }

    function buyYes(uint256 minYesOut) external payable notResolved {
        require(msg.value > 0, "Must send ETH");
        uint256 currentPrice = (noPool * 1e18) / yesPool;
        uint256 dy = (msg.value * 1e18) / currentPrice;
        require(dy > 0, "Not enough ETH for at least 1 token");

        yesPool += dy;
        totalYesSupply += dy;
        yesBalances[msg.sender] += dy;

        require(dy >= minYesOut, "Slippage too high");
        emit BoughtYes(msg.sender, msg.value, dy);
    }

    function buyNo(uint256 minNoOut) external payable notResolved {
        require(msg.value > 0, "Must send ETH");
        uint256 currentPrice = (yesPool * 1e18) / noPool;
        uint256 dy = (msg.value * 1e18) / currentPrice;
        require(dy > 0, "Not enough ETH for at least 1 token");

        noPool += dy;
        totalNoSupply += dy;
        noBalances[msg.sender] += dy;

        require(dy >= minNoOut, "Slippage too high");
        emit BoughtNo(msg.sender, msg.value, dy);
    }

    function sellYes(
        uint256 yesAmount,
        uint256 minEthOut
    ) external notResolved {
        require(yesBalances[msg.sender] >= yesAmount, "Not enough YES");

        uint256 currentPrice = (noPool * 1e18) / yesPool;
        uint256 ethOut = (yesAmount * currentPrice) / 1e18;
        require(
            ethOut > 0 && address(this).balance >= ethOut,
            "Insufficient liquidity"
        );

        yesBalances[msg.sender] -= yesAmount;
        yesPool -= yesAmount;
        totalYesSupply -= yesAmount;

        (bool success, ) = msg.sender.call{value: ethOut}("");
        require(success, "ETH transfer failed");

        require(ethOut >= minEthOut, "Slippage too high");
        emit SoldYes(msg.sender, yesAmount, ethOut);
    }

    function sellNo(uint256 noAmount, uint256 minEthOut) external notResolved {
        require(noBalances[msg.sender] >= noAmount, "Not enough NO");

        uint256 currentPrice = (yesPool * 1e18) / noPool;
        uint256 ethOut = (noAmount * currentPrice) / 1e18;
        require(
            ethOut > 0 && address(this).balance >= ethOut,
            "Insufficient liquidity"
        );

        noBalances[msg.sender] -= noAmount;
        noPool -= noAmount;
        totalNoSupply -= noAmount;

        (bool success, ) = msg.sender.call{value: ethOut}("");
        require(success, "ETH transfer failed");

        require(ethOut >= minEthOut, "Slippage too high");
        emit SoldNo(msg.sender, noAmount, ethOut);
    }

    function resolveMarket(bool _outcomeYes) external onlyOwner notResolved {
        marketResolved = true;
        outcomeYes = _outcomeYes;
        emit MarketResolved(_outcomeYes);
    }

    function redeem() external {
        require(marketResolved, "Not resolved yet");

        if (outcomeYes) {
            uint256 userBalance = yesBalances[msg.sender];
            require(userBalance > 0, "No YES tokens");
            uint256 amount = (address(this).balance * userBalance) /
                totalYesSupply;
            yesBalances[msg.sender] = 0;
            totalYesSupply -= userBalance;

            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "ETH transfer failed");

            emit Redeemed(msg.sender, amount, true);
        } else {
            uint256 userBalance = noBalances[msg.sender];
            require(userBalance > 0, "No NO tokens");
            uint256 amount = (address(this).balance * userBalance) /
                totalNoSupply;
            noBalances[msg.sender] = 0;
            totalNoSupply -= userBalance;

            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "ETH transfer failed");

            emit Redeemed(msg.sender, amount, false);
        }
    }

    function getYesBalance(address user) external view returns (uint256) {
        return yesBalances[user];
    }

    function getNoBalance(address user) external view returns (uint256) {
        return noBalances[user];
    }

    function getCollateralBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
