export function applicationProgressLayout(nodes, availableWidth) {
  const width = Number.isFinite(availableWidth) && availableWidth > 0 ? availableWidth : 800
  const columns = Math.max(1, Math.min(5, nodes.length, Math.floor((width - 48) / 130)))
  const rowHeight = 112
  const gutter = Math.min(24, width / 4)
  const cellWidth = (width - gutter * 2) / columns
  const steps = nodes.map((node, index) => {
    const row = Math.floor(index / columns)
    const offset = index % columns
    const column = row % 2 ? columns - offset - 1 : offset
    return { node, index, row, column, x: gutter + (column + 0.5) * cellWidth, y: row * rowHeight + 16 }
  })
  const reached = node => ['done', 'closed', 'current', 'processing'].includes(node.state)
  const edges = steps.slice(1).map((step, index) => {
    const previous = steps[index]
    let path = `M ${previous.x} ${previous.y} H ${step.x}`
    if (previous.row !== step.row) {
      const direction = previous.row % 2 ? -1 : 1
      const turn = direction > 0 ? width - gutter / 2 : gutter / 2
      const radius = Math.min(16, Math.abs(turn - previous.x) / 2, rowHeight / 2)
      const shoulder = turn - direction * radius
      path = `M ${previous.x} ${previous.y} H ${shoulder}`
        + ` Q ${turn} ${previous.y} ${turn} ${previous.y + radius}`
        + ` V ${step.y - radius} Q ${turn} ${step.y} ${shoulder} ${step.y} H ${step.x}`
    }
    return { path, from: previous.index, to: step.index, reached: reached(previous.node) && reached(step.node) }
  })
  return { width, columns, rowHeight, height: Math.ceil(nodes.length / columns) * rowHeight, steps, edges }
}
