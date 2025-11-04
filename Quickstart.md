### Quickstart for testing
Update your .env with 
PRIVATE_KEY=
RPC_URL=

Use `deploy_custom_tokens.sh` to create 2 tokens
Go to Uniswap, create a pool and add the tokens to get lp tokens
Use `deploy_vaults_only.sh` to deploy vaults with initial valuations.
After that is succesful, use `seed_vaults.sh` to seed the lps to the vaults.

I have saved the deployed addresses in `deployed_contracts.md` 


