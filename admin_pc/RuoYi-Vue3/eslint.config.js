import js from '@eslint/js'
import pluginVue from 'eslint-plugin-vue'
import configPrettier from '@vue/eslint-config-prettier'

export default [
  {
    ignores: ['dist/**', 'node_modules/**', 'public/**', 'bin/**', 'docs/**', 'vite/**', '**/*.md', 'vite.config.js']
  },
  js.configs.recommended,
  ...pluginVue.configs['flat/essential'],
  configPrettier,
  {
    files: ['src/**/*.{js,vue}'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: {
        // 浏览器全局
        window: 'readonly',
        document: 'readonly',
        navigator: 'readonly',
        location: 'readonly',
        localStorage: 'readonly',
        sessionStorage: 'readonly',
        console: 'readonly',
        setTimeout: 'readonly',
        clearTimeout: 'readonly',
        setInterval: 'readonly',
        clearInterval: 'readonly',
        requestAnimationFrame: 'readonly',
        cancelAnimationFrame: 'readonly',
        Blob: 'readonly',
        FileReader: 'readonly',
        FormData: 'readonly',
        URL: 'readonly',
        URLSearchParams: 'readonly',
        fetch: 'readonly',
        // unplugin-auto-import: vue
        ref: 'readonly', shallowRef: 'readonly', triggerRef: 'readonly', toRef: 'readonly',
        toRefs: 'readonly', isRef: 'readonly', unref: 'readonly', reactive: 'readonly',
        shallowReactive: 'readonly', readonly: 'readonly', shallowReadonly: 'readonly',
        isReactive: 'readonly', isReadonly: 'readonly', isProxy: 'readonly', toRaw: 'readonly',
        markRaw: 'readonly', computed: 'readonly', watch: 'readonly', watchEffect: 'readonly',
        watchPostEffect: 'readonly', watchSyncEffect: 'readonly', onMounted: 'readonly',
        onBeforeMount: 'readonly', onBeforeUnmount: 'readonly', onUnmounted: 'readonly',
        onBeforeUpdate: 'readonly', onUpdated: 'readonly', onActivated: 'readonly',
        onDeactivated: 'readonly', onErrorCaptured: 'readonly', onRenderTracked: 'readonly',
        onRenderTriggered: 'readonly', getCurrentInstance: 'readonly', getCurrentScope: 'readonly',
        onScopeDispose: 'readonly', nextTick: 'readonly', defineAsyncComponent: 'readonly',
        defineComponent: 'readonly', h: 'readonly', inject: 'readonly', provide: 'readonly',
        resolveComponent: 'readonly',
        // unplugin-auto-import: vue-router
        useRouter: 'readonly', useRoute: 'readonly', useLink: 'readonly',
        // unplugin-auto-import: pinia
        defineStore: 'readonly', storeToRefs: 'readonly',
        // 自定义自动导入
        useDict: 'readonly', selectDictLabel: 'readonly'
      }
    },
    rules: {
      // 允许 console.warn / error，仅警告裸 console.log（生产已 drop）
      'no-console': ['warn', { allow: ['warn', 'error'] }],
      // 未使用变量：忽略 _ 前缀的参数
      'no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
      // Vue 模板里多词组件名不强制（后台系统大量单字词组）
      'vue/multi-word-component-names': 'off',
      // v-html 警告保留（防 XSS）
      'vue/no-v-html': 'warn',
      // 以下规则降级为 warn：RuoYi 后台系统常见模式，不阻断构建
      'vue/no-mutating-props': 'warn',
      'vue/no-side-effects-in-computed-properties': 'warn',
      'vue/require-valid-default-prop': 'warn',
      'no-empty': 'warn',
      'vue/no-unused-vars': 'warn',
      'no-useless-assignment': 'warn',
      'no-useless-escape': 'warn',
      'vue/no-deprecated-filter': 'warn',
      'vue/no-ref-as-operand': 'warn',
      'vue/no-dupe-keys': 'warn',
      'no-redeclare': 'warn',
      'no-prototype-builtins': 'warn'
    }
  }
]
