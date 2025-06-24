// This hook will contain the core client-side game logic,
// such as fetching the initial game state, subscribing to real-time updates,
// and providing functions to interact with the game (e.g., submit orders).

import { useEffect } from 'react';
import { supabase } from '../supabase';
import { useGameStore } from '../store';

export const useGame = (gameId: string, playerId: string) => {
  const store = useGameStore();

  useEffect(() => {
    if (!gameId || !playerId) return;

    // Fetch initial state
    const fetchInitialState = async () => {
      const { data, error } = await supabase
        .from('game_state')
        .select('*')
        .eq('game_id', gameId);

      if (error) {
        console.error('Error fetching initial state:', error);
      } else if (data) {
        const territories = data.map((row) => ({
          id: row.territory_id as string,
          name: row.territory_name as string,
          owner: (row.owner_name as string) || null,
          armies: row.armies as number,
        }));
        store.setTerritories(territories);
      }
    };

    fetchInitialState();

    const fetchOrders = async () => {
      const { data, error } = await supabase
        .from('orders')
        .select('*')
        .eq('game_id', gameId)
        .eq('player_id', playerId)
        .order('created_at', { ascending: true });
      if (error) {
        console.error('Error fetching orders:', error);
      } else {
        store.setOrders(data);
      }
    };

    fetchOrders();

    // Subscribe to real-time updates
    const eventsChannel = supabase
      .channel(`game:${gameId}`)
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

    const ordersChannel = supabase
      .channel(`orders:${gameId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'orders',
        filter: `game_id=eq.${gameId}`,
      }, (payload) => {
        const newOrder = payload.new;
        if (newOrder.player_id === playerId) {
          store.addOrder(newOrder);
        }
      })
      .subscribe();

    return () => {
      supabase.removeChannel(eventsChannel);
      supabase.removeChannel(ordersChannel);
    };
  }, [gameId, playerId, store]);

  // Expose functions to interact with the game
  const lockOrders = async () => {
    const { error } = await supabase.rpc('lock_orders', { p_game_id: gameId });
    if (error) console.error('Error locking orders:', error);
  };

  return { lockOrders };
}; 