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
  if (role.mine) return 'Tu rol'
  return role.available ? role.subtitle : `Ocupado por ${role.holder.name}`
}
</script>

<template>
  <section class="screen-w flex min-h-0 flex-1 flex-col overflow-hidden" aria-labelledby="picker-title">
    <div class="flex min-h-0 flex-1 flex-col justify-center gap-[clamp(20px,6vh,56px)] py-5 md:py-12">
      <ScreenHeading id="picker-title">
        ¿Qué quieres ser <span class="text-amber">hoy?</span>
        <template #hint>Selecciona tu especialidad para comenzar.</template>
      </ScreenHeading>

      <p v-if="message" class="notice-error" role="alert">{{ message }}</p>

      <div class="grid w-full grid-cols-2 gap-2.5 md:gap-3.5" aria-label="Elige tu rol">
        <button
          v-for="role in roleList"
          :key="role.id"
          type="button"
          class="group flex cursor-pointer items-center gap-2.5 rounded-[5px] border border-l-[6px] p-3.5 text-left text-ink transition duration-200 md:gap-[18px] md:p-[clamp(18px,2.4vw,28px)] enabled:hover:-translate-y-[3px] enabled:hover:border-(--button-color) enabled:hover:bg-(--button-pale) enabled:hover:text-(--button-dark) focus-visible:outline-none disabled:cursor-not-allowed disabled:border-[#31445b] disabled:border-l-[#516276] disabled:bg-[rgba(15,32,52,.45)] disabled:text-[#6d7f94] disabled:opacity-70"
          :class="role.mine ? 'border-(--button-color) bg-[rgb(15,32,52)]' : 'border-[#2d435b] border-l-(--button-color) bg-[rgba(15,32,52,.9)]'"
          :style="{ '--button-color': role.color, '--button-pale': role.pale, '--button-dark': role.dark }"
          :disabled="!role.available"
          @click="emit('pick', role.id)"
        >
          <span
            class="grid size-[42px] shrink-0 place-items-center rounded-full border border-(--button-color) font-mono text-[9px] font-medium tracking-[.04em] text-(--button-color) md:size-[54px] md:text-[11px] group-enabled:group-hover:text-(--button-dark) group-disabled:border-[#516276] group-disabled:text-[#6d7f94]"
            aria-hidden="true"
          >
            {{ role.code }}
          </span>
          <span class="flex flex-col gap-[7px]">
            <strong class="text-[clamp(18px,2vw,23px)]">{{ role.name }}</strong>
            <small class="text-[10px] text-muted md:text-xs group-enabled:group-hover:text-(--button-dark) group-disabled:text-[#718198]">
              {{ caption(role) }}
            </small>
          </span>
          <span class="ml-auto text-[25px] text-(--button-color)" aria-hidden="true">{{ role.available ? '→' : '—' }}</span>
        </button>
      </div>

    </div>
  </section>
</template>
