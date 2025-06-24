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
  armies: number
  orders: Order[]
  territories: Territory[]
  setOrders: (orders: Order[]) => void
  addOrder: (order: Order) => void
  setTerritories: (territories: Territory[]) => void
  increaseArmies: (by: number) => void
}

export const useGameStore = create<GameState>()((set) => ({
  armies: 0,
  orders: [],
  territories: [],
  setOrders: (orders) => set(() => ({ orders })),
  addOrder: (order) => set((state) => ({ orders: [...state.orders, order] })),
  setTerritories: (territories) => set(() => ({ territories })),
  increaseArmies: (by) => set((state) => ({ armies: state.armies + by })),
}))
