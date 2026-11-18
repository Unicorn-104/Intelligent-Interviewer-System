<template>
  <article class="message-content-card" :class="`message-content-card--${card.kind}`">
    <header class="message-content-card__header">
      <span class="message-content-card__icon" aria-hidden="true">
        <svg v-if="card.kind === 'job'" viewBox="0 0 24 24"><rect x="3" y="7" width="18" height="14" rx="3"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 12a23 23 0 0 0 18 0M12 11v4"/></svg>
        <svg v-else viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="16" rx="3"/><path d="M7 3v4M17 3v4M3 11h18m-13 5 3 2 5-4"/></svg>
      </span>
      <span class="message-content-card__label">{{ card.label }}</span>
      <span v-if="card.status" class="message-content-card__status" :class="`message-content-card__status--${card.tone}`">{{ card.status }}</span>
    </header>
    <div class="message-content-card__body">
      <h3>{{ card.title }}</h3>
      <p v-if="card.highlight" class="message-content-card__salary">{{ card.highlight }}</p>
      <p v-if="card.subtitle" class="message-content-card__subtitle">{{ card.subtitle }}</p>
      <div v-if="card.tags?.length" class="message-content-card__tags"><span v-for="tag in card.tags" :key="tag">{{ tag }}</span></div>
      <dl v-if="card.fields?.length" class="message-content-card__fields">
        <div v-for="(field, index) in card.fields" :key="index"><dt>{{ field.label }}</dt><dd><template v-for="(part, partIndex) in messageLinkParts(field.value)" :key="partIndex"><a v-if="part.href" class="message-content-card__link" :href="part.href" target="_blank" rel="noopener noreferrer">{{ part.text }}</a><template v-else>{{ part.text }}</template></template></dd></div>
      </dl>
      <p v-if="card.description" class="message-content-card__description"><template v-for="(part, index) in messageLinkParts(card.description)" :key="index"><a v-if="part.href" class="message-content-card__link" :href="part.href" target="_blank" rel="noopener noreferrer">{{ part.text }}</a><template v-else>{{ part.text }}</template></template></p>
      <a v-for="link in card.links" :key="link.href" class="message-content-card__link" :href="link.href" target="_blank" rel="noopener noreferrer">{{ link.text }}</a>
      <p v-if="card.footnote" class="message-content-card__footnote">{{ card.footnote }}</p>
    </div>
    <RouterLink v-if="card.action" class="message-content-card__action" :to="card.action.to"><span>{{ card.action.label }}</span><span aria-hidden="true">→</span></RouterLink>
  </article>
</template>

<script setup>
import { RouterLink } from 'vue-router'
import { messageLinkParts } from '@/utils/agentMessage'

defineProps({ card: { type: Object, required: true } })
</script>

<style scoped>
.message-content-card{width:320px;max-width:100%;overflow:hidden;border:1px solid #dce5f0;border-radius:14px;background:#fff;color:#24354b;box-shadow:0 3px 12px rgba(26,60,110,.05);text-align:left;overflow-wrap:anywhere}
.message-content-card__header{display:flex;align-items:center;gap:9px;padding:12px 15px;border-bottom:1px solid #e9eef6;background:#f4f8ff}
.message-content-card__icon{display:grid;flex:0 0 30px;width:30px;height:30px;place-items:center;border-radius:9px;background:#e4eeff;color:#3671cd}
.message-content-card__icon svg{width:18px;height:18px;fill:none;stroke:currentColor;stroke-width:1.7;stroke-linecap:round;stroke-linejoin:round}
.message-content-card__label{flex:1;min-width:0;color:#506887;font-size:12px;font-weight:600}
.message-content-card__status{flex-shrink:0;padding:3px 7px;border-radius:20px;background:#eef1f5;color:#67768a;font-size:10px}
.message-content-card__status--success{background:#e4f5ed;color:#217553}
.message-content-card__status--pending{background:#fff2da;color:#98651b}
.message-content-card__body{padding:15px}
.message-content-card h3{margin:0;color:#1c3454;font-size:16px;font-weight:700;line-height:1.5}
.message-content-card__salary{margin:7px 0 0;color:#d07133;font-size:16px;font-weight:700;line-height:1.5}
.message-content-card__subtitle{margin:7px 0 0;color:#61738a;font-size:12px;line-height:1.7}
.message-content-card__tags{display:flex;flex-wrap:wrap;gap:6px;margin-top:12px}
.message-content-card__tags span{padding:3px 7px;border-radius:5px;background:#f1f5fa;color:#607187;font-size:11px;line-height:1.5}
.message-content-card__fields{display:grid;gap:12px;margin:14px 0 0}
.message-content-card__fields div{min-width:0;padding-left:10px;border-left:2px solid #dce7f5}
.message-content-card__fields dt{margin:0 0 3px;color:#7b889a;font-size:11px;line-height:1.6}
.message-content-card__fields dd{margin:0;color:#30435e;font-size:12px;line-height:1.75;white-space:pre-wrap}
.message-content-card__description{margin:12px 0 0;font-size:12px;line-height:1.8;white-space:pre-wrap}
.message-content-card__link{display:block;margin-top:8px;color:#2867c0;font-size:12px;text-decoration:underline}
.message-content-card__fields .message-content-card__link,.message-content-card__description .message-content-card__link{display:inline;margin:0}
.message-content-card__footnote{margin:14px 0 0;color:#8995a5;font-size:10px;line-height:1.7}
.message-content-card__action{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:12px 15px;border-top:1px solid #e9eef6;background:#fbfdff;color:#2867c0;font-size:12px;font-weight:600;text-decoration:none;transition:background .15s}
.message-content-card__action:hover{background:#edf4ff}
.message-content-card__action:focus-visible{outline:2px solid #568bd5;outline-offset:-3px}
@media(max-width:480px){.message-content-card__header,.message-content-card__body,.message-content-card__action{padding:11px}.message-content-card h3{font-size:14px}.message-content-card__status{font-size:9px;padding:3px 5px}}
</style>
