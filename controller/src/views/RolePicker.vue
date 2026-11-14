<script setup>
// Selección de rol en el lobby. La disponibilidad sale de lobby_state.
import { computed } from 'vue'
import { ROLES } from '../roles.js'
import ScreenHeading from '../components/ScreenHeading.vue'

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
  if (role.mine) return 'Your role'
  return role.available ? role.subtitle : `Taken by ${role.holder.name}`
}
</script>

<template>
  <section class="screen-w flex min-h-0 flex-1 flex-col overflow-hidden" aria-labelledby="picker-title">
    <div class="flex min-h-0 flex-1 flex-col justify-center gap-[clamp(20px,6vh,56px)] py-5 md:py-12">
      <ScreenHeading id="picker-title">
        Who do you want to be <span class="text-amber">today?</span>
        <template #hint>Pick your job on the crew to start.</template>
      </ScreenHeading>

      <p v-if="message" class="notice-error" role="alert">{{ message }}</p>

      <div class="grid w-full grid-cols-2 gap-2.5 md:gap-3.5" aria-label="Pick your role">
        <button
          v-for="role in roleList"
          :key="role.id"
          type="button"
          class="neon-button group flex items-center gap-2.5 p-3.5 text-left md:gap-[18px] md:p-[clamp(18px,2.4vw,28px)]"
          :class="role.mine ? 'bg-panel-hover' : ''"
          :style="{ '--neon': role.color, '--button-color': role.color }"
          :disabled="!role.available"
          @click="emit('pick', role.id)"
        >
          <span
            class="grid size-[42px] shrink-0 place-items-center rounded-full border-[3px] border-outline bg-(--button-color) font-mono text-[10px] font-bold tracking-[.04em] text-outline md:size-[54px] md:text-[12px]"
            aria-hidden="true"
          >
            {{ role.code }}
          </span>
          <span class="flex min-w-0 flex-col gap-[7px]">
            <strong class="text-[clamp(16px,2vw,23px)] leading-tight">{{ role.name }}</strong>
            <small class="text-[11px] text-muted md:text-xs">
              {{ caption(role) }}
            </small>
          </span>
          <span class="ml-auto hidden text-[25px] text-(--button-color) md:inline" aria-hidden="true">{{ role.available ? '→' : '—' }}</span>
        </button>
      </div>

    </div>
  </section>
</template>
