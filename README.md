## LockedTokenVault

**LockedTokenVault locks $ORDER. The token is linear unlocked, with a cliff time**

### For owners

```
deposit(uint256 amount);
withdraw(uint256 amount);
function grant(
    address[] calldata holderList,
    uint256[] calldata amountList,
    uint256[] calldata startList,
    uint256[] calldata durationList,
    uint256[] calldata cliffList
);
function recall(address holder);
```

### For holders

```
function claim() external;
```
