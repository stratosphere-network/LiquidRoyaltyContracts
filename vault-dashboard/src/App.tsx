import { useState } from 'react';
import { useAccount } from 'wagmi';
import { WalletConnect } from './components/WalletConnect';
import { VaultDashboard } from './components/VaultDashboard';
import { AdminPanel } from './components/AdminPanel';
import { Shield, Wallet } from 'lucide-react';
import './App.css';

function App() {
  const { isConnected } = useAccount();
  const [activeTab, setActiveTab] = useState<'vaults' | 'admin'>('vaults');

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
      {/* Header */}
      <header className="border-b border-white/10 backdrop-blur-sm bg-black/20">
        <div className="container mx-auto px-4 py-4">
          <div className="flex justify-between items-center">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center">
                <Shield className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className="text-2xl font-bold text-white">Liquid Royalty</h1>
                <p className="text-sm text-gray-400">Protocol Dashboard</p>
              </div>
            </div>
            
            {/* Only show wallet button in header when connected */}
            {isConnected && <WalletConnect />}
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container mx-auto px-4 py-8">
        {!isConnected ? (
          <div className="flex flex-col items-center justify-center min-h-[60vh] text-center">
            <Wallet className="w-20 h-20 text-purple-400 mb-6" />
            <h2 className="text-3xl font-bold text-white mb-4">
              Connect Your Wallet
            </h2>
            <p className="text-gray-400 mb-8 max-w-md">
              Connect your wallet to interact with the Liquid Royalty Protocol vaults on Berachain
            </p>
            <WalletConnect />
          </div>
        ) : (
          <>
            {/* Tabs */}
            <div className="flex space-x-4 mb-8">
              <button
                onClick={() => setActiveTab('vaults')}
                className={`px-6 py-3 rounded-lg font-semibold transition-all ${
                  activeTab === 'vaults'
                    ? 'bg-purple-600 text-white shadow-lg shadow-purple-500/50'
                    : 'bg-white/5 text-gray-400 hover:bg-white/10'
                }`}
              >
                Vaults
              </button>
              <button
                onClick={() => setActiveTab('admin')}
                className={`px-6 py-3 rounded-lg font-semibold transition-all ${
                  activeTab === 'admin'
                    ? 'bg-purple-600 text-white shadow-lg shadow-purple-500/50'
                    : 'bg-white/5 text-gray-400 hover:bg-white/10'
                }`}
              >
                Admin
              </button>
            </div>

            {/* Content */}
            {activeTab === 'vaults' ? <VaultDashboard /> : <AdminPanel />}
          </>
        )}
      </main>

      {/* Footer */}
      <footer className="border-t border-white/10 mt-20">
        <div className="container mx-auto px-4 py-6">
          <div className="flex justify-between items-center text-sm text-gray-400">
            <p>Liquid Royalty Protocol © 2025</p>
            <div className="flex space-x-4">
              <a href="#" className="hover:text-white transition-colors">Docs</a>
              <a href="#" className="hover:text-white transition-colors">GitHub</a>
              <a href="https://artio.beratrail.io" target="_blank" rel="noopener noreferrer" className="hover:text-white transition-colors">
                Explorer
              </a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}

export default App;
