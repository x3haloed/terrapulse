import { create } from 'zustand'

export interface Order {
  id: string
  game_id: string
  player_id: string
  type: 'reinforce' | 'attack' | 'fortify'
  payload: Record<string, unknown>
  cost_ap: number
  created_at: string
  executed_at: string | null
}

export interface Territory {
  id: string
  name: string
  owner: string | null
  armies: number
}

interface GameState {
  ap: number
  apCap: number
  orders: Order[]
  territories: Territory[]
  setOrders: (orders: Order[]) => void
  addOrder: (order: Order) => void
  setTerritories: (territories: Territory[]) => void
  setAp: (ap: number) => void
  setApCap: (cap: number) => void
}

export const useGameStore = create<GameState>()((set) => ({
  ap: 0,
  apCap: 0,
  orders: [],
  territories: [],
  setOrders: (orders) => set(() => ({ orders })),
  addOrder: (order) => set((state) => ({ orders: [...state.orders, order] })),
  setTerritories: (territories) => set(() => ({ territories })),
  setAp: (ap) => set(() => ({ ap })),
  setApCap: (cap) => set(() => ({ apCap: cap })),
}))
