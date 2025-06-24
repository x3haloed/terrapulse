import { create } from 'zustand'

export interface Territory {
  id: string
  name: string
  owner: string | null
  armies: number
}

interface GameState {
  armies: number
  territories: Territory[]
  increaseArmies: (by: number) => void
  setTerritories: (t: Territory[]) => void
}

export const useGameStore = create<GameState>()((set) => ({
  armies: 0,
  territories: [],
  increaseArmies: (by) => set((state) => ({ armies: state.armies + by })),
  setTerritories: (territories) => set({ territories }),
}))
