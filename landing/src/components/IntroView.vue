<script setup>
// Portada: Marte visto por la ventana de la nave. Nombre y logo del juego, de qué va, los recursos,
// la tripulación y un dato real de la NASA. La indicación señala el canto de la puerta (a la derecha).
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
</script>

<template>
  <main
    class="intro-shade flex min-h-dvh flex-col justify-center gap-[clamp(18px,3.4vh,40px)] py-[clamp(20px,4vh,64px)] pr-[calc(var(--hatch-w)+clamp(24px,4vw,64px))] pl-[clamp(24px,6vw,96px)] text-[clamp(17px,calc(.5vw+11px),22px)] max-md:justify-start max-md:px-6 max-md:pt-8 max-md:pb-[calc(var(--hatch-h)+32px)]"
  >
    <h1
      class="outline-text m-0 flex items-center gap-[.3em] font-display text-[clamp(34px,4.4vw,76px)] leading-[1.05] font-normal tracking-[-.03em] text-white max-md:flex-col max-md:items-start max-md:gap-3.5 max-md:text-[min(9vw,40px)]"
    >
      <img :src="logo" alt="" class="size-[1.6em] shrink-0 drop-shadow-[4px_4px_0_var(--color-ink)] [image-rendering:pixelated] max-md:size-[72px]">
      <!-- Corta en «Red Planet / Survivors»: Sixtyfour es muy ancha -->
      <span class="max-w-[10.5em]">Red Planet Survivors</span>
    </h1>

    <p class="m-0 max-w-[25em] text-[1.4em] leading-[1.4] text-pretty text-glass">
      Your crew just landed in Jezero Crater, on Mars. Work together to keep your base alive for 20 Sols.
      <small class="mt-1.5 block text-[.72em] text-glass-dim">A Sol is one day on Mars. It is a little longer than a day on Earth.</small>
    </p>

    <!-- Indicación (no es un botón): señala el canto de la puerta, que es el que la abre -->
    <p class="outline-text-sm m-0 flex items-center gap-3.5 font-display text-[1.05em] tracking-[-.01em] whitespace-nowrap text-white max-md:hidden">
      Press the bar to play
      <svg viewBox="0 0 64 36" class="h-9 w-16 shrink-0 drop-shadow-[0_4px_0_var(--color-ink)]" aria-hidden="true">
        <path d="M3 12h36V3l22 15-22 15v-9H3z" fill="#ffa826" stroke="#1a2030" stroke-width="3.5" stroke-linejoin="round" />
      </svg>
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

    <!-- El canto de la puerta tapa el crédito que trae la imagen -->
    <p class="m-0 text-[13px] text-glass-dim/70">Mars photo: ESA/DLR/FU Berlin, processed by J. Cowart.</p>
  </main>
</template>
