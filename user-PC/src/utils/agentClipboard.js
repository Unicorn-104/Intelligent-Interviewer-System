export async function copyText(value, clipboard = globalThis.navigator?.clipboard, document = globalThis.document) {
  if (clipboard?.writeText) {
    try {
      await clipboard.writeText(value)
      return
    } catch {}
  }
  if (!document?.body || !document.execCommand) throw new Error('浏览器不支持自动复制，请复制地址栏中的链接')
  const previous = document.activeElement
  const input = document.createElement('textarea')
  input.value = value
  input.setAttribute('readonly', '')
  input.style.cssText = 'position:fixed;left:-9999px;top:0'
  document.body.appendChild(input)
  try {
    input.select()
    if (!document.execCommand('copy')) throw new Error('链接复制失败，请复制地址栏中的链接')
  } finally {
    input.remove()
    previous?.focus()
  }
}
