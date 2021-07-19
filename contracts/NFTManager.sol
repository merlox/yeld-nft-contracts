pragma solidity =0.6.2;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';

abstract contract IFreeFromUpTo is IERC20 {
    function freeFromUpTo(address from, uint256 value) external virtual returns(uint256 freed);
}

interface IDistributeNFTRewards {
    function addFeeAndUpdatePrice(uint256 _feeIn) external;
    function lockLiquidity(address _to, uint256 _amount) external;
}

contract NFTManager is Initializable, OwnableUpgradeSafe, ERC721UpgradeSafe {
    using SafeMath for uint256;
    
    // Time staked in blocks
    mapping (address => uint256) public timeStaked;
    mapping (address => uint256) public amountStaked;
    // TokenURI => blueprint
    // the array is a Blueprint with 3 elements. We use this method instead of a struct since structs are not upgradeable
    // [0] uint256 mintMax;
    // [1] uint256 currentMint; // How many tokens of this type have been minted already
    // [2] uint256 yeldCost;
    mapping (string => uint256[4]) public blueprints;
    mapping (string => bool) public blueprintExists;
    // Token ID -> tokenURI without baseURI
    mapping (uint256 => string) public myTokenURI;
    mapping (address => uint256) public myTokensCombinedCost;
    mapping (address => uint256[]) public myTokens;
    uint256 public totalLockedTokens; // Total YELD tokens locked
    string[] public tokenURIs;
    uint256[] public mintedTokenIds;
    uint256 public lastId;
    address public yeld;
    uint256 public oneDayInBlocks;
    address public devTreasury;
    uint256 public treasuryPercentage;
    uint256 public distributionToOthersPercentage;
    address public chi;
    address public distributeNFTRewards;

    modifier discountCHI {
        uint256 gasStart = gasleft();
        _;
        uint256 gasSpent = 21000 + gasStart - gasleft() + 16 * msg.data.length;
        IFreeFromUpTo(chi).freeFromUpTo(msg.sender, (gasSpent + 14154) / 41947);
    }

    // Chi mainnet 0x0000000000004946c0e9F43F4Dee607b0eF1fA1c
    // Base URI has to be like this: https://mynftpage.com/nft-token/
    function initialize(address _yeld, address _devTreasury, address _chi, string memory baseUri_) public initializer {
        __Ownable_init();
        __ERC721_init('NFTManager', 'YELDNFT');
        _setBaseURI(baseUri_);
        yeld = _yeld;
        chi = _chi;
        devTreasury = _devTreasury;
        treasuryPercentage = 10e18;
        distributionToOthersPercentage = 40e18;
        oneDayInBlocks = 6500;
    }

    function setCHI(address _chi) external onlyOwner {
        chi = _chi;
    }

    function setYELD(address _yeld) external onlyOwner {
        yeld = _yeld;
    }

    function setDevTreasury(address _devTreasury) external onlyOwner {
      devTreasury = _devTreasury;
    }

    function setDistributeNFTRewards(address _distributeNFTRewards) external onlyOwner {
        distributeNFTRewards = _distributeNFTRewards;
    }

    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _setBaseURI(baseURI_);
    }

    // Allows the owner to create a blueprint which is how many card can be minted for a particular tokenURI
    // NOTE: Remember to deploy the json file to the right URI with the baseURI
    function createBlueprint(string memory _tokenURI, uint256 _maxMint, uint256 _yeldCost) public onlyOwner {
        uint256[3] memory blueprint = [_maxMint, 0, _yeldCost];
        blueprints[_tokenURI] = blueprint;
        blueprintExists[_tokenURI] = true;
        tokenURIs.push(_tokenURI);
    }

    function discountSafeMint(string memory _tokenURI) public discountCHI {
        safeMint(_tokenURI);
    }

    function safeMintMultiple(string memory _tokenURI, uint256 _amount) public {
        for (uint256 i = 0; i < _amount; i++) {
            safeMint(_tokenURI);
        }
    }

    // Mint a card for the sender
    // NOTE: remember that the tokenURI most not have the baseURI. For instance:
    // - BaseURI is https://examplenft.com/
    // - TokenURI must be "token-1" or whatever without the BaseURI
    // To create the resulting https://exampleNFT.com/token-1
    function safeMint(string memory _tokenURI) public {
        // Check that this tokenURI exists
        require(blueprintExists[_tokenURI], "NFTManager: That token URI doesn't exist");
        // Require than the amount of tokens to mint is not exceeded
        require(blueprints[_tokenURI][0] > blueprints[_tokenURI][1], 'NFTManager: The total amount of tokens for this URI have been minted already');
        uint256 allowanceYELD = IERC20(yeld).allowance(msg.sender, address(this));
        require(allowanceYELD >= blueprints[_tokenURI][2], 'NFTManager: You have to approve the required token amount of YELD to stake');

        // Remember that the actual value locked is 50%
        uint256 cost = blueprints[_tokenURI][2];
        uint256 dev = blueprints[_tokenURI][2].mul(treasuryPercentage).div(1e20);
        uint256 distributionToOthers = blueprints[_tokenURI][2].mul(distributionToOthersPercentage).div(1e20);

        // Payment
        IERC20(yeld).transferFrom(msg.sender, address(this), cost.sub(dev).sub(distributionToOthers));
        IERC20(yeld).transferFrom(msg.sender, devTreasury, dev);
        IERC20(yeld).transferFrom(msg.sender, distributeNFTRewards, distributionToOthers);
        IDistributeNFTRewards(distributeNFTRewards).addFeeAndUpdatePrice(distributionToOthers);
        // Lock liquidity amounts
        IERC20(yeld).transferFrom(msg.sender, distributeNFTRewards, cost.div(2));
        IDistributeNFTRewards(distributeNFTRewards).lockLiquidity(msg.sender, cost.div(2));

        blueprints[_tokenURI][1] = blueprints[_tokenURI][1].add(1);
        lastId = lastId.add(1);
        mintedTokenIds.push(lastId);
        myTokenURI[lastId] = _tokenURI;
        myTokensCombinedCost[msg.sender] = myTokensCombinedCost[msg.sender].add(blueprints[_tokenURI][2]);
        myTokens[msg.sender].push(lastId);
        totalLockedTokens = totalLockedTokens.add(cost.div(2)); // 5o%
        // The token URI determines which NFT this is
        _safeMint(msg.sender, lastId, "");
        _setTokenURI(lastId, _tokenURI);
    }

    function extractTokensIfStuck(address _token, uint256 _amount) public onlyOwner {
        IERC20(_token).transfer(owner(), _amount);
    }

    function extractETHIfStruck() public onlyOwner {
        payable(address(owner())).transfer(address(this).balance);
    }

    /// @notice this is the reason we need abiencoder v2 to return the string memory
    function getTokenURIs() public view returns (string[] memory) {
        return tokenURIs;
    }

    function getBlueprint(string memory _tokenURI) public view returns(uint256[4] memory) {
        return blueprints[_tokenURI];
    }

    function getAllMyTokens(address _user) public view returns(uint256[] memory) {
        return myTokens[_user];
    }
}