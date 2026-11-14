<script setup>
// Tarjeta de estado: espera, decisión registrada, resultado, sala cerrada…
defineProps({
  mark: { type: String, default: '◷' },
  eyebrow: { type: String, default: '' },
  title: { type: String, required: true },
  text: { type: String, default: '' },
})
</script>

<template>
  <div class="border border-line px-5 py-[clamp(28px,6vh,55px)] text-center" role="status" aria-live="polite">
    <div
      class="mx-auto mb-5 grid size-[58px] place-items-center rounded-full border border-(--role-color) text-[27px] text-(--role-color)"
      aria-hidden="true"
    >
      {{ mark }}
    </div>
    <p v-if="eyebrow" class="eyebrow text-(--role-color)">{{ eyebrow }}</p>
    <h2 class="mb-3 text-[clamp(24px,3vw,36px)] font-bold">{{ title }}</h2>
    <p v-if="text" class="text-[15px] text-muted">{{ text }}</p>
    <slot />
  </div>
</template>
