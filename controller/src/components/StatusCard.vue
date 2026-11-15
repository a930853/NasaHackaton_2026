<script setup>
// Pantalla de estado del aparato: espera, voto enviado, resultado, sala cerrada…
// El slot por defecto va dentro de la pantalla; "actions" (teclas) va debajo, en la carcasa.
defineProps({
  title: { type: String, required: true },
  text: { type: String, default: '' },
})
</script>

<template>
  <div class="flex flex-col gap-5">
    <div class="screen screen-padding flex flex-col gap-3" role="status" aria-live="polite">
      <h2 class="display text-[clamp(17px,5vw,22px)] text-(--role-color)">{{ title }}</h2>
      <p v-if="text" class="whitespace-pre-line text-glass">{{ text }}</p>
      <div v-if="$slots.default" class="mt-2">
        <slot />
      </div>
    </div>
    <div v-if="$slots.actions" class="flex flex-col gap-4 pb-1.5">
      <slot name="actions" />
    </div>
  </div>
</template>
