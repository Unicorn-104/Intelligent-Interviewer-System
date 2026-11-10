import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { parse, compileStyle, compileTemplate } from '@vue/compiler-sfc'
import { applicationProgressLayout } from '../src/utils/applicationProgress.js'

function timeline(count) {
  return Array.from({ length: count }, (_, index) => ({
    stage: index,
    title: `真实流程节点 ${index + 1}`,
    state: index === 0 ? 'done' : 'current',
    occurredAt: '2026-11-10T09:30:00'
  }))
}

test('第六个节点从第一行右端向下衔接，第二行反向，第三行继续正向', () => {
  const layout = applicationProgressLayout(timeline(13), 1000)
  assert.equal(layout.columns, 5)
  assert.deepEqual(layout.steps.map(step => [step.row, step.column]), [
    [0, 0], [0, 1], [0, 2], [0, 3], [0, 4],
    [1, 4], [1, 3], [1, 2], [1, 1], [1, 0],
    [2, 0], [2, 1], [2, 2]
  ])
  assert.equal(layout.edges[4].path.match(/ Q /g).length, 2)
  assert.equal(layout.edges[9].path.match(/ Q /g).length, 2)
  assert.ok(layout.steps[5].y > layout.steps[4].y)
  assert.equal(layout.steps[5].x, layout.steps[4].x)
})

test('不同容器宽度及任意节点数保持相邻节点首尾连续，不添加悬空首尾线', () => {
  for (const width of [240, 320, 420, 680, 1120]) {
    for (const count of [0, 1, 2, 5, 6, 10, 11, 31]) {
      const nodes = timeline(count)
      const layout = applicationProgressLayout(nodes, width)
      assert.equal(layout.edges.length, Math.max(0, count - 1))
      assert.equal(layout.height, Math.ceil(count / layout.columns) * layout.rowHeight)
      assert.equal(new Set(layout.steps.map(step => `${step.row}:${step.column}`)).size, count)
      assert.deepEqual(layout.steps.map(step => step.node), nodes)
      for (const edge of layout.edges) {
        const previous = layout.steps[edge.from]
        const next = layout.steps[edge.to]
        assert.ok(edge.path.startsWith(`M ${previous.x} ${previous.y} H `))
        assert.ok(edge.path.endsWith(`H ${next.x}`))
        if (previous.row === next.row) {
          assert.equal(previous.y, next.y)
          assert.equal(edge.path.includes(' Q '), false)
        } else {
          assert.ok(edge.path.includes(` ${next.y} H ${next.x}`))
          assert.equal(previous.column, next.column)
          assert.equal(next.row, previous.row + 1)
        }
        for (const step of [previous, next]) {
          assert.ok(step.x >= 0 && step.x <= width)
          assert.ok(step.y >= 0 && step.y < layout.height)
        }
      }
    }
  }
})

test('只按真实状态绘制已到达连线，不改变时间、节点数量或状态', () => {
  const nodes = Object.freeze(['done', 'processing', 'closed', 'pending'].map((state, index) => Object.freeze({ state, title: `步骤${index}`, occurredAt: null })))
  const layout = applicationProgressLayout(nodes, 1000)
  assert.deepEqual(layout.edges.map(edge => edge.reached), [true, true, false])
  assert.deepEqual(layout.steps.map(step => step.node.state), ['done', 'processing', 'closed', 'pending'])
  assert.equal(applicationProgressLayout([], Number.NaN).height, 0)
  assert.equal(applicationProgressLayout(nodes, 260).columns, 1)
  assert.equal(applicationProgressLayout(nodes, 420).columns, 2)
})

test('真实投递时间线接入独立 scoped 组件，移除旧换行断线和窄屏固定宽度', () => {
  const page = fs.readFileSync(new URL('../src/views/agent/pages/applications.vue', import.meta.url), 'utf8')
  assert.match(page, /<ApplicationProgress[^>]*:nodes="details\[item.id\].timeline"[^>]*:format-time="formatDate"/)
  assert.doesNotMatch(page, /\.progress-step[^\s{]*|min-width:480px/)
  const filename = 'ApplicationProgress.vue'
  const source = fs.readFileSync(new URL('../src/components/agent/ApplicationProgress.vue', import.meta.url), 'utf8')
  const parsed = parse(source, { filename })
  assert.deepEqual(parsed.errors, [])
  const { descriptor } = parsed
  assert.equal(descriptor.styles[0].scoped, true)
  assert.deepEqual(compileTemplate({ source: descriptor.template.content, filename, id: 'progress-test' }).errors, [])
  assert.deepEqual(compileStyle({ source: descriptor.styles[0].content, filename, id: 'progress-test', scoped: true }).errors, [])
  assert.match(source, /observer\?\.disconnect\(\)/)
  assert.match(source, /new ResizeObserver\(measure\)/)
})
