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
  <div class="screen-panel px-5 py-[clamp(28px,6vh,55px)] text-center" role="status" aria-live="polite">
    <div
      class="mx-auto mb-5 grid size-[62px] place-items-center rounded-full border-[3px] border-(--role-color) bg-panel text-[27px] text-(--role-color) shadow-[0_0_16px_var(--role-color)]"
      aria-hidden="true"
    >
      {{ mark }}
    </div>
    <p v-if="eyebrow" class="eyebrow text-(--role-color)">{{ eyebrow }}</p>
    <h2 class="mb-3 text-[clamp(22px,3vw,34px)] font-bold">{{ title }}</h2>
    <p v-if="text" class="text-[15px] whitespace-pre-line text-muted">{{ text }}</p>
    <slot />
  </div>
</template>
