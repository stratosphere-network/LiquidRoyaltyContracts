// Deployed contract addresses on Berachain Artio Testnet
export const ADDRESSES = {
  // Tokens
  HONEY: '0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce' as `0x${string}`,
  WBTC: '0x0555E30da8f98308EdB960aa94C0Db47230d2B9c' as `0x${string}`,
  
  // Vaults
  SENIOR_VAULT: '0x65691bd1972e906459954306aDa0f622a47d4744' as `0x${string}`,
  JUNIOR_VAULT: '0x3A1b3b300dEE06Caf0b691F1771d1Aa26d70B067' as `0x${string}`,
  RESERVE_VAULT: '0x2C75291479788C568A6750185CaDedf43aBFC553' as `0x${string}`,
  
  // Hooks (UPDATED - Fixed LP liquidation algorithm - Nov 14, 2025)
  SENIOR_HOOK: '0x949Ba11180BDF15560D7Eba9864c929FA4a32bA2' as `0x${string}`,
  JUNIOR_HOOK: '0x9e7753A490628C65219c467A792b708A89209168' as `0x${string}`,
  RESERVE_HOOK: '0x88FA91FCF1771AC3C07b3f6684239A4A0B234299' as `0x${string}`,
  
  // Kodiak
  KODIAK_ISLAND: '0xf6b16E73d3b0e2784AAe8C4cd06099BE65d092Bf' as `0x${string}`,
  KODIAK_ROUTER: '0x679a7C63FC83b6A4D9C1F931891d705483d4791F' as `0x${string}`,
  
  // Enso Aggregator
  ENSO_AGGREGATOR: '0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf' as `0x${string}`,
} as const;

export const CHAIN_ID = 80094; // Berachain Artio Testnet

