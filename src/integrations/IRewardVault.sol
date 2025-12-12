pragma solidity ^0.8.20;

interface IRewardVault {
    function delegateStake(address account, uint256 amount) external;

    function delegateWithdraw(address account, uint256 amount) external;

    function getReward(
    address account,
    address recipient
) external returns (uint256);
   

    function getTotalDelegateStaked(
        address account
    ) external view returns (uint256);

}


interface IRewardVaultFactory {
    function createRewardVault(
        address stakingToken
    ) external returns (address);
}