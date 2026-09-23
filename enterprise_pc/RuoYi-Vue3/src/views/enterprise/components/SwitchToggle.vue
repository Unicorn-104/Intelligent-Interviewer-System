<script setup>
const model = defineModel({ type: Boolean, default: true })
</script>

<template><button class="switch" :class="{on:model}" type="button" @click="model=!model"><i/></button></template>

<style scoped>
.switch{width:40px;height:22px;border:0;border-radius:20px;background:#cbd5e1;padding:3px;transition:.2s}.switch i{display:block;width:16px;height:16px;border-radius:50%;background:#fff;box-shadow:0 1px 3px rgba(0,0,0,.2);transition:.2s}.switch.on{background:#2563eb}.switch.on i{transform:translateX(18px)}
</style>



