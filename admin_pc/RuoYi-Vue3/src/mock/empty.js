// 生产构建替身：通过 vite.config.js 的 alias 替换 @/mock
// 让整个 mock 目录（db.js / business.js / platform.js / index.js）不进生产包
export const useMock = false

export default null
