import { defineConfig, loadEnv } from 'vite'
import path from 'path'
import createVitePlugins from './vite/plugins'
import { visualizer } from 'rollup-plugin-visualizer'

// https://vitejs.dev/config/
export default defineConfig(({ mode, command }) => {
  const env = loadEnv(mode, process.cwd())
  const { VITE_APP_ENV, VITE_APP_TARGET } = env
  const isBuild = command === 'build'
  // 代理目标：默认本地后端，可在 .env.* 里用 VITE_APP_TARGET 覆盖
  const proxyTarget = VITE_APP_TARGET || 'http://localhost:8080'

  return {
    // 部署生产环境和开发环境下的URL
    base: '/',
    plugins: [
      ...createVitePlugins(env, isBuild),
      // 仅当 ANALYZE=1 时生成打包分析报告 dist/stats.html
      ...(process.env.ANALYZE ? [visualizer({ open: true, filename: 'dist/stats.html', gzipSize: true })] : [])
    ],
    resolve: {
      alias: {
        '~': path.resolve(__dirname, './'),
        '@': path.resolve(__dirname, './src'),
        // 生产构建时把整个 mock 目录替换成空模块，避免 ~125KB 假数据进 bundle
        ...(isBuild ? { '@/mock': path.resolve(__dirname, './src/mock/empty.js') } : {})
      },
      extensions: ['.mjs', '.js', '.ts', '.jsx', '.tsx', '.json', '.vue']
    },
    // 打包配置
    build: {
      sourcemap: false,
      outDir: 'dist',
      assetsDir: 'assets',
      chunkSizeWarningLimit: 2000,
      rollupOptions: {
        output: {
          chunkFileNames: 'static/js/[name]-[hash].js',
          entryFileNames: 'static/js/[name]-[hash].js',
          assetFileNames: 'static/[ext]/[name]-[hash].[ext]',
          // 把大体积第三方依赖单独拆包，避免主包过大
          manualChunks: {
            vue: ['vue', 'vue-router', 'pinia'],
            echarts: ['echarts'],
            'element-plus': ['element-plus', '@element-plus/icons-vue']
          }
        }
      }
    },
    // 生产构建时去掉 console.log（保留 warn / error）
    esbuild: {
      drop: isBuild ? ['console'] : [],
      pure: isBuild ? ['console.log', 'console.info', 'console.debug'] : []
    },
    // vite 相关配置
    server: {
      port: 5173,
      host: true,
      open: true,
      proxy: {
        '/dev-api': {
          target: proxyTarget,
          changeOrigin: true,
          rewrite: (p) => p.replace(/^\/dev-api/, '')
        },
        '^/v3/api-docs/(.*)': {
          target: proxyTarget,
          changeOrigin: true
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
