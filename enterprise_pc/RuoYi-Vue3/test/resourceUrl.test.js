import test from 'node:test'
import assert from 'node:assert/strict'
import { resourcePath, resolveResourceUrl } from '../src/utils/resourceUrl.js'

const origin = 'https://recruit.example.com'
const paths = [
  '/profile/storage/avatars/17/2026/11/02/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png',
  '/profile/storage/uploads/17/2026/11/02/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf',
  '/profile/upload/legacy.png'
]

test('RustFS 代理资源与旧文件统一经过当前 API，API 前缀仅添加一次', () => {
  for (const path of paths) {
    for (const value of [path, `/prod-api${path}`, `/dev-api${path}`, `http://old-backend:8080${path}`]) {
      assert.equal(resolveResourceUrl(value, '/prod-api/', origin), `${origin}/prod-api${path}`)
      assert.equal(resourcePath(value, '/prod-api', origin), path)
    }
    assert.equal(resolveResourceUrl(path, `${origin}/gateway/api/`, origin), `${origin}/gateway/api${path}`)
  }
})

test('公共外链保留原地址，拒绝存储内部引用、凭据和路径穿越', () => {
  const cdn = 'https://cdn.example.com/logo.png?v=2'
  assert.equal(resolveResourceUrl(cdn, '/prod-api', origin), cdn)
  assert.equal(resourcePath(cdn, '/prod-api', origin), '')
  for (const invalid of [
    's3:private-bucket/private-resume/17/a.pdf', 'javascript:alert(1)',
    'https://synthetic:credential@host/profile/x.png', '//host/profile/x.png',
    '/profile/../private/file.pdf', '/profile/%2e%2e/file.pdf',
    '/profile/%2fprivate/file.pdf', '/profile/a.png#fragment', '/profile/\nfile.png'
  ]) {
    assert.equal(resolveResourceUrl(invalid, '/prod-api', origin), '')
    assert.equal(resourcePath(invalid, '/prod-api', origin), '')
  }
})

test('图片上传列表保留编码后的文件名，不把 API 地址写回业务字段', () => {
  const value = '/profile/upload/附件 1.png?v=2'
  const url = resolveResourceUrl(value, '/prod-api', origin)
  assert.equal(url, `${origin}/prod-api/profile/upload/%E9%99%84%E4%BB%B6%201.png?v=2`)
  assert.equal(resourcePath(url, '/prod-api', origin), '/profile/upload/%E9%99%84%E4%BB%B6%201.png?v=2')
  assert.equal(resolveResourceUrl('/assets/default-avatar.png', '/prod-api', origin), `${origin}/assets/default-avatar.png`)
  assert.equal(resolveResourceUrl('/user/static/jpg/profile.jpg', '/prod-api', origin), `${origin}/user/static/jpg/profile.jpg`)
})
