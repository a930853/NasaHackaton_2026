<script setup>
// Cabecera de las pantallas de inicio. El título va en el slot por defecto; el texto de ayuda, en "hint".
</script>

<template>
  <div>
    <p class="eyebrow">NASA · CENTRO DE CONTROL</p>
    <h1 class="text-[clamp(36px,5vw,58px)] leading-[.98] font-bold tracking-[-.055em]"><slot /></h1>
    <p v-if="$slots.hint" class="mt-4 text-[clamp(15px,1.8vw,18px)] text-[#9aacc0]"><slot name="hint" /></p>
  </div>
</template>
