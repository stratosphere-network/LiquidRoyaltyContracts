# COMPUTE.r Senior/Junior LP seed fork report

- Fork RPC: https://rpc.berachain.com
- Fork block: 28038506
- Island: 0x40E8Fa74792274d9d9A328D41324E9d5199C0A16
- LP for ~$1M: 272952300828455311673549 (usdPerLp=3663643783052331296)

## 0-baseline
- Senior NAV: 0
- Junior NAV: 0
- Senior Island on vault: 0
- Senior Island on hook: 0
- Junior Island on vault: 0
- Junior Island on hook: 0
- Implied USD (hook LP * pool ratio): senior 0 junior 0
- Notes: Before any LP transfer

## 1-after-erc20-to-vault
- Senior NAV: 0
- Junior NAV: 0
- Senior Island on vault: 272952300828455311673549
- Senior Island on hook: 0
- Junior Island on vault: 272952300828455311673549
- Junior Island on hook: 0
- Implied USD (hook LP * pool ratio): senior 0 junior 0
- Notes: Island LP sitting on vault contract balances only

## 2-after-LMV-transfer
- Senior NAV: 0
- Junior NAV: 0
- Senior Island on vault: 272952300828455311673549
- Senior Island on hook: 0
- Junior Island on vault: 272952300828455311673549
- Junior Island on hook: 0
- Implied USD (hook LP * pool ratio): senior 0 junior 0
- Notes: Senior LMV failed; Junior LMV failed; 

