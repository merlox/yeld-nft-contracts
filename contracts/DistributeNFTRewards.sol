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
    // The TOKEN token
    address public token;
    // How many LP tokens are locked
    uint256 public totalLiquidityLocked;
    // The total TOKENFee generated
    uint256 public totalTOKENFeeMined;
    uint256 public tokenFeePrice;
    uint256 public accomulatedRewards;
    uint256 public pricePadding;
    
    function initialize(address _liquidityProviderToken, address _token) public initializer {
        __Ownable_init();
        liquidityProviderToken = _liquidityProviderToken;
        token = _token;
        pricePadding = 1e18;
    }

    function setTOKEN(address _token) public onlyOwner {
        token = _token;
    }

    function setLiquidityProviderToken(address _liquidityProviderToken) public onlyOwner {
        liquidityProviderToken = _liquidityProviderToken;
    }

    /// @notice When fee is added, the price is increased
    /// Price is = (feeIn / totalTOKENFeeDistributed) + currentPrice
    /// padded with 18 zeroes that get removed after the calculations
    /// if there are no locked LPs, the price is 0
    function addFeeAndUpdatePrice(uint256 _feeIn) public {
        require(msg.sender == token, 'LockLiquidity: Only the TOKEN contract can execute this function');
        accomulatedRewards = accomulatedRewards.add(_feeIn);
        if (totalLiquidityLocked == 0) {
            tokenFeePrice = 0;
        } else {
            tokenFeePrice = (_feeIn.mul(pricePadding).div(totalLiquidityLocked)).add(tokenFeePrice);
        }
    }

    function lockLiquidity(uint256 _amount) public {
        require(_amount > 0, 'LockLiquidity: Amount must be larger than zero');
        // Transfer UNI-LP-V2 tokens inside here forever while earning fees from every transfer, LP tokens can't be extracted
        uint256 approval = IERC20(liquidityProviderToken).allowance(msg.sender, address(this));
        require(approval >= _amount, 'LockLiquidity: You must approve the desired amount of liquidity tokens to this contract first');
        IERC20(liquidityProviderToken).transferFrom(msg.sender, address(this), _amount);
        totalLiquidityLocked = totalLiquidityLocked.add(_amount);
        // Extract earnings in case the user is not a new Locked LP
        if (lastPriceEarningsExtracted[msg.sender] != 0 && lastPriceEarningsExtracted[msg.sender] != tokenFeePrice) {
            extractEarnings();
        }
        // Set the initial price 
        if (tokenFeePrice == 0) {
            tokenFeePrice = (accomulatedRewards.mul(pricePadding).div(_amount)).add(1e18);
            lastPriceEarningsExtracted[msg.sender] = 1e18;
        } else {
            lastPriceEarningsExtracted[msg.sender] = tokenFeePrice;
        }
        // The price doesn't change when locking liquidity. It changes when fees are generated from transfers
        amountLocked[msg.sender] = amountLocked[msg.sender].add(_amount);
        // Notice that the locking time is reset when new liquidity is added
        lockingTime[msg.sender] = now;
    }

    // We check for new earnings by seeing if the price the user last extracted his earnings
    // is the same or not to determine whether he can extract new earnings or not
    function extractEarnings() public {
        require(lastPriceEarningsExtracted[msg.sender] != tokenFeePrice, 'LockLiquidity: You have already extracted your earnings');
        // The amountLocked price minus the last price extracted
        uint256 earnings = getEarnings();
        lastPriceEarningsExtracted[msg.sender] = tokenFeePrice;
        accomulatedRewards = accomulatedRewards.sub(earnings);
        IERC20(token).transfer(msg.sender, earnings);
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