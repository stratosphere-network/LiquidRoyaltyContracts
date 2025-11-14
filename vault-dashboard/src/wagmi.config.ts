import { http, createConfig } from 'wagmi';
import { injected, walletConnect } from 'wagmi/connectors';

// Define Berachain Artio Testnet
export const berachainArtio = {
  id: 80094,
  name: 'Berachain Artio Testnet',
  nativeCurrency: {
    decimals: 18,
    name: 'BERA',
    symbol: 'BERA',
  },
  rpcUrls: {
    default: {
      http: ['https://rpc.berachain.com'],
    },
    public: {
      http: ['https://rpc.berachain.com'],
    },
  },
  blockExplorers: {
    default: {
      name: 'Beratrail',
      url: 'https://artio.beratrail.io',
    },
  },
  testnet: true,
} as const;

export const config = createConfig({
  chains: [berachainArtio],
  connectors: [
    injected(),
    walletConnect({
      projectId: 'YOUR_WALLETCONNECT_PROJECT_ID', // Get from https://cloud.walletconnect.com
    }),
  ],
  transports: {
    [berachainArtio.id]: http('https://rpc.berachain.com'),
  },
});

