<script setup>
// Portada: Marte visto por la ventana de la nave. Nombre y logo del juego, de qué va, los recursos,
// la tripulación y un dato real de la NASA. Arriba, un banner con el logo y el nombre; «Play» abre la puerta.
import { randomFact } from '../facts.js'
import logo from '../assets/logo.png'
import health from '../assets/health.png'
import oxygen from '../assets/oxygen.png'
import energy from '../assets/energy.png'
import strength from '../assets/strength.png'

const STATS = [
  { name: 'Health', icon: health, color: 'var(--color-health)' },
  { name: 'Oxygen', icon: oxygen, color: 'var(--color-oxygen)' },
  { name: 'Energy', icon: energy, color: 'var(--color-energy)' },
  { name: 'Base strength', icon: strength, color: 'var(--color-strength)' },
]
// Colores de los cascos del juego (game/Scripts/main_ui.gd: ROLE_COLORS)
const CREW = [
  { name: 'Engineer', color: '#ffd933' },
  { name: 'Biologist', color: '#66e680' },
  { name: 'Doctor', color: '#ff6666' },
  { name: 'Generalist', color: '#ffffff' },
]
const fact = randomFact()
// «Play» abre la puerta (App.vue); al cerrarla, el foco vuelve a este botón
import { ref } from 'vue'
const emit = defineEmits(['play'])
const playEl = ref(null)
defineExpose({ focusPlay: () => playEl.value?.focus() })
</script>

<template>
  <div class="flex min-h-dvh flex-col">
    <!-- Banner: franja con degradado de izquierda (opaco) a derecha (transparente), con el logo y
         el nombre en una sola línea en PC; abajo, una línea naranja que se desvanece igual -->
    <header class="relative z-[1] flex items-center gap-[clamp(14px,2vw,32px)] bg-linear-to-r from-screen via-screen/75 to-screen/0 px-[clamp(24px,6vw,96px)] py-[clamp(14px,3.4vh,48px)] max-md:px-6 max-md:py-6">
      <span class="absolute right-0 bottom-0 left-[clamp(24px,6vw,96px)] h-[3px] max-md:left-6 bg-linear-to-r from-energy via-energy/60 to-energy/0" aria-hidden="true" />
      <img :src="logo" alt="" class="size-[clamp(48px,min(6.4vw,11vh),112px)] shrink-0 drop-shadow-[3px_3px_0_var(--color-ink)] [image-rendering:pixelated]">
      <h1 class="outline-text m-0 font-display text-[clamp(22px,min(3.5vw,6.6vh),64px)] leading-[1.1] font-normal tracking-[-.03em] text-white md:whitespace-nowrap max-md:text-[min(6.6vw,30px)]">
        Red Planet Survivors
      </h1>
    </header>

  <main
    class="intro-shade flex flex-1 flex-col justify-center gap-[clamp(10px,2.6vh,40px)] py-[clamp(12px,3vh,64px)] pr-[clamp(24px,4vw,64px)] pl-[clamp(24px,6vw,96px)] text-[clamp(16px,min(calc(.5vw+11px),2.5vh),22px)] max-md:justify-start max-md:px-6 max-md:pt-7 max-md:pb-[calc(var(--hatch-h)+32px)]"
  >
    <p class="m-0 max-w-[25em] text-[1.4em] leading-[1.4] text-pretty text-glass">
      Your crew just landed in Jezero Crater, on Mars. Work together to keep your base alive for 20 Sols.
      <small class="mt-1.5 block text-[.72em] text-glass-dim">A Sol is one day on Mars. It is a little longer than a day on Earth.</small>
    </p>

    <div class="flex max-w-[36em] items-center gap-[18px] max-md:flex-col max-md:items-start max-md:gap-3">
      <ul class="m-0 flex shrink-0 list-none gap-2.5 p-0" aria-label="The four things to look after">
        <li
          v-for="stat in STATS"
          :key="stat.name"
          class="raised grid h-[52px] w-[58px] place-items-center rounded-xl"
          :style="{ background: stat.color }"
        >
          <img :src="stat.icon" :alt="stat.name" class="size-[34px] [image-rendering:pixelated]">
        </li>
      </ul>
      <p class="m-0 max-w-[22em] text-glass-dim">
        Every Sol brings a new problem. Keep <strong class="text-glass">health, oxygen, energy and base strength</strong> above zero.
      </p>
    </div>

    <div class="flex max-w-[36em] items-center gap-[18px] max-md:flex-col max-md:items-start max-md:gap-3">
      <ul class="m-0 flex shrink-0 list-none p-0" aria-label="The crew jobs">
        <li v-for="role in CREW" :key="role.name" class="not-first:-ml-2.5">
          <span class="helmet size-14" :style="{ '--c': role.color }" role="img" :aria-label="role.name" />
        </li>
      </ul>
      <p class="m-0 max-w-[22em] text-glass-dim">
        Play alone, or with up to 4 astronauts. Each one joins with a phone, picks a job and
        <strong class="text-glass">votes</strong> what to do.
      </p>
    </div>

    <p class="m-0 max-w-[36em] border-l-4 border-energy pl-4 text-[.9em] text-glass-dim">
      <b class="text-glass">Real NASA science:</b> {{ fact }}
    </p>

    <!-- Abre la puerta con las dos formas de jugar: grande y al final, después de saber de qué va.
         Solo en PC: en el móvil abre la barra gris de abajo (SlidingDoor). -->
    <button ref="playEl" class="key flex w-fit items-center gap-5 py-4 pr-14 pl-4 font-display text-[1.7em] font-normal max-md:hidden" type="button" aria-controls="door-panel" @click="emit('play')">
      <span class="grid size-16 shrink-0 place-items-center rounded-full bg-ink max-md:size-14" aria-hidden="true">
        <svg viewBox="0 0 14 16" class="ml-1 h-6 w-[21px]"><path d="M1 1l12 7-12 7z" fill="#ffa826" /></svg>
      </span>
      Play
    </button>

    <p class="m-0 text-[13px] text-glass-dim/70">Mars photo: ESA/DLR/FU Berlin, processed by J. Cowart.</p>
  </main>
  </div>
</template>
