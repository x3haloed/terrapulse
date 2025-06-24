import React from 'react';
import Map from './components/Map';
import OrdersPanel from './components/OrdersPanel';
import APBar from './components/APBar';
import { useGame } from './hooks/useGame';

function App() {
  // Hardcoded gameId for now. In a real app, this would come from the URL or a lobby system.
  const gameId = '00000000-0000-0000-0000-000000000001';
  // Placeholder player ID until auth is wired up
  const playerId = '00000000-0000-0000-0000-000000000001';
  const { lockOrders } = useGame(gameId, playerId);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100vh' }}>
      <header style={{ background: '#333', color: 'white', padding: '0.5rem' }}>
        <h1>TerraPulse</h1>
      </header>
      <main style={{ display: 'flex', flex: 1 }}>
        <div style={{ flex: 3, padding: '1rem' }}>
          <Map />
        </div>
        <div style={{ flex: 1, padding: '1rem', borderLeft: '1px solid #ccc' }}>
          <OrdersPanel gameId={gameId} playerId={playerId} />
          <APBar />
          <button onClick={lockOrders} style={{ marginTop: '1rem', width: '100%', padding: '0.5rem' }}>
            Lock Orders
          </button>
        </div>
      </main>
    </div>
  );
}

export default App; 