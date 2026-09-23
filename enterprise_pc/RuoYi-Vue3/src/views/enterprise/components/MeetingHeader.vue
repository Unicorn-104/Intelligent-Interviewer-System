<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { BriefcaseBusiness, ArrowLeft, Clock3 } from '@/views/enterprise/components/icons'
import MiniAvatar from './MiniAvatar.vue'
const props = defineProps({ candidate: String, round: String, position: {type:String,default:'高级前端工程师'}, candidateProfile: {type:String,default:'候选人'}, stageStatus: {type:String,default:'面试进行中'}, stack: {type:String,default:''}, recording: Boolean })
const router = useRouter()
const seconds = ref(754)
let timer
onMounted(()=>timer=setInterval(()=>seconds.value++,1000))
onBeforeUnmount(()=>clearInterval(timer))
const time = computed(()=>`${String(Math.floor(seconds.value/60)).padStart(2,'0')}:${String(seconds.value%60).padStart(2,'0')}`)
</script>

<template>
  <header class="meeting-head">
    <button class="back" @click="router.push('/enterprise/interviews')"><ArrowLeft :size="17"/>返回列表</button>
    <div class="candidate"><MiniAvatar :name="candidate" :size="42" color="#536a78"/><div><h2>{{candidate}}</h2><p>{{ candidateProfile }}</p></div></div>
    <div class="info"><small>应聘岗位</small><b>{{ position }}</b></div>
    <div class="info"><small>当前阶段</small><span class="round"><BriefcaseBusiness :size="14"/>{{round}}</span></div>
    <div v-if="stack" class="info"><small>当前技术栈</small><b>{{stack}}</b></div>
    <div v-if="recording" class="info"><small>录制状态</small><b class="rec"><i/>REC 录制中</b></div>
    <div class="live"><span class="pill green"><i class="dot"/>{{ stageStatus }}</span><small>已进行</small><b><Clock3 :size="16"/>{{time}}</b></div>
  </header>
</template>

<style scoped>
.meeting-head{height:85px;border:1px solid #e5ebf3;border-radius:15px;background:white;display:flex;align-items:center;padding:0 20px;gap:20px}.back{height:36px;border:0;border-right:1px solid #e4eaf2;background:white;padding-right:18px;color:#657690;font-size:10px;display:flex;align-items:center;gap:5px}.candidate{display:flex;align-items:center;gap:9px;min-width:205px}.candidate h2{font-size:16px}.candidate p{font-size:9px;color:#718198;margin-top:3px}.info{min-width:170px;border-left:1px solid #e2e8f0;padding-left:18px}.info small,.info b{display:block}.info small{color:#8a99ad;font-size:9px;margin-bottom:5px}.info b{font-size:12px}.round{height:29px;padding:0 11px;border-radius:7px;background:#2563eb;color:white;display:inline-flex;align-items:center;gap:5px;font-size:11px;font-weight:600}.rec{color:#ef4444!important}.rec i{display:inline-block;width:7px;height:7px;border-radius:50%;background:#ef4444;margin-right:5px}.live{margin-left:auto;text-align:right}.live>small{display:block;color:#8a99ad;font-size:9px;margin-top:6px}.live>b{display:flex;align-items:center;gap:5px;justify-content:flex-end;font-size:18px;margin-top:1px}
</style>



