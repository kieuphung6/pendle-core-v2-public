// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

interface IPGaugeController {
    event MarketClaimReward(address indexed market, uint256 amount);

    event ReceiveVotingResults(uint128 wTime, address[] markets, uint256[] pendleAmounts);

    function fundPendle(uint256 amount) external;

    function withdrawPendle(uint256 amount) external;

    function pendle() external returns (address);

    function redeemMarketReward() external;

    function rewardData(address pool)
        external
        view
        returns (
            uint128 pendlePerSec,
            uint128,
            uint128,
            uint128
        );
}
