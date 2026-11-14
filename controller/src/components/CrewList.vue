<script setup>
import { ROLES } from '../roles.js'

defineProps({
  players: { type: Array, required: true },
  playerId: { type: String, default: '' },
})
</script>

<template>
  <ul class="crew-list" aria-label="Tripulación">
    <li v-for="p in players" :key="p.id" :class="{ offline: !p.connected, me: p.id === playerId }">
      <span class="crew-dot" :style="{ background: ROLES[p.role]?.color ?? '#516276' }" aria-hidden="true" />
      <span class="crew-name">{{ p.name }}<small v-if="p.id === playerId"> (tú)</small></span>
      <span class="crew-role">
        {{ ROLES[p.role]?.name ?? 'Sin rol' }}<template v-if="!p.connected"> · desconectado</template>
      </span>
    </li>
  </ul>
</template>
