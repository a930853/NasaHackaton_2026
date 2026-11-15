<script setup>
// Unirse con el móvil: el código de la pantalla grande abre el mando en /controller/?room=<código>.
import { ref } from 'vue'

const room = ref('')
// El código viaja en mayúsculas y sin espacios (el mando lo normaliza igual).
const normalize = (event) => { room.value = event.target.value.toUpperCase().replace(/\s+/g, '') }
</script>

<template>
  <form class="flex flex-col gap-[18px] max-md:gap-3" action="/controller/" method="get" aria-labelledby="join-title">
    <div class="screen flex-1">
      <h3 id="join-title" class="m-0 text-[clamp(20px,2.4vw,28px)] leading-tight font-bold">Join with your phone</h3>
      <p class="mt-2 mb-0 text-glass-dim">Scan the QR code on the big screen, or type its room code here.</p>
      <label for="room" class="mt-[18px] block font-bold max-md:mt-3">Room code</label>
      <input
        id="room"
        :value="room"
        class="field"
        name="room"
        maxlength="8"
        placeholder="K7MP"
        autocomplete="off"
        autocapitalize="characters"
        spellcheck="false"
        required
        @input="normalize"
      >
    </div>
    <button class="key key-cyan" type="submit">Join the room</button>
  </form>
</template>
