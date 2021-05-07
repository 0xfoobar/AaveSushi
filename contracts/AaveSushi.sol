// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

library DataTypes {
  // refer to the whitepaper, section 1.1 basic concepts for a formal description of these properties.
  struct ReserveData {
    //stores the reserve configuration
    ReserveConfigurationMap configuration;
    //the liquidity index. Expressed in ray
    uint128 liquidityIndex;
    //variable borrow index. Expressed in ray
    uint128 variableBorrowIndex;
    //the current supply rate. Expressed in ray
    uint128 currentLiquidityRate;
    //the current variable borrow rate. Expressed in ray
    uint128 currentVariableBorrowRate;
    //the current stable borrow rate. Expressed in ray
    uint128 currentStableBorrowRate;
    uint40 lastUpdateTimestamp;
    //tokens addresses
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    //address of the interest rate strategy
    address interestRateStrategyAddress;
    //the id of the reserve. Represents the position in the list of the active reserves
    uint8 id;
  }

  struct ReserveConfigurationMap {
    //bit 0-15: LTV
    //bit 16-31: Liq. threshold
    //bit 32-47: Liq. bonus
    //bit 48-55: Decimals
    //bit 56: Reserve is active
    //bit 57: reserve is frozen
    //bit 58: borrowing is enabled
    //bit 59: stable rate borrowing enabled
    //bit 60-63: reserved
    //bit 64-79: reserve factor
    uint256 data;
  }

  struct UserConfigurationMap {
    uint256 data;
  }

  enum InterestRateMode {NONE, STABLE, VARIABLE}
}

/**
 * @title IFlashLoanReceiver interface
 * @notice Interface for the Aave fee IFlashLoanReceiver.
 * @author Aave
 * @dev implement this interface to develop a flashloan-compatible flashLoanReceiver contract
 **/
interface IFlashLoanReceiver {
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool);

    // function ADDRESSES_PROVIDER() external view returns (ILendingPoolAddressesProvider);

    // function LENDING_POOL() external view returns (ILendingPool);
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function migrator() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function setMigrator(address) external;
}

interface ILendingPoolAddressesProvider {}

interface ILendingPool {

    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint256);

    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);

    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;

    function repay(
        address asset,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external returns (uint256);

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

}

interface IUniswapV2Router02 {

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata data,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function factory() external pure returns (address);

}

interface IERC20 {

    function balanceOf(address) external view returns (uint);

    function approve(address, uint256) external returns (bool);

    function transfer(address, uint) external returns (bool);

    function transferFrom(address, address, uint) external returns (bool);
}

interface IAToken {

    function scaledBalanceOf(address) external view returns (uint);
}

contract AaveSushi is IFlashLoanReceiver {

    ILendingPool public LENDING_POOL = ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    ILendingPoolAddressesProvider public ADDRESSES_PROVIDER = ILendingPoolAddressesProvider(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);

    IUniswapV2Router02 private immutable sushiRouter = IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);

    struct Swap {
        address user;
        address desiredAsset;
        uint256 amountInExact;
        uint256 amountOutMin;
    }
    Swap private _swap;

    constructor() {}

    function aAddress(address addr) public view returns (address) {
        return LENDING_POOL.getReserveData(addr).aTokenAddress;
    }

    /**
     * @dev Atomically swap your Aave collateral with SushiSwap.
     * @param
     */
    /**
        Consider calculating the proper amount needed to swap
        Let's start out by just swapping all the collateral

     */
    function swapCollateral(
        address currentAsset,
        address desiredAsset,
        uint loanAmount,
        // uint amountInExact,
        uint amountOutMin
    ) public {
        _swap = Swap({
            user: msg.sender,
            desiredAsset: desiredAsset,
            amountInExact: loanAmount,
            amountOutMin: amountOutMin
        });
        bytes memory params = addressToBytes(_swap.desiredAsset);
        // Take out flashloan
        address[] memory assets = new address[](1);
        assets[0] = currentAsset;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = loanAmount;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        LENDING_POOL.flashLoan(
            address(this),
            assets,
            amounts,
            modes,
            address(0x0), // onBehalfOf, not used here
            params,
            0 // referralCode
        );
    }

    function bytesToAddress(bytes memory bys) private pure returns (address addr) {
        assembly {
            addr := mload(add(bys,20))
        }
    }

    function addressToBytes(address a) public pure returns (bytes memory) {
        return abi.encodePacked(a);
    }

    /**
     * Swap flashloan tokens (current collateral) for desired collateral
     * Deposit desired collateral on behalf of user
     * Transfer current collateral aTokens and extract underlying tokens
     * Approve current asset tokens for the Lending Pool to pull back
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) public override returns (bool) {

        // _swap = Swap({
        //     // user: msg.sender,
        //     user: 0x4deB3EDD991Cfd2fCdAa6Dcfe5f1743F6E7d16A6,
        //     desiredAsset: 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9,
        //     amountInExact: 100,
        //     amountOutMin: 1
        // });

        // address pairAddress = IUniswapV2Factory(sushiRouter.factory()).getPair(currentAsset, desiredAsset);

        { // scope to avoid stack too deep
        // Swap for desired collateral
        address[] memory data = new address[](2);
        data[0] = assets[0];
        data[1] = _swap.desiredAsset;
        uint deadline = type(uint).max;

        IERC20(assets[0]).approve(address(sushiRouter), amounts[0]);
        sushiRouter.swapExactTokensForTokens(
            // _swap.amountInExact,
            amounts[0],
            _swap.amountOutMin,
            data,
            address(this),
            deadline
        );
        }


        {
        // Deposit desired collateral
        uint desiredAmount = IERC20(_swap.desiredAsset).balanceOf(address(this));
        uint aToken = IERC20(aAddress(_swap.desiredAsset)).balanceOf(_swap.user);
        address addr = aAddress(_swap.desiredAsset);
        IERC20(_swap.desiredAsset).approve(address(LENDING_POOL), desiredAmount);
        LENDING_POOL.deposit(
            _swap.desiredAsset,
            desiredAmount,
            _swap.user,
            0
        );
        uint desiredAmountAfterDeposit = IERC20(_swap.desiredAsset).balanceOf(address(this));
        uint aTokenAfterDeposit = IERC20(aAddress(_swap.desiredAsset)).balanceOf(_swap.user);
        uint foo = 3;
        }

        // Withdraw current collateral, enough to cover flashloan plus premium
        uint loanPlusPremium = amounts[0] + premiums[0] + 1000;
        address aCurrent = aAddress(assets[0]);
        require(
            IERC20(aCurrent).balanceOf(_swap.user) >= loanPlusPremium,
            "Not enough aTokens to repay flashloan"
        );
        IERC20(aCurrent).transferFrom(_swap.user, address(this), loanPlusPremium);
        LENDING_POOL.withdraw(
            assets[0],
            loanPlusPremium,
            address(this)
        );

        // Approve the LendingPool contract allowance to *pull* the owed amount
        IERC20(assets[0]).approve(address(LENDING_POOL), loanPlusPremium);
        require(
            IERC20(assets[0]).balanceOf(address(this)) >= loanPlusPremium,
            "Not enough tokens to repay flashloan"
        );

        // For manual testing before adding the flashloan back
        // IERC20(assets[0]).transfer(address(LENDING_POOL), loanPlusPremium);

        // Zero out the stack
        delete _swap;

        return true;

    }

}

