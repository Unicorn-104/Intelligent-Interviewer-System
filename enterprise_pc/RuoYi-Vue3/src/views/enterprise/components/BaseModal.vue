<script setup>
import { X } from '@/views/enterprise/components/icons'
defineProps({ title: String, width: { type: String, default: '680px' } })
defineEmits(['close'])
</script>

<template>
  <Teleport to="body">
    <div class="modal-mask" @mousedown.self="$emit('close')">
      <section class="modal" :style="{ width }">
        <header><h2>{{ title }}</h2><button @click="$emit('close')"><X :size="20" /></button></header>
        <div class="modal-content"><slot /></div>
        <footer v-if="$slots.footer"><slot name="footer" /></footer>
      </section>
    </div>
  </Teleport>
</template>

<style scoped>
.modal-mask { position: fixed; z-index: 100; inset: 0; background: rgba(15,23,42,.48); backdrop-filter: blur(2px); display: grid; place-items: center; padding: 20px; }
.modal { max-height: calc(100vh - 40px); overflow: auto; border-radius: 15px; background: #fff; box-shadow: 0 25px 65px rgba(9,18,41,.28); animation: pop .2s ease; }
header { height: 62px; padding: 0 22px; border-bottom: 1px solid var(--line); display: flex; justify-content: space-between; align-items: center; position: sticky; top: 0; z-index: 2; background: white; }
header h2 { font-size: 19px; }header button{border:0;background:transparent;color:#6f7f99;display:grid;place-items:center}
.modal-content { padding: 22px; }
footer { min-height: 66px; padding: 13px 22px; border-top: 1px solid var(--line); display: flex; gap: 10px; justify-content: flex-end; align-items: center; position: sticky; bottom: 0; background: white; }
@keyframes pop{from{opacity:0;transform:scale(.97) translateY(5px)}to{opacity:1;transform:none}}
</style>



