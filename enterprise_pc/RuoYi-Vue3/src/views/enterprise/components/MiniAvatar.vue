<script setup>
const props = defineProps({
  name: { type: String, default: '' },
  size: { type: Number, default: 36 },
  color: { type: String, default: '#2563eb' },
  src: { type: String, default: '' }
})
const surname = props.name.slice(0, 1)
</script>

<template>
  <div class="avatar" :style="{ width: `${size}px`, height: `${size}px`, background: src ? 'none' : `linear-gradient(145deg, ${color}, color-mix(in srgb, ${color} 62%, #111827))` }">
    <img v-if="src" :src="src" :alt="name" class="avatar-img" />
    <span v-else>{{ surname }}</span>
  </div>
</template>

<style scoped>
.avatar { flex: 0 0 auto; border-radius: 50%; color: #fff; display: grid; place-items: center; font-weight: 700; font-size: calc(v-bind(size) * .38px); border: 2px solid rgba(255,255,255,.85); box-shadow: 0 2px 7px rgba(30,41,59,.15); overflow: hidden; }
.avatar-img { width: 100%; height: 100%; object-fit: cover; border-radius: 50%; }
</style>
