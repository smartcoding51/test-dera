// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IBeefyVault.sol";
import "./interfaces/IPair.sol";
import "./interfaces/IUniswapRouter.sol";

contract Treasury is Ownable {
    using SafeERC20 for IERC20;

    struct VaultInfo {
        address vault;   // Address of the vault contract
        address want;    // Address of the token the vault accepts
        uint256 ratio;   // Allocation ratio of the vault
    }

    /// @notice Address of the stable coin
    address public stableCoin;

    /// @notice Array of vault information
    VaultInfo[] public vaultInfos;       

    /// @notice Total allocation across all vaults
    uint256 public totalAllocation;

    /// @notice Array to track invested amounts in each vault
    uint256[] investAmounts;

    event Deposit(address _from, uint256 _amount);
    event VaultAdded(uint256 _index, address _vault, uint256 _ratio);
    event RatioUpdated(uint256 _index, uint256 _newRatio);

    constructor(address _stableCoin) {
        stableCoin = _stableCoin;
    }

    /**
     * @dev Deposit stable coin to the Treasury contract.
     * @param _amount The amount of stable coin to deposit.
     */
    function deposit(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero");

        IERC20(stableCoin).safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(msg.sender, _amount);
    }

    /**
     * @dev Add a new vault to the Treasury contract.
     * @param _vault The address of the vault contract.
     * @param _ratio The allocation ratio of the vault.
     */
    function addVault(address _vault, uint256 _ratio) external onlyOwner {
        IERC20 _want = IBeefyVault(_vault).want();
        require(address(_want) != address(0), "vault token must not be zero address");

        vaultInfos.push(VaultInfo(_vault, address(_want), _ratio));
        investAmounts.push(0);
        totalAllocation += _ratio;

        emit VaultAdded(vaultInfos.length - 1, _vault, _ratio);
    }

    /**
     * @dev Update the allocation ratio of a vault.
     * @param _index The index of the vault to update.
     * @param _ratio The new allocation ratio.
     */
    function updateRatio(uint256 _index, uint256 _ratio) external onlyOwner {
        require(_index < vaultInfos.length, "Invalid vault index");

        VaultInfo storage vaultInfo = vaultInfos[_index];
        totalAllocation -= vaultInfo.ratio;

        vaultInfo.ratio = _ratio;
        totalAllocation += _ratio;

        emit RatioUpdated(_index, _ratio);
    }

    /**
     * @dev Distribute funds across all vaults according to their allocation ratios.
     * @param _amount The amount of funds to distribute.
     */
    function distribute(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than zero");
        require(totalAllocation > 0, "No vaults available");

        for (uint256 i = 0; i < vaultInfos.length; i++) {
            VaultInfo memory vaultInfo = vaultInfos[i];

            if (vaultInfo.ratio > 0) {
                uint256 investAmount = (_amount * vaultInfo.ratio) / totalAllocation;

                if (vaultInfo.want != stableCoin) {
                    IBeefyStrategy _strategy = IBeefyVault(vaultInfo.vault).strategy();
                    _addLiquidity(
                        IBeefyStrategy(_strategy).unirouter(),
                        IBeefyStrategy(_strategy).lpToken0(),
                        IBeefyStrategy(_strategy).lpToken1(),
                        IBeefyStrategy(_strategy).outputToLp0Route(),
                        IBeefyStrategy(_strategy).outputToLp1Route()
                    );
                    investAmount = IERC20(vaultInfo.want).balanceOf(address(this));
                }

                IERC20(stableCoin).approve(vaultInfo.vault, investAmount);
                IBeefyVault(vaultInfo.vault).deposit(investAmount);

                investAmounts[i] += investAmount;
            }
        }
    }

    /**
     * @dev Withdraw funds from a specific vault.
     * @param _index The index of the vault to withdraw from.
     * @param _shares The number of shares to withdraw.
     */
    function withdrawFunds(uint256 _index, uint256 _shares) external onlyOwner {
        VaultInfo memory vaultInfo = vaultInfos[_index];

        IBeefyVault beefyVault = IBeefyVault(vaultInfo.vault);
        beefyVault.withdraw(_shares);

        if (vaultInfo.want != stableCoin) {
            IBeefyStrategy _strategy = IBeefyVault(vaultInfo.vault).strategy();
            address uniRouter = IBeefyStrategy(_strategy).unirouter();
            address lpToken0 = IBeefyStrategy(_strategy).lpToken0();
            address lpToken1 = IBeefyStrategy(_strategy).lpToken1();

            (uint256 amount0, uint256 amount1) = _removeLiquidity(
                uniRouter,
                address(IBeefyStrategy(_strategy).want()),
                lpToken0,
                lpToken1
            );

            if (lpToken0 != stableCoin) {
                IERC20(lpToken0).approve(uniRouter, amount0);
                IUniswapRouter(uniRouter).swapExactTokensForTokens(
                    amount0,
                    0,
                    _reversePath(IBeefyStrategy(_strategy).outputToLp0Route()),
                    address(this),
                    block.timestamp
                );
            }

            if (lpToken1 != stableCoin) {
                IERC20(lpToken1).approve(uniRouter, amount1);
                IUniswapRouter(uniRouter).swapExactTokensForTokens(
                    amount1,
                    0,
                    _reversePath(IBeefyStrategy(_strategy).outputToLp1Route()),
                    address(this),
                    block.timestamp
                );
            }
        }
    }

    /**
     * @dev Calculate the aggregate yield for a specific vault.
     * @param _index The index of the vault to calculate the yield for.
     * @return The aggregate yield percentage.
     */
    function calculateAggregateYield(uint256 _index) external view returns (uint256) {
        IBeefyVault beefyVault = IBeefyVault(vaultInfos[_index].vault);

        // Get the price per full share from Beefy Vault
        uint256 pricePerFullShare = beefyVault.getPricePerFullShare();

        // Calculate the total value locked in Beefy Vault
        uint256 totalValueLocked = (beefyVault.balance() * pricePerFullShare) / 1e18;

        // Calculate the aggregate yield percentage
        return ((totalValueLocked - investAmounts[_index]) * 100) / investAmounts[_index];
    }

    /**
     * @dev Add liquidity to a Uniswap pair.
     * @param _uniRouter The address of the Uniswap router.
     * @param _lpToken0 The address of the first token in the pair.
     * @param _lpToken1 The address of the second token in the pair.
     * @param _outputToLp0Route The Uniswap route for swapping output token to LP token0.
     * @param _outputToLp1Route The Uniswap route for swapping output token to LP token1.
     */
    function _addLiquidity(
        address _uniRouter,
        address _lpToken0,
        address _lpToken1,
        address[] memory _outputToLp0Route,
        address[] memory _outputToLp1Route
    ) internal {
        uint256 outputHalf = IERC20(stableCoin).balanceOf(address(this)) / 2;
        IERC20(stableCoin).approve(_uniRouter, outputHalf);

        if (_lpToken0 != stableCoin) {
            IUniswapRouter(_uniRouter).swapExactTokensForTokens(
                outputHalf,
                0,
                _outputToLp0Route,
                address(this),
                block.timestamp
            );
        }

        if (_lpToken1 != stableCoin) {
            IUniswapRouter(_uniRouter).swapExactTokensForTokens(
                outputHalf,
                0,
                _outputToLp1Route,
                address(this),
                block.timestamp
            );
        }

        uint256 lp0Bal = IERC20(_lpToken0).balanceOf(address(this));
        uint256 lp1Bal = IERC20(_lpToken1).balanceOf(address(this));
        IERC20(_lpToken0).approve(_uniRouter, lp0Bal);
        IERC20(_lpToken1).approve(_uniRouter, lp1Bal);

        IUniswapRouter(_uniRouter).addLiquidity(
            _lpToken0,
            _lpToken1,
            lp0Bal,
            lp1Bal,
            1,
            1,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev Remove liquidity from a Uniswap pair.
     * @param _uniRouter The address of the Uniswap router.
     * @param _pair The address of the Uniswap pair.
     * @param _lpToken0 The address of LP token0.
     * @param _lpToken1 The address of LP token1.
     * @return amount0 token0 amount received from removing liquidity.
     * @return amount1 token1 amount received from removing liquidity.
     */
    function _removeLiquidity(
        address _uniRouter,
        address _pair,
        address _lpToken0,
        address _lpToken1
    ) internal returns (uint256 amount0, uint256 amount1) {
        uint256 liquidity = IERC20(_pair).balanceOf(address(this));
        IERC20(_pair).approve(_uniRouter, liquidity);

        (amount0, amount1) = IUniswapRouter(_uniRouter).removeLiquidity(
            _lpToken0,
            _lpToken1,
            liquidity,
            1,
            1,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev Reverse the order of addresses in a path.
     * @param _path The path of addresses.
     * @return The reversed path of addresses.
     */
    function _reversePath(address[] memory _path) internal pure returns (address[] memory) {
        address[] memory reversedPath = new address[](_path.length);

        uint256 lastIndex = _path.length - 1;
        for (uint256 i = 0; i <= lastIndex; i++) {
            reversedPath[i] = _path[lastIndex - i];
        }

        return reversedPath;
    }
}
