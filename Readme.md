## Tranching System

This is an implementation of a liquid royalty-tranching system as specified in the mathematical specification.

Please refer to the mathematical specification to understand how the system works.

## Things to Keep in Mind

The vaults accept LP tokens. There is a deposit function that takes in `(uint256 amount, address recipient)`. This should be called by an admin or whitelisted contract to deposit LP tokens on behalf of the recipient, and the shares will be minted to the recipient. 

We can design a contract to handle this and whitelist it. The contract needs to interact with Kodiak and should accept USDe, then divide it into USDe/SAIL and zap liquidity. It will then receive LP tokens and deposit them into the vaults on behalf of the user. 

Alternatively, we can interact with Kodiak off-chain via their APIs, which are very straightforward to use. Users deposit USDe into a contract, and the admin calls the contract function to zap the USDe into Kodiak pools and deposit LPs into the vaults on behalf of the users.

For redeeming the shares, we should add a function for this, redeems lps back to a separate contract which handles removing liquidity from the dex pool and returning usde to user. Currently, it burns snrUSDE and returns the lp tokens to user.

If we want the management fee to be charged by minting new tokens for senior (like we do for performance fees), we can set the management fee constant to 0. Then, when minting performance fees as snrUSD, we mint additional snrUSD, i.e., 1/12 of vault value every month.

The contracts are upgradeable, and the admin can add/remove features and update constants.

## Scripts

This repo uses Foundry. The scripts folder contains bash scripts to get you started. You can deploy custom tokens, create a pool on Kodiak to get LP tokens, then deploy vaults that support the LP tokens you got from the DEX. You can then seed the vaults by sending LP tokens to them and mint more tokens as needed. The scripts in the scripts folder provide this functionality.


### API wrapper

The API wrapper is a typescript express server consuming the contracts and  is in the wrapper folder. Quick way to test how the contracts work.


### Generating ABI
 There is a script in `scripts/generate_abis.sh`, use it to create abis which will be saved in abi folder.