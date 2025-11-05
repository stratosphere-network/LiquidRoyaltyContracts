// Bot Configuration
export const config = {
  // API endpoint
  apiUrl: import.meta.env.VITE_API_URL || 'http://localhost:3000',
  
  // Network
  chainId: 137,
  networkName: 'Polygon',
  
  // Bot Private Keys
  bots: {
    whale: {
      privateKey: import.meta.env.VITE_WHALE_PRIVATE_KEY || '0x56f68e21f8d5809e1b17414a49b801b0caa1a482db3d4b2f16d2117a53140099',
      address: '0xE09883Cb3Fe2d973cEfE4BB28E3A3849E7e5f0A7'
    },
    farmer: {
      privateKey: import.meta.env.VITE_FARMER_PRIVATE_KEY || '0x56f68e21f8d5809e1b17414a49b801b0caa1a482db3d4b2f16d2117a53140099',
      address: '0xE09883Cb3Fe2d973cEfE4BB28E3A3849E7e5f0A7'
    }
  }
};

