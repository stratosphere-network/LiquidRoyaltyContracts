# Pinned deployment bytecode

## `BurnMintTokenPool.v2.0.0.bin`

- **Size:** 23986 bytes (raw binary; not hex text).
- **Source:** `@chainlink/contracts-ccip@2.0.0` → `bytecode/v2_0_0/burn_mint_token_pool.bin` (hex with `0x` prefix in the npm tarball), decoded to raw bytes.
- **Do not** replace with `forge inspect` output from the vendored `lib/chainlink-ccip` tree (that artifact is ~20604 bytes and is not the official factory 2.0.0 creation code).

Used by `script/ccip/DeploySnrUsdBurnMintTokenPool.s.sol` for CREATE2 prediction and `deployTokenPoolWithExistingToken`.