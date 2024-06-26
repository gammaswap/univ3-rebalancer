// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPoolInitializer.sol";
import "@uniswap/swap-router-contracts/contracts/interfaces/IQuoterV2.sol";

import "../../../contracts/interfaces/IPositionManagerMintable.sol";
import "./TokensSetup.sol";

contract UniswapSetup is TokensSetup {
    IUniswapV3Factory public uniFactory;
    IUniswapV3Pool public wethUsdcPool;
    IUniswapV3Pool public wethUsdtPool;
    IQuoterV2 public quoter;

    uint24 public immutable poolFee1 = 10000;    // fee 1%
    uint24 public immutable poolFee2 = 500;    // fee 0.05%
    uint160 public immutable sqrtPriceX96 = 4339505179874779489431521;  // 1 WETH = 3000 USDC

    function initUniswap() public {
        bytes memory factoryBytecode = abi.encodePacked(vm.getCode("./node_modules/@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json"));
        assembly {
            sstore(uniFactory.slot, create(0, add(factoryBytecode, 0x20), mload(factoryBytecode)))
        }
        // uniFactory.enableFeeAmount(100, 1);

        bytes memory tickLensBytecode = abi.encodePacked(vm.getCode("./node_modules/@uniswap/v3-periphery/artifacts/contracts/lens/TickLens.sol/TickLens.json"));
        address tickLens;
        assembly {
            tickLens := create(0, add(tickLensBytecode, 0x20), mload(tickLensBytecode))
        }

        bytes memory nftDescriptorLibBytecode = abi.encodePacked(vm.getCode("./node_modules/@uniswap/v3-periphery/artifacts/contracts/libraries/NFTDescriptor.sol/NFTDescriptor.json"));
        address nftDescriptorLib;
        assembly {
            nftDescriptorLib := create(0, add(nftDescriptorLibBytecode, 0x20), mload(nftDescriptorLibBytecode))
        }

        bytes memory nftPositionManagerBytecode = abi.encodePacked(vm.getCode("./node_modules/@uniswap/v3-periphery/artifacts/contracts/NonfungiblePositionManager.sol/NonfungiblePositionManager.json"), abi.encode(address(uniFactory), address(weth), address(0)));
        address nftPositionManager;
        assembly {
            nftPositionManager := create(0, add(nftPositionManagerBytecode, 0x20), mload(nftPositionManagerBytecode))
        }

        bytes memory quoterBytecode = abi.encodePacked(vm.getCode("./node_modules/@uniswap/swap-router-contracts/artifacts/contracts/lens/QuoterV2.sol/QuoterV2.json"), abi.encode(address(uniFactory), address(weth)));
        assembly {
            sstore(quoter.slot, create(0, add(quoterBytecode, 0x20), mload(quoterBytecode)))
        }

        // Deploy Weth/Usdc pool
        wethUsdcPool = IUniswapV3Pool(
            IPoolInitializer(nftPositionManager).createAndInitializePoolIfNecessary(address(weth), address(usdc), poolFee1, sqrtPriceX96)
        );

        // Deploy Weth/Usdt pool
        wethUsdtPool = IUniswapV3Pool(
            IPoolInitializer(nftPositionManager).createAndInitializePoolIfNecessary(address(weth), address(usdt), poolFee2, sqrtPriceX96)
        );

        weth.mint(vm.addr(1), 120);
        usdc.mint(vm.addr(1), 350_000);
        weth.mint(vm.addr(1), 890);
        usdt.mint(vm.addr(1), 2_700_000);

        vm.startPrank(vm.addr(1));

        weth.approve(nftPositionManager, type(uint256).max);
        usdc.approve(nftPositionManager, type(uint256).max);
        usdt.approve(nftPositionManager, type(uint256).max);

        // Add liquidity to WETH-USDC pool
        IPositionManagerMintable.MintParams memory mintParams = IPositionManagerMintable.MintParams({
            token0: address(weth),
            token1: address(usdc),
            fee: poolFee1,
            tickLower: -887200,
            tickUpper: 887200,
            // tickLower: -216200,
            // tickUpper: -176200,
            amount0Desired: 115594502247137145239,  // 115.5 WETH
            amount1Desired: 345648123455,   // 345648 USDC
            amount0Min: 0,
            amount1Min: 0,
            recipient: msg.sender,
            deadline: type(uint256).max
        });
        IPositionManagerMintable(nftPositionManager).mint(mintParams);

        // Add liquidity to WETH-USDT pool
        mintParams = IPositionManagerMintable.MintParams({
            token0: address(weth),
            token1: address(usdt),
            fee: poolFee2,
            tickLower: -887200,
            tickUpper: 887200,
            amount0Desired: 887209737429288199534,  // 887.2 WETH
            amount1Desired: 2680657431182,   // 2680657 USDT
            amount0Min: 0,
            amount1Min: 0,
            recipient: msg.sender,
            deadline: type(uint256).max
        });
        IPositionManagerMintable(nftPositionManager).mint(mintParams);

        vm.stopPrank();
    }
}