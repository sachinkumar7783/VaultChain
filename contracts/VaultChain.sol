// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title VaultChain
 * @dev A decentralized asset management platform for DeFi operations
 * @author VaultChain Team
 */
contract Project is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;
    
    // State variables
    mapping(address => mapping(address => uint256)) public userDeposits;
    mapping(address => mapping(address => uint256)) public userDepositTime;
    mapping(address => uint256) public totalTokenDeposits;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public userRewards;
    
    uint256 public constant REWARD_RATE = 5; // 5% annual reward rate
    uint256 public constant SECONDS_IN_YEAR = 31536000; // 365 days in seconds
    uint256 public totalValueLocked;
    
    // Events
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    
    // Modifiers
    modifier onlySupportedToken(address token) {
        require(supportedTokens[token], "Token not supported");
        _;
    }
    
    constructor() Ownable(msg.sender) {
        // Constructor is now properly initialized
    }
    
    /**
     * @dev Core Function 1: Deposit tokens into the vault
     * @param token The ERC20 token address to deposit
     * @param amount The amount of tokens to deposit
     */
    function depositTokens(address token, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
        onlySupportedToken(token) 
    {
        require(amount > 0, "Amount must be greater than 0");
        
        IERC20 tokenContract = IERC20(token);
        require(tokenContract.balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(tokenContract.allowance(msg.sender, address(this)) >= amount, "Insufficient allowance");
        
        // Transfer tokens from user to contract using SafeERC20
        tokenContract.safeTransferFrom(msg.sender, address(this), amount);
        
        // Update user deposits and total deposits
        userDeposits[msg.sender][token] += amount;
        userDepositTime[msg.sender][token] = block.timestamp;
        totalTokenDeposits[token] += amount;
        totalValueLocked += amount;
        
        emit Deposit(msg.sender, token, amount);
    }
    
    /**
     * @dev Core Function 2: Withdraw tokens from the vault
     * @param token The ERC20 token address to withdraw
     * @param amount The amount of tokens to withdraw
     */
    function withdrawTokens(address token, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
        onlySupportedToken(token) 
    {
        require(amount > 0, "Amount must be greater than 0");
        require(userDeposits[msg.sender][token] >= amount, "Insufficient deposit balance");
        
        IERC20 tokenContract = IERC20(token);
        require(tokenContract.balanceOf(address(this)) >= amount, "Insufficient contract balance");
        
        // Update user deposits and total deposits
        userDeposits[msg.sender][token] -= amount;
        totalTokenDeposits[token] -= amount;
        totalValueLocked -= amount;
        
        // Transfer tokens back to user using SafeERC20
        tokenContract.safeTransfer(msg.sender, amount);
        
        emit Withdraw(msg.sender, token, amount);
    }
    
    /**
     * @dev Core Function 3: Calculate and claim rewards
     * @param token The token address for which to calculate rewards
     * @return reward The calculated reward amount
     */
    function calculateAndClaimRewards(address token) 
        external 
        nonReentrant 
        whenNotPaused 
        onlySupportedToken(token) 
        returns (uint256 reward) 
    {
        uint256 userBalance = userDeposits[msg.sender][token];
        require(userBalance > 0, "No deposits found");
        
        uint256 depositTime = userDepositTime[msg.sender][token];
        require(depositTime > 0, "No deposit time found");
        
        // Calculate time-based rewards
        uint256 timeElapsed = block.timestamp - depositTime;
        reward = (userBalance * REWARD_RATE * timeElapsed) / (100 * SECONDS_IN_YEAR);
        
        if (reward > 0) {
            userRewards[msg.sender] += reward;
            userDepositTime[msg.sender][token] = block.timestamp; // Reset timer
            
            emit RewardsClaimed(msg.sender, reward);
        }
        
        return reward;
    }
    
    // Additional utility functions
    
    /**
     * @dev Add a new supported token (only owner)
     * @param token The token address to add
     */
    function addSupportedToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token address");
        supportedTokens[token] = true;
        emit TokenAdded(token);
    }
    
    /**
     * @dev Remove a supported token (only owner)
     * @param token The token address to remove
     */
    function removeSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = false;
        emit TokenRemoved(token);
    }
    
    /**
     * @dev Get user's total deposit for a specific token
     * @param user The user address
     * @param token The token address
     * @return The user's deposit amount
     */
    function getUserDeposit(address user, address token) external view returns (uint256) {
        return userDeposits[user][token];
    }
    
    /**
     * @dev Get user's total rewards
     * @param user The user address
     * @return The user's total rewards
     */
    function getUserRewards(address user) external view returns (uint256) {
        return userRewards[user];
    }
    
    /**
     * @dev Emergency pause function (only owner)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Emergency unpause function (only owner)
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Get contract's total value locked
     * @return The total value locked in the contract
     */
    function getTotalValueLocked() external view returns (uint256) {
        return totalValueLocked;
    }
}
