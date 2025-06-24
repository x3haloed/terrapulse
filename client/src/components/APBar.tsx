import React from 'react';
import { useGameStore } from '../store';

const APBar = () => {
  const ap = useGameStore((state) => state.ap);
  const apCap = useGameStore((state) => state.apCap);

  return (
    <div style={{ border: '1px solid black', padding: '1rem', marginTop: '1rem' }}>
      <h3>Action Points: {ap} / {apCap}</h3>
    </div>
  );
};

export default APBar;
