<script setup>
// Selección de rol en el lobby. La disponibilidad sale de lobby_state.
import { computed } from 'vue'
import { ROLES, ROLE_IDS } from '../roles.js'

const props = defineProps({
  players: { type: Array, required: true },
  playerId: { type: String, default: '' },
  message: { type: String, default: '' },
})
const emit = defineEmits(['pick'])

const roleList = computed(() =>
  ROLE_IDS.map((id) => {
    const role = ROLES[id]
    const holder = props.players.find((p) => p.role === id)
    const mine = holder?.id === props.playerId
    return { id, ...role, holder, mine, available: !holder || mine }
  }),
)

const caption = (role) => {
  if (role.mine) return 'This is you'
  return role.available ? role.subtitle : `${role.holder.name} has it`
}
</script>

<template>
  <section class="flex flex-1 flex-col gap-5" aria-labelledby="picker-title">
    <div class="screen screen-padding">
      <h1 id="picker-title" class="text-[clamp(22px,6.5vw,28px)] leading-tight font-bold">Pick your job</h1>
      <p class="mt-1 text-glass-dim">Each astronaut does one job. You can change it until the mission starts.</p>
    </div>

    <p v-if="message" class="alert" role="alert">{{ message }}</p>

    <div class="flex flex-col gap-4 pb-1.5">
      <button
        v-for="role in roleList"
        :key="role.id"
        type="button"
        class="key flex items-center gap-3.5"
        :class="role.available ? '' : 'key-off'"
        :style="role.available ? { '--key': role.color } : null"
        :aria-pressed="role.mine"
        :disabled="!role.available"
        @click="emit('pick', role.id)"
      >
        <!-- Ojo de buey con el casco del rol, como los astronautas del juego -->
        <span class="grid size-14 shrink-0 place-items-center rounded-full border-[3px] border-ink bg-screen">
          <span class="helmet size-10" :style="{ '--helmet-color': role.available ? role.color : '#8b93a8' }" aria-hidden="true" />
        </span>
        <span class="flex min-w-0 flex-col">
          <span class="text-[19px] leading-tight">{{ role.name }}</span>
          <span class="text-[15px] font-normal text-ink/80">{{ caption(role) }}</span>
        </span>
      </button>
    </div>
  </section>
</template>
