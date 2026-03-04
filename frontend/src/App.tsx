import { WagmiProvider } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { config } from './config/wagmi';
import { Header } from './components/layout/Header';
import { OrderForm } from './components/trading/OrderForm';
import { OrderBook } from './components/trading/OrderBook';
import { ProtocolStats } from './components/trading/ProtocolStats';
import { ActiveOrders } from './components/portfolio/ActiveOrders';

const queryClient = new QueryClient();

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <Header />
        <main className="dashboard-grid">
          {/* Left Sidebar — 3 columns */}
          <div className="dashboard-left">
            <OrderForm />
          </div>

          {/* Main View — 6 columns */}
          <div className="dashboard-main">
            <OrderBook />
          </div>

          {/* Right Sidebar — 3 columns */}
          <div className="dashboard-right">
            <ProtocolStats />
          </div>

          {/* Bottom Panel — Full width */}
          <div className="dashboard-bottom">
            <ActiveOrders />
          </div>
        </main>
      </QueryClientProvider>
    </WagmiProvider>
  );
}

export default App;
