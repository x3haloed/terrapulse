import React from 'react';
import { useGameStore } from '../store';

const APBar = () => {
  const armies = useGameStore((state) => state.armies); // Using 'armies' as a placeholder for AP

  return (
    <div style={{ border: '1px solid black', padding: '1rem', marginTop: '1rem' }}>
      <h3>Action Points: {armies} / 24</h3>
      {/* TODO: Replace placeholder with actual AP from store */}
    </div>
  );
};

export default APBar; 