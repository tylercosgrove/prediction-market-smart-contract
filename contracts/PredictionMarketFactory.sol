// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./PredictionMarket.sol";

/**
 * @title PredictionMarketFactory
 * @notice Deploys multiple instances of PredictionMarket contracts.
 */
contract PredictionMarketFactory {
    address public factoryOwner;
    PredictionMarket[] public allMarkets;

    event MarketCreated(
        address indexed marketAddress,
        address indexed owner,
        string question,
        string description
    );

    modifier onlyFactoryOwner() {
        require(msg.sender == factoryOwner, "Not factory owner");
        _;
    }

    constructor() {
        factoryOwner = msg.sender;
    }

    /**
     * @notice Create a new prediction market instance.
     * @param _owner Owner/oracle of the new prediction market.
     * @param _question Market event question.
     * @param _description More detailed description.
     * @return market The address of the newly created prediction market contract.
     */
    function createMarket(
        address _owner,
        string memory _question,
        string memory _description
    ) external returns (address market) {
        PredictionMarket newMarket = new PredictionMarket(
            _owner,
            _question,
            _description
        );
        allMarkets.push(newMarket);

        emit MarketCreated(address(newMarket), _owner, _question, _description);
        return address(newMarket);
    }

    /**
     * @notice Returns the number of markets created by the factory.
     */
    function getMarketsCount() external view returns (uint256) {
        return allMarkets.length;
    }

    /**
     * @notice Returns the address of a market at a given index.
     * @param index The index in the allMarkets array.
     */
    function getMarket(uint256 index) external view returns (PredictionMarket) {
        require(index < allMarkets.length, "Index out of range");
        return allMarkets[index];
    }
}
