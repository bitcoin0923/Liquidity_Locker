// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";


interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the token name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view returns (address);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address _owner,
        address spender
    ) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract LiquidityLocker is Ownable {
    uint256 public seconds_per_day = 24 * 60 * 60;
    
    uint256 public lockFee = 5 * 10 ** 16;

    struct LockerInfo {
        address tokenAddress;           //locked token address
        uint256 tokenAmount;                 //locked token amount
        uint256 unlockTime;
    }

    struct UserInfo {
        mapping(uint256 => LockerInfo) lockers;
        uint256 noOfLockers;
        uint256 intialized;
    }

    mapping(address => UserInfo) public usersInfo;

    address[] public allUsers;


    event DepositComplete(address indexed user, address token, uint256 amount, uint256 time);
    event WithdrawComplete(address indexed user, address token, uint256 amount, uint256 time);

    constructor () {

    }

    function lockTokens(address lpTokenAddress, uint256 lpAmount, uint256 lockPeriodInDays) external payable {

        UserInfo storage user = usersInfo[msg.sender];
        user.lockers[user.noOfLockers] = LockerInfo({
            tokenAddress: lpTokenAddress,
            tokenAmount: lpAmount,
            unlockTime: getToday(block.timestamp) + lockPeriodInDays * seconds_per_day
        });

        user.noOfLockers ++;
        if(user.intialized == 0){
            user.intialized = 1;
            allUsers.push(msg.sender);
        }

        IERC20 LockerToken = IERC20(lpTokenAddress);
        LockerToken.transferFrom(address(msg.sender), address(this), lpAmount);

        require(msg.value >= lockFee, "Insufficient Eth");

        emit DepositComplete(msg.sender, lpTokenAddress, lpAmount, block.timestamp);

    }

    function withdraw(uint256 lockerNumber) external {
        UserInfo storage user = usersInfo[msg.sender];
        LockerInfo storage locker = user.lockers[lockerNumber];
        require(block.timestamp >= locker.unlockTime, "Did not pass the lock period");

        IERC20 LockerToken = IERC20(locker.tokenAddress);

        //replace withdrawing locker with last locker of this user
        //as a result, withdrawing locker is removed
        LockerInfo memory lastLocker = user.lockers[user.noOfLockers - 1];
        user.lockers[lockerNumber] = lastLocker;
        user.noOfLockers --;

        LockerToken.transfer(address(msg.sender), locker.tokenAmount);

        emit WithdrawComplete(msg.sender, locker.tokenAddress, locker.tokenAmount, block.timestamp);

    }

    function setLockFee(uint256 newLockFee) onlyOwner external {
        lockFee = newLockFee;
    }

    function transferOwnershipOfLocker(uint256 lockerNumber, address newOwner) external {
        UserInfo storage oldUser = usersInfo[msg.sender];
        LockerInfo storage locker = oldUser.lockers[lockerNumber];

        //replace withdrawing locker with last locker of this user
        //as a result, withdrawing locker is removed
        LockerInfo memory lastLocker = oldUser.lockers[oldUser.noOfLockers - 1];
        oldUser.lockers[lockerNumber] = lastLocker;
        oldUser.noOfLockers --;

        UserInfo storage newUser = usersInfo[newOwner];
        newUser.lockers[newUser.noOfLockers] = locker;
        newUser.noOfLockers ++;
        
        if(newUser.intialized == 0){
            newUser.intialized = 1;
            allUsers.push(newOwner);
        }

    }

    function getToday(uint256 time) internal view returns (uint256) {
        return time / seconds_per_day * seconds_per_day; 
    }
}