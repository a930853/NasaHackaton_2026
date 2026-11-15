<script setup>
// La puerta de la nave con las dos formas de jugar. Se cierra con «Back» (o Escape, desde App.vue).
//   PC: cerrada queda fuera de la pantalla; «Play» (en la portada) la abre y entra por la derecha.
//   Móvil: cerrada asoma abajo su canto, una barra gris con «Play»; la barra la abre, la puerta sube
//   y la barra sale por arriba, así que la hoja queda a pantalla completa.
import { ref } from 'vue'
import JoinForm from './JoinForm.vue'

defineProps({ open: { type: Boolean, required: true } })
const emit = defineEmits(['open', 'close'])

const hatchEl = ref(null)
const titleEl = ref(null)
defineExpose({
  focusTitle: () => titleEl.value?.focus(),
  focusHatch: () => hatchEl.value?.focus(),
})
</script>

<template>
  <div class="door" :class="{ open }">
    <!-- Solo móvil: el canto de la puerta, metal con tornillos y «Play». Solo abre. -->
    <button
      ref="hatchEl"
      class="hatch metal relative hidden shrink-0 cursor-pointer items-center justify-center gap-3.5 border-0 p-0 text-ink max-md:flex"
      type="button"
      aria-label="Play"
      aria-controls="door-panel"
      :aria-expanded="open"
      :inert="open || undefined"
      @click="emit('open')"
    >
      <span class="screw top-1/2 left-[18px] -translate-y-1/2" aria-hidden="true" />
      <span class="play-icon raised grid size-11 shrink-0 place-items-center rounded-full bg-energy" aria-hidden="true">
        <svg viewBox="0 0 14 16" class="ml-[3px] h-[18px] w-4"><path d="M1 1l12 7-12 7z" fill="#1a2030" /></svg>
      </span>
      <span class="font-display text-xl" aria-hidden="true">Play</span>
      <span class="screw top-1/2 right-[18px] -translate-y-1/2" aria-hidden="true" />
    </button>

    <!-- La hoja de la puerta -->
    <section
      id="door-panel"
      class="door-panel metal relative min-h-0 min-w-0 flex-1 text-ink"
      role="dialog"
      aria-labelledby="door-title"
      :inert="!open || undefined"
    >
      <span class="screw top-3.5 left-4" aria-hidden="true" />
      <span class="screw top-3.5 right-4" aria-hidden="true" />
      <span class="screw bottom-3.5 left-4 max-md:hidden" aria-hidden="true" />
      <span class="screw right-4 bottom-3.5 max-md:hidden" aria-hidden="true" />

      <div class="flex h-full flex-col gap-[clamp(20px,3vh,32px)] overflow-y-auto overscroll-contain px-[clamp(20px,5vw,72px)] py-[clamp(32px,5vh,56px)] max-md:gap-4 max-md:px-4 max-md:pt-9 max-md:pb-5 max-md:text-base">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <h2
            id="door-title"
            ref="titleEl"
            tabindex="-1"
            class="m-0 font-display text-[clamp(18px,3vw,34px)] leading-[1.2] font-normal tracking-[-.02em] focus:outline-none"
          >
            How do you want to play?
          </h2>
          <!-- «Back»: arriba a la derecha en PC; en el móvil va abajo del todo, a mano del pulgar -->
          <button class="key key-quiet shrink-0 max-md:hidden" type="button" @click="emit('close')">Back</button>
        </div>

        <!-- Las dos formas de jugar, centradas y con pantallas de la misma altura -->
        <div class="my-auto grid w-full max-w-[1100px] grid-cols-[repeat(auto-fit,minmax(min(100%,380px),1fr))] gap-[clamp(16px,3vw,40px)] self-center">
          <section class="flex flex-col gap-[18px] max-md:gap-3" aria-labelledby="host-title">
            <div class="screen flex-1">
              <h3 id="host-title" class="m-0 text-[clamp(20px,2.4vw,28px)] leading-tight font-bold">Start a game</h3>
              <p class="mt-2 mb-0 text-glass-dim">
                Open it on the computer that everyone can see, like a projector or a big TV.
                It shows a room code and a QR code for the phones. You can also play alone there.
              </p>
            </div>
            <a class="key" href="/game/">Create a game</a>
          </section>

          <JoinForm />
        </div>

        <p class="m-0 text-base max-md:text-sm">Every phone uses this same web address.</p>
        <button class="key key-quiet hidden w-full max-md:block" type="button" @click="emit('close')">Back</button>
      </div>
    </section>
  </div>
</template>

<style scoped>
/* PC: cerrada, fuera de la pantalla a la derecha; abierta, a pantalla completa. */
.door {
  position: fixed; inset: 0; z-index: 3; display: flex;
  transform: translateX(100%); visibility: hidden;
  transition: transform var(--door-time) cubic-bezier(.7, 0, .2, 1), visibility 0s linear var(--door-time);
}
.door.open { transform: none; visibility: visible; transition: transform var(--door-time) cubic-bezier(.7, 0, .2, 1), visibility 0s; }

/* Canto de la hoja: se ve mientras entra */
.door-panel { border-left: 4px solid var(--color-ink); box-shadow: -10px 0 30px rgb(0 0 0 / .35); }

/*
 * Móvil: la puerta mide la pantalla más la barra. Cerrada, solo asoma la barra abajo; abierta, sube
 * lo que mide la barra de más, que queda fuera por arriba. El contenido de la hoja solo se ve abierta.
 */
@media (width < 48rem) {
  .door {
    inset: 0 0 auto; flex-direction: column; height: calc(100% + var(--hatch-h));
    transform: translateY(calc(100% - 2 * var(--hatch-h))); visibility: visible; transition: transform var(--door-time) cubic-bezier(.7, 0, .2, 1);
  }
  .door.open { transform: translateY(calc(-1 * var(--hatch-h))); }
  .door-panel { border-left: 0; box-shadow: none; }
  .door-panel > * { visibility: hidden; transition: visibility 0s linear var(--door-time); }
  .door.open .door-panel > * { visibility: visible; transition: visibility 0s; }

  .hatch {
    height: var(--hatch-h);
    border-top: 4px solid var(--color-ink); border-bottom: 3px solid var(--color-ink);
    background-image:
      linear-gradient(180deg, rgb(255 255 255 / .28), transparent 35%, transparent 70%, rgb(26 32 48 / .25));
    box-shadow: inset 0 4px 0 rgb(255 255 255 / .35), 0 -10px 30px rgb(0 0 0 / .35);
  }
  .hatch:focus-visible { outline-offset: -8px; }
}

/* El icono responde como las teclas: se ilumina y se hunde */
.play-icon { transition: transform 80ms ease-out, box-shadow 80ms ease-out, filter 120ms; }
.hatch:hover .play-icon { filter: brightness(1.1); }
.hatch:active .play-icon { transform: translateY(4px); box-shadow: 0 0 0 var(--color-ink), inset 0 3px 0 rgb(255 255 255 / .38); }
</style>
