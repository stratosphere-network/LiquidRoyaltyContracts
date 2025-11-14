import { useAccount, useConnect, useDisconnect } from 'wagmi';
import { Wallet, LogOut } from 'lucide-react';

export function WalletConnect() {
  const { address, isConnected } = useAccount();
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();

  if (isConnected) {
    return (
      <button
        onClick={() => disconnect()}
        className="flex items-center space-x-2 px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg transition-colors"
      >
        <span>{address?.slice(0, 6)}...{address?.slice(-4)}</span>
        <LogOut className="w-4 h-4" />
      </button>
    );
  }

  // Get the first available connector
  const availableConnector = connectors.find((c) => c.ready) || connectors[0];

  return (
    <button
      onClick={() => connect({ connector: availableConnector })}
      className="flex items-center space-x-2 px-6 py-3 bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white rounded-lg transition-all shadow-lg shadow-purple-500/50 hover:shadow-purple-500/70 font-semibold"
    >
      <Wallet className="w-5 h-5" />
      <span>Connect Wallet</span>
    </button>
  );
}

