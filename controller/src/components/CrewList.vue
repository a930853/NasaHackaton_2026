<script setup>
import { ROLES } from '../roles.js'

defineProps({
  players: { type: Array, required: true },
  playerId: { type: String, default: '' },
})
</script>

<template>
  <ul class="flex flex-col gap-2" aria-label="Crew">
    <li
      v-for="p in players"
      :key="p.id"
      class="flex items-center gap-3 rounded-[12px] bg-screen-2 px-3 py-2"
      :class="{ 'opacity-50': !p.connected }"
    >
      <span
        class="helmet size-8"
        :style="{ '--helmet-color': ROLES[p.role]?.color ?? '#5d667c' }"
        aria-hidden="true"
      />
      <span class="min-w-0 flex-1 truncate text-glass">
        {{ p.name }}<span v-if="p.id === playerId" class="text-glass-dim"> (you)</span>
      </span>
      <span class="text-[15px] text-glass-dim">
        {{ ROLES[p.role]?.name ?? 'No role yet' }}<template v-if="!p.connected">, offline</template>
      </span>
    </li>
  </ul>
</template>
