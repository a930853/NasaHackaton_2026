<script setup>
// La puerta de la nave con las dos formas de jugar.
//
// Ocupa la pantalla más su canto (la barra), pero cerrada solo asoma el canto: por la derecha en PC
// y por abajo en el móvil. El canto la abre; al abrir, la puerta se desliza entera y el canto sale
// de la pantalla (por la izquierda en PC, por arriba en el móvil), así que la hoja queda a pantalla
// completa. Se cierra con «Back» (o Escape, desde App.vue).
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
    <!-- El canto: metal, tornillos y el icono de «play». Solo abre. -->
    <button
      ref="hatchEl"
      class="hatch metal relative flex shrink-0 cursor-pointer items-center justify-center gap-3.5 border-0 p-0 text-ink"
      type="button"
      aria-label="Play"
      aria-controls="door-panel"
      :aria-expanded="open"
      :inert="open || undefined"
      @click="emit('open')"
    >
      <span class="screw hatch-screw-a" aria-hidden="true" />
      <span class="play-icon raised grid size-11 shrink-0 place-items-center rounded-full bg-energy" aria-hidden="true">
        <svg viewBox="0 0 14 16" class="ml-[3px] h-[18px] w-4"><path d="M1 1l12 7-12 7z" fill="#1a2030" /></svg>
      </span>
      <span class="hidden font-display text-xl max-md:inline" aria-hidden="true">Play</span>
      <span class="screw hatch-screw-b" aria-hidden="true" />
    </button>

    <!-- La hoja de la puerta -->
    <section
      id="door-panel"
      class="door-panel metal relative min-w-0 flex-1 text-ink"
      role="dialog"
      aria-labelledby="door-title"
      :inert="!open || undefined"
    >
      <span class="screw top-3.5 left-4" aria-hidden="true" />
      <span class="screw top-3.5 right-4" aria-hidden="true" />
      <span class="screw bottom-3.5 left-4 max-md:hidden" aria-hidden="true" />
      <span class="screw right-4 bottom-3.5 max-md:hidden" aria-hidden="true" />

      <div class="flex h-full flex-col gap-[clamp(20px,3vh,32px)] overflow-y-auto px-[clamp(20px,5vw,72px)] py-[clamp(32px,5vh,56px)]">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <h2
            id="door-title"
            ref="titleEl"
            tabindex="-1"
            class="m-0 font-display text-[clamp(22px,3vw,34px)] leading-[1.2] font-normal tracking-[-.02em] focus:outline-none"
          >
            How do you want to play?
          </h2>
          <button class="key key-quiet" type="button" @click="emit('close')">Back</button>
        </div>

        <!-- Las dos formas de jugar, centradas y con pantallas de la misma altura -->
        <div class="my-auto grid w-full max-w-[1100px] grid-cols-[repeat(auto-fit,minmax(min(100%,380px),1fr))] gap-[clamp(20px,3vw,40px)] self-center">
          <section class="flex flex-col gap-[18px]" aria-labelledby="host-title">
            <div class="screen flex-1">
              <h3 id="host-title" class="m-0 text-[clamp(22px,2.4vw,28px)] leading-tight font-bold">Start a game</h3>
              <p class="mt-2 mb-0 text-glass-dim">
                Open it on the computer that everyone can see, like a projector or a big TV.
                It shows a room code and a QR code for the phones. You can also play alone there.
              </p>
            </div>
            <a class="key" href="/game/">Create a game</a>
          </section>

          <JoinForm />
        </div>

        <p class="m-0 text-base">Every phone uses this same web address.</p>
      </div>
    </section>
  </div>
</template>

<style scoped>
/*
 * Geometría de la puerta. Es más grande que la pantalla justo el ancho (o alto) del canto:
 *   cerrada: desplazada para que solo asome el canto;
 *   abierta: desplazada lo que mide el canto en sentido contrario, que queda fuera de la pantalla.
 */
.door {
  position: fixed; top: 0; left: 0; z-index: 3; display: flex; pointer-events: none;
  width: calc(100% + var(--hatch-w)); height: 100%;
  transform: translateX(calc(100% - 2 * var(--hatch-w)));
  transition: transform var(--door-time) cubic-bezier(.7, 0, .2, 1);
}
.door.open { transform: translateX(calc(-1 * var(--hatch-w))); }

.hatch {
  width: var(--hatch-w); pointer-events: auto;
  border-left: 4px solid var(--color-ink); border-right: 3px solid var(--color-ink);
  background-image:
    linear-gradient(90deg, rgb(255 255 255 / .28), transparent 35%, transparent 70%, rgb(26 32 48 / .25)),
    linear-gradient(180deg, rgb(255 255 255 / .15), transparent 40%, rgb(26 32 48 / .2));
  box-shadow: inset 4px 0 0 rgb(255 255 255 / .35), -10px 0 30px rgb(0 0 0 / .35);
}
.hatch:focus-visible { outline-offset: -8px; }
.hatch-screw-a, .hatch-screw-b { left: 50%; transform: translateX(-50%); }
.hatch-screw-a { top: 18px; }
.hatch-screw-b { bottom: 18px; }

/* El icono responde como las teclas del mando: se ilumina y se hunde */
.play-icon { transition: transform 80ms ease-out, box-shadow 80ms ease-out, filter 120ms; }
.hatch:hover .play-icon { filter: brightness(1.1); }
.hatch:active .play-icon { transform: translateY(4px); box-shadow: 0 0 0 var(--color-ink), inset 0 3px 0 rgb(255 255 255 / .38); }

.door-panel {
  pointer-events: auto;
  visibility: hidden; transition: visibility 0s linear var(--door-time);
}
.door.open .door-panel { visibility: visible; transition: visibility 0s; }

/* Móvil: la puerta sube desde abajo y su canto es una barra horizontal */
@media (width < 48rem) {
  .door {
    flex-direction: column; width: 100%; height: calc(100% + var(--hatch-h));
    transform: translateY(calc(100% - 2 * var(--hatch-h)));
  }
  .door.open { transform: translateY(calc(-1 * var(--hatch-h))); }
  .hatch {
    width: auto; height: var(--hatch-h);
    border-left: 0; border-right: 0;
    border-top: 4px solid var(--color-ink); border-bottom: 3px solid var(--color-ink);
    box-shadow: inset 0 4px 0 rgb(255 255 255 / .35), 0 -10px 30px rgb(0 0 0 / .35);
  }
  .hatch-screw-a, .hatch-screw-b { top: 50%; bottom: auto; transform: translateY(-50%); }
  .hatch-screw-a { left: 18px; }
  .hatch-screw-b { left: auto; right: 18px; }
}
</style>
