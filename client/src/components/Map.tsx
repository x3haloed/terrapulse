import React from 'react';
import { useGameStore } from '../store';

// Simple placeholder map rendering territories as circles
const Map = () => {
  const territories = useGameStore((s) => s.territories);

  return (
    <svg width="800" height="600" viewBox="0 0 800 600" style={{ border: '1px solid black' }}>
      <rect width="800" height="600" fill="#eee" />
      {territories.map((t, idx) => {
        const x = 50 + (idx % 8) * 90;
        const y = 50 + Math.floor(idx / 8) * 90;
        return (
          <g key={t.id} transform={`translate(${x}, ${y})`}>
            <circle r="20" fill="#ccc" stroke="#000" />
            <text y="35" textAnchor="middle" fontSize="10">
              {t.name}
            </text>
          </g>
        );
      })}
    </svg>
  );
};

export default Map; 