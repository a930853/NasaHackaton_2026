<script setup>
// Cabecera de las pantallas de inicio: placa metálica con pilotos, como el marco del juego.
// El título va en el slot por defecto; el texto de ayuda, en "hint".
</script>

<template>
  <div class="hull-plate">
    <p class="mb-1.5 flex items-center gap-2 font-mono text-[11px] font-medium tracking-[.14em] text-outline/75">
      <span class="hud-light" aria-hidden="true" />
      NASA · CENTRO DE CONTROL
    </p>
    <h1 class="text-[clamp(32px,5vw,54px)] leading-[.98] font-bold tracking-[-.04em] [&_.text-amber]:text-[#b8560b]">
      <slot />
    </h1>
    <p v-if="$slots.hint" class="mt-3 text-[clamp(14px,1.8vw,17px)] text-outline/80"><slot name="hint" /></p>
  </div>
</template>
