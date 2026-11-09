import { defineConfig, loadEnv } from 'vite'
import path from 'path'
import { fileURLToPath } from 'url'
import basicSsl from '@vitejs/plugin-basic-ssl'
import createVitePlugins from './vite/plugins'

const baseUrl = 'http://localhost:8080' // 后端接口
const rootDir = path.dirname(fileURLToPath(import.meta.url))

// https://vitejs.dev/config/
export default defineConfig(({ mode, command }) => {
  const env = loadEnv(mode, process.cwd())
  const { VITE_BACKEND_TARGET = baseUrl } = env
  return {
    // 部署生产环境和开发环境下的URL。
    // 默认情况下，vite 会假设你的应用是被部署在一个域名的根路径上
    // 例如 https://www.ruoyi.vip/。如果应用被部署在一个子路径上，你就需要用这个选项指定这个子路径。例如，如果你的应用被部署在 https://www.ruoyi.vip/admin/，则设置 baseUrl 为 /admin/。
    base: command === 'build' ? '/user/' : '/',
    // 摄像头（getUserMedia）要求安全上下文，局域网 IP 走 http 会被浏览器禁用，故开发环境启用自签名 HTTPS
    plugins: [...createVitePlugins(env, command === 'build'), basicSsl()],
    resolve: {
      // https://cn.vitejs.dev/config/#resolve-alias
      alias: {
        // 设置路径
        '~': path.resolve(rootDir, './'),
        // 设置别名
        '@': path.resolve(rootDir, './src')
      },
      // https://cn.vitejs.dev/config/#resolve-extensions
      extensions: ['.mjs', '.js', '.ts', '.jsx', '.tsx', '.json', '.vue']
    },
    // 打包配置
    build: {
      // https://vite.dev/config/build-options.html
      sourcemap: command === 'build' ? false : 'inline',
      outDir: 'dist',
      assetsDir: 'assets',
      chunkSizeWarningLimit: 2000,
      rollupOptions: {
        output: {
          chunkFileNames: 'static/js/[name]-[hash].js',
          entryFileNames: 'static/js/[name]-[hash].js',
          assetFileNames: 'static/[ext]/[name]-[hash].[ext]'
        }
      }
    },
    // vite 相关配置
    server: {
      port: 5180,
      host: '0.0.0.0',
      open: true,
      proxy: {
        // https://cn.vitejs.dev/config/#server-proxy
        '/dev-api': {
          target: VITE_BACKEND_TARGET,
          // 保留浏览器原始 Host，后端据此把 LiveKit 地址改写为手机可直接访问的局域网地址
          changeOrigin: false,
          rewrite: (p) => p.replace(/^\/dev-api/, '')
        },
         // springdoc proxy
         '^/v3/api-docs/(.*)': {
          target: VITE_BACKEND_TARGET,
          changeOrigin: true,
        },
        // 实时字幕 WebSocket 后端代理
        '/ws': {
          target: VITE_BACKEND_TARGET,
          ws: true,
          changeOrigin: true
        },
        // HTTPS 页面用同源 wss 访问 LiveKit 信令（规避混合内容拦截）
        '/livekit': {
          target: 'ws://localhost:7880',
          ws: true,
          rewrite: (p) => p.replace(/^\/livekit/, '')
        }
      }
    },
    css: {
      postcss: {
        plugins: [
          {
            postcssPlugin: 'internal:charset-removal',
            AtRule: {
              charset: (atRule) => {
                if (atRule.name === 'charset') {
                  atRule.remove()
                }
              }
            }
          }
        ]
      }
    }
  }
})
