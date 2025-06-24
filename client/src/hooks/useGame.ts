// This hook will contain the core client-side game logic,
// such as fetching the initial game state, subscribing to real-time updates,
// and providing functions to interact with the game (e.g., submit orders).

import { useEffect } from 'react';
import { supabase } from '../supabase';
import { useGameStore } from '../store';

export const useGame = (gameId: string) => {
  const store = useGameStore();

  useEffect(() => {
    if (!gameId) return;

    // Fetch initial state
    const fetchInitialState = async () => {
      const { data, error } = await supabase
        .from('game_state')
        .select('*')
        .eq('game_id', gameId);

      if (error) {
        console.error('Error fetching initial state:', error);
      } else {
        // Here you would transform the data and update the store
        console.log('Initial state:', data);
      }
    };

    fetchInitialState();

    // Subscribe to real-time updates
    const channel = supabase.channel(`game:${gameId}`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'events',
        filter: `game_id=eq.${gameId}`
      }, (payload) => {
        console.log('New event received:', payload);
        // Here you would process the event and update the store
        // store.applyEvent(payload.new);
      })
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [gameId, store]);

  // Expose functions to interact with the game
  const lockOrders = async () => {
    const { error } = await supabase.rpc('lock_orders', { p_game_id: gameId });
    if (error) console.error('Error locking orders:', error);
  };

  return { lockOrders };
}; 