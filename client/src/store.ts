import { create } from 'zustand'

interface GameState {
  // Define state properties here
  // e.g., territories, players, orders
  armies: number
  increaseArmies: (by: number) => void
}

export const useGameStore = create<GameState>()((set) => ({
  armies: 0,
  increaseArmies: (by) => set((state) => ({ armies: state.armies + by })),
})) 