import React from 'react';

// This will be a simple SVG map.
// For a real game, you would use a library like d3 or a more complex SVG.

const Map = () => {
  return (
    <svg width="800" height="600" viewBox="0 0 800 600" style={{ border: '1px solid black' }}>
      <rect width="800" height="600" fill="#eee" />
      <text x="50%" y="50%" dominantBaseline="middle" textAnchor="middle">
        Map Placeholder
      </text>
      {/* TODO: Render territories from game state */}
    </svg>
  );
};

export default Map; 