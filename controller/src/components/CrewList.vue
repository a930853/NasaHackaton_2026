<script setup>
import { ROLES } from '../roles.js'

defineProps({
  players: { type: Array, required: true },
  playerId: { type: String, default: '' },
})
</script>

<template>
  <ul class="crew-grid grid w-full max-w-[620px] grid-cols-2 gap-2" aria-label="Tripulación">
    <li
      v-for="p in players"
      :key="p.id"
      class="crew-member flex min-w-0 items-center gap-2.5 border-2 bg-[rgba(15,32,52,.6)] px-3 py-2.5 text-sm"
      :class="{ 'opacity-50': !p.connected }"
      :style="{ '--crew-color': ROLES[p.role]?.color ?? '#516276' }"
    >
      <span
        class="size-[9px] shrink-0 rounded-full"
        :style="{ background: ROLES[p.role]?.color ?? '#516276' }"
        aria-hidden="true"
      />
      <span class="flex-1 text-ink">
        {{ p.name }}<small v-if="p.id === playerId" class="text-muted"> (tú)</small>
      </span>
      <span class="font-mono text-[11px] text-muted">
        {{ ROLES[p.role]?.name ?? 'Sin rol' }}<template v-if="!p.connected"> · desconectado</template>
      </span>
    </li>
  </ul>
</template>
