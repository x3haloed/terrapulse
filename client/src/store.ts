import { create } from 'zustand'

interface GameState {
  ap: number
  apCap: number
  setAp: (ap: number) => void
  setApCap: (cap: number) => void
}

export const useGameStore = create<GameState>()((set) => ({
  ap: 0,
  apCap: 24,
  setAp: (ap) => set({ ap }),
  setApCap: (cap) => set({ apCap: cap }),
}))
