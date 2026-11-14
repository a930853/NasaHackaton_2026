<script setup>
// Selección de rol en el lobby. La disponibilidad sale de lobby_state.
import { computed } from 'vue'
import { ROLES } from '../roles.js'
import CrewList from '../components/CrewList.vue'

const props = defineProps({
  players: { type: Array, required: true },
  playerId: { type: String, default: '' },
  message: { type: String, default: '' },
})
const emit = defineEmits(['pick'])

const roleList = computed(() =>
  Object.entries(ROLES).map(([id, role]) => {
    const holder = props.players.find((p) => p.role === id)
    const mine = holder?.id === props.playerId
    return { id, ...role, holder, mine, available: !holder || mine }
  }),
)

const caption = (role) => {
  if (role.mine) return 'Tu rol'
  return role.available ? role.subtitle : `Ocupado por ${role.holder.name}`
}
</script>

<template>
  <section class="screen start-screen" aria-labelledby="picker-title">
    <div class="start-content">
      <div class="welcome">
        <p class="eyebrow">NASA · CENTRO DE CONTROL</p>
        <h1 id="picker-title">¿Qué quieres ser <span>hoy?</span></h1>
        <p class="hint">Selecciona tu especialidad para comenzar.</p>
      </div>

      <p v-if="message" class="server-message error-message" role="alert">{{ message }}</p>

      <div class="role-grid" aria-label="Elige tu rol">
        <button
          v-for="role in roleList"
          :key="role.id"
          class="role-button"
          :class="{ disabled: !role.available, mine: role.mine }"
          :style="{ '--button-color': role.color, '--button-pale': role.pale, '--button-dark': role.dark }"
          :disabled="!role.available"
          type="button"
          @click="emit('pick', role.id)"
        >
          <span class="role-code" aria-hidden="true">{{ role.code }}</span>
          <span class="role-button-copy">
            <strong>{{ role.name }}</strong>
            <small>{{ caption(role) }}</small>
          </span>
          <span class="button-go" aria-hidden="true">{{ role.available ? '→' : '—' }}</span>
        </button>
      </div>

      <CrewList v-if="players.length" :players="players" :player-id="playerId" />
    </div>
  </section>
</template>
