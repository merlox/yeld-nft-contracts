// The contract to lock the TOKEN liquidity and earn fees
pragma solidity =0.6.2;

import '@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';

/// @notice This contract allows you to lock liquidity LP tokens and receive earnings
/// It also allows you to extract those earnings
/// It's the treasury where the feeTOKEN, TOKEN and LP TOKEN tokens are stored
contract DistributeNFTRewards is Initializable, OwnableUpgradeSafe {
    using SafeMath for uint256;

    // How many LP tokens each user has
    mapping (address => uint256) public amountLocked;
    // The price when you extracted your earnings so we can whether you got new earnings or not
    mapping (address => uint256) public lastPriceEarningsExtracted;
    // When the user started locking his LP tokens
    mapping (address => uint256) public lockingTime;
    // The uniswap LP token contract
    address public liquidityProviderToken;
    // The TOKEN rewardToken
    address public rewardToken;
    // How many LP tokens are locked
    uint256 public totalLiquidityLocked;
    // The total TOKENFee generated
    uint256 public totalTOKENFeeMined;
    uint256 public tokenFeePrice;
    uint256 public accomulatedRewards;
    uint256 public pricePadding;
    address public manager;

    modifier onlyManager {
        require(msg.sender == manager);
        _;
    }
    
    /// @param _liquidityProviderToken The token that gets locked here
    /// @param _rewardToken The token that gets rewarded every time new liquidity is added
    function initialize(address _liquidityProviderToken, address _rewardToken, address _manager) public initializer {
        __Ownable_init();
        liquidityProviderToken = _liquidityProviderToken;
        rewardToken = _rewardToken;
        manager = _manager;
        pricePadding = 1e18;
    }

    function setRewardToken(address _rewardToken) public onlyOwner {
        rewardToken = _rewardToken;
    }

    function setManager(address _manager) public onlyOwner {
        manager = _manager;
    }

    function setLiquidityProviderToken(address _liquidityProviderToken) public onlyOwner {
        liquidityProviderToken = _liquidityProviderToken;
    }

    /// @notice When fee is added, the price is increased
    /// Price is = (feeIn / totalTOKENFeeDistributed) + currentPrice
    /// padded with 18 zeroes that get removed after the calculations
    /// if there are no locked LPs, the price is 0
    function addFeeAndUpdatePrice(uint256 _feeIn) public onlyManager {
        accomulatedRewards = accomulatedRewards.add(_feeIn);
        if (totalLiquidityLocked == 0) {
            tokenFeePrice = 0;
        } else {
            tokenFeePrice = (_feeIn.mul(pricePadding).div(totalLiquidityLocked)).add(tokenFeePrice);
        }
    }

    // Liquidity is locked FOREVER
    function lockLiquidity(address _to, uint256 _amount) public onlyManager {
        require(_amount > 0, 'LockLiquidity: Amount must be larger than zero');
        // Transfer UNI-LP-V2 tokens inside here forever while earning fees from every transfer, LP tokens can't be extracted
        totalLiquidityLocked = totalLiquidityLocked.add(_amount);
        // Extract earnings in case the user is not a new Locked LP
        if (lastPriceEarningsExtracted[_to] != 0 && lastPriceEarningsExtracted[_to] != tokenFeePrice) {
            extractEarnings();
        }
        // Set the initial price 
        if (tokenFeePrice == 0) {
            tokenFeePrice = (accomulatedRewards.mul(pricePadding).div(_amount)).add(1e18);
            lastPriceEarningsExtracted[_to] = 1e18;
        } else {
            lastPriceEarningsExtracted[_to] = tokenFeePrice;
        }
        // The price doesn't change when locking liquidity. It changes when fees are generated from transfers
        amountLocked[_to] = amountLocked[_to].add(_amount);
        // Notice that the locking time is reset when new liquidity is added
        lockingTime[_to] = now;
    }

    // We check for new earnings by seeing if the price the user last extracted his earnings
    // is the same or not to determine whether he can extract new earnings or not
    function extractEarnings() public {
        require(lastPriceEarningsExtracted[msg.sender] != tokenFeePrice, 'LockLiquidity: You have already extracted your earnings');
        // The amountLocked price minus the last price extracted
        uint256 earnings = getEarnings();
        lastPriceEarningsExtracted[msg.sender] = tokenFeePrice;
        accomulatedRewards = accomulatedRewards.sub(earnings);
        IERC20(rewardToken).transfer(msg.sender, earnings);
    }

    function getEarnings() public view returns(uint256) {
        uint256 myPrice = tokenFeePrice.sub(lastPriceEarningsExtracted[msg.sender]);
        uint256 earnings = amountLocked[msg.sender].mul(myPrice).div(pricePadding);
        return earnings;
    }

    function getAmountLocked(address _user) public view returns (uint256) {
        return amountLocked[_user];
    }

    function extractTokensIfStuck(address _token, uint256 _amount) public onlyOwner {
        IERC20(_token).transfer(owner(), _amount);
    }

    function extractETHIfStruck() public onlyOwner {
        payable(address(owner())).transfer(address(this).balance);
    }
}