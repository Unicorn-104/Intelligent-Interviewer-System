<script setup>
import { CheckCircle2 } from '@/views/enterprise/components/icons'
defineProps({ message: String })
</script>

<template><Transition name="toast"><div v-if="message" class="toast"><CheckCircle2 :size="18" />{{ message }}</div></Transition></template>

<style scoped>
.toast{position:fixed;z-index:200;left:50%;top:78px;transform:translateX(-50%);height:42px;padding:0 17px;border-radius:10px;background:#122044;color:white;box-shadow:0 10px 30px rgba(0,0,0,.2);display:flex;align-items:center;gap:9px;font-size:13px}.toast svg{color:#35d399}.toast-enter-active,.toast-leave-active{transition:.2s}.toast-enter-from,.toast-leave-to{opacity:0;transform:translate(-50%,-8px)}
</style>



