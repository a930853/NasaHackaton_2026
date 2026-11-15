<script setup>
// Página de inicio: la portada (IntroView) y la puerta con las dos formas de jugar (SlidingDoor).
//
// La puerta se abre con «Play» de la portada (en el móvil, con la barra de abajo) y se cierra con «Back» (o Escape). Abierta, la portada queda
// inerte (ni el teclado ni los lectores de pantalla entran en ella) y no hace scroll.
// /#play abre la puerta directamente.
import { nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import IntroView from './components/IntroView.vue'
import SlidingDoor from './components/SlidingDoor.vue'

const open = ref(location.hash === '#play')
const door = ref(null)
const intro = ref(null)

function sync(isOpen) {
  document.documentElement.classList.toggle('overflow-hidden', isOpen)
  const url = isOpen ? '#play' : location.pathname + location.search
  if ((location.hash === '#play') !== isOpen) history.replaceState(null, '', url)
}

watch(open, async (isOpen) => {
  sync(isOpen)
  await nextTick()
  if (isOpen) door.value.focusTitle()
  // Al cerrar, el foco vuelve a lo que abre la puerta y se ve: «Play» en PC, la barra en el móvil.
  // Se decide por lo que está a la vista, sin repetir aquí el punto de corte de Tailwind.
  else intro.value.focusPlay() || door.value.focusHatch()
})

const onHashChange = () => { open.value = location.hash === '#play' }
const onKeydown = (event) => { if (event.key === 'Escape' && open.value) open.value = false }

onMounted(() => {
  sync(open.value)
  window.addEventListener('hashchange', onHashChange)
  window.addEventListener('keydown', onKeydown)
})

onBeforeUnmount(() => {
  window.removeEventListener('hashchange', onHashChange)
  window.removeEventListener('keydown', onKeydown)
})
</script>

<template>
  <IntroView ref="intro" :inert="open || undefined" @play="open = true" />
  <SlidingDoor ref="door" :open="open" @open="open = true" @close="open = false" />
</template>
