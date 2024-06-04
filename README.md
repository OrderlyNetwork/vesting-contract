## LockedTokenVault

**LockedTokenVault locks $ORDER. The token is linear unlocked, with a cliff time**

### For owners

```
// Deposit $ORDER to this contract
deposit(uint256 amount);
// Withdraw $ORDER from this contract
withdraw(uint256 amount);
// Grant $ORDER to holders, with parameter amount, startTimestamp, durationSeconds, and cliffTimestamp
function grant(
    address[] calldata holderList,
    uint256[] calldata amountList,
    uint256[] calldata startList,
    uint256[] calldata durationList,
    uint256[] calldata cliffList
);
// Recall unclaimed $ORDER of an address
function recall(address holder);
```

### For holders

```
// Holders claim the token that is able to claim
function claim() external;
```
