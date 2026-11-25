export function openCandidateAssistant(action = 'chat') {
  window.dispatchEvent(new CustomEvent('candidate-ai-open', { detail: { action } }))
}
