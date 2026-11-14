<script setup>
import { ROLES } from '../roles.js'

defineProps({
  players: { type: Array, required: true },
  playerId: { type: String, default: '' },
})
</script>

<template>
  <ul class="grid w-full max-w-[620px] gap-2" aria-label="Crew">
    <li
      v-for="p in players"
      :key="p.id"
      class="flex items-center gap-2.5 rounded-[10px] border-2 border-l-[6px] bg-panel px-3 py-2.5 text-sm"
      :class="[p.id === playerId ? 'border-line-strong' : 'border-outline', { 'opacity-50': !p.connected }]"
      :style="{ borderLeftColor: ROLES[p.role]?.color ?? 'var(--color-hull-dark)' }"
    >
      <span class="flex-1 text-ink">
        {{ p.name }}<small v-if="p.id === playerId" class="text-muted"> (you)</small>
      </span>
      <span class="font-mono text-[11px] text-muted">
        {{ ROLES[p.role]?.name ?? 'No role yet' }}<template v-if="!p.connected"> · offline</template>
      </span>
    </li>
  </ul>
</template>
