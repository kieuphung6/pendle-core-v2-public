// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./PendleRouterLytAndForge.sol";
import "./PendleRouterOT.sol";
import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";

contract PendleRouterRawTokenOT is
    PendleRouterLytAndForge,
    PendleRouterMarketBase,
    IPMarketSwapCallback
{
    using MarketMathLib for MarketParameters;
    using FixedPoint for uint256;
    using FixedPoint for int256;

    constructor(
        address _joeRouter,
        address _joeFactory,
        address _marketFactory
    )
        PendleRouterLytAndForge(_joeRouter, _joeFactory)
        PendleRouterMarketBase(_marketFactory)
    //solhint-disable-next-line no-empty-blocks
    {

    }

    /**
    * @dev netOtOutGuessMin & netOtOutGuessMax the minimum & maximum possible guess for the netOtOut
    the correct otOut must lie between this range, else the function will revert.
    * @dev the smaller the range, the fewer iterations it will take (hence less gas). The expected way
    to create the guess is to run this function with min = 0, max = type(uint256.max) to trigger the widest
    guess range. After getting the result, min = result * (100-slippage) & max = result * (100+slippage)
    * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
    * @dev inner working of this function:
     - mintLytFromRawToken is invoked, except the market will be the recipient of all outcome LYT
     - market.swap is called, which will transfer out all the OT to the recipient, and callback is invoked
     - callback will do nothing & return (since the required LYT was transferred to market in step 1)
    */
    function swapExactRawTokenForOt(
        uint256 exactRawTokenIn,
        address recipient,
        address[] calldata path,
        address market,
        uint256 minOtOut,
        uint256 netOtOutGuessMin,
        uint256 netOtOutGuessMax
    ) external returns (uint256 netOtOut) {
        IPMarket _market = IPMarket(market);
        MarketParameters memory state = _market.readState();

        if (netOtOutGuessMax == type(uint256).max) {
            netOtOutGuessMax = state.totalOt.Uint();
        }

        address LYT = _market.LYT();
        uint256 netLytUsedToBuyOT = mintLytFromRawToken(exactRawTokenIn, LYT, 1, market, path);

        netOtOut = state.getSwapExactLytForOt(
            netLytUsedToBuyOT,
            _market.timeToExpiry(),
            netOtOutGuessMin,
            netOtOutGuessMax
        );

        require(netOtOut >= minOtOut, "insufficient ot");

        _market.swapLytForExactOt(recipient, netOtOut, netLytUsedToBuyOT, abi.encode());
    }

    /**
     * @notice sell all Ot for RawToken
     * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
     * @dev inner working of this function:
     - OT is transferred to the market
     - market.swap is called, which will transfer LYT directly to the LYT contract, and callback is invoked
     - callback will do nothing & return (since OT has been transferred to the market in step 1)
     - redeemLytToRawToken is invoked
     */
    function swapExactOtForRawToken(
        uint256 exactOtIn,
        address recipient,
        address[] calldata path,
        address market,
        uint256 minRawTokenOut
    ) external returns (uint256 netRawTokenOut) {
        IPMarket _market = IPMarket(market);
        address OT = _market.OT();
        address LYT = _market.LYT();

        IERC20(OT).transferFrom(msg.sender, market, exactOtIn);

        _market.swapExactOtForLyt(LYT, exactOtIn, 1, abi.encode());

        netRawTokenOut = _redeemLytToRawToken(LYT, minRawTokenOut, recipient, path);
    }

    function swapCallback(
        int256,
        int256,
        bytes calldata //solhint-disable-next-line no-empty-blocks
    ) external {
        // empty body since all tokens has been transferred manually to correct addresses
    }
}
