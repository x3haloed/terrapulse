import React, { useState } from 'react';
import { supabase } from '../supabase';
import { useGameStore, Order } from '../store';

interface Props {
  gameId: string
  playerId: string
}

const OrdersPanel = ({ gameId, playerId }: Props) => {
  const orders = useGameStore((state) => state.orders);
  const addOrder = useGameStore((state) => state.addOrder);

  const [type, setType] = useState<'reinforce' | 'attack' | 'fortify'>('reinforce');
  const [source, setSource] = useState('');
  const [target, setTarget] = useState('');

  const submitOrder = async (e: React.FormEvent) => {
    e.preventDefault();
    const payload: Record<string, string> = {};
    if (type !== 'reinforce') payload.from = source;
    payload.to = target;

    const { data, error } = await supabase
      .from('orders')
      .insert({
        game_id: gameId,
        player_id: playerId,
        type,
        payload,
        cost_ap: 1,
      })
      .select()
      .single();

    if (error) {
      console.error('Failed to submit order', error);
    } else if (data) {
      addOrder(data as Order);
    }

    setSource('');
    setTarget('');
  };

  return (
    <div style={{ border: '1px solid black', padding: '1rem' }}>
      <h2>Orders</h2>
      <form onSubmit={submitOrder} style={{ marginBottom: '1rem' }}>
        <label>
          Type:
          <select value={type} onChange={(e) => setType(e.target.value as any)}>
            <option value="reinforce">Reinforce</option>
            <option value="attack">Attack</option>
            <option value="fortify">Fortify</option>
          </select>
        </label>
        {type !== 'reinforce' && (
          <input
            type="text"
            placeholder="Source Territory ID"
            value={source}
            onChange={(e) => setSource(e.target.value)}
            required
          />
        )}
        <input
          type="text"
          placeholder="Target Territory ID"
          value={target}
          onChange={(e) => setTarget(e.target.value)}
          required
        />
        <button type="submit">Submit</button>
      </form>
      <ul>
        {orders.map((o) => (
          <li key={o.id}>{o.type} - {JSON.stringify(o.payload)}</li>
        ))}
      </ul>
    </div>
  );
};

export default OrdersPanel; 