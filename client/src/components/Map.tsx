import React from 'react';
import { useGameStore } from '../store';

// This will be a simple SVG map.
// For a real game, you would use a library like d3 or a more complex SVG.

const Map = () => {
  const territories = useGameStore((s) => s.territories);

  return (
    <svg width="800" height="600" viewBox="0 0 800 600" style={{ border: '1px solid black' }}>
      <rect width="800" height="600" fill="#eee" />
      {territories.map((t, i) => {
        const x = 50 + (i % 10) * 70;
        const y = 50 + Math.floor(i / 10) * 70;
        return (
          <g key={t.id} transform={`translate(${x}, ${y})`}>
            <circle r={20} fill="#ccc" stroke="#333" />
            <text textAnchor="middle" dy=".35em" style={{ fontSize: '8px' }}>
              {t.name}
            </text>
          </g>
        );
      })}
    </svg>
  );
};

export default Map; 