import pluginVue from 'eslint-plugin-vue'
import betterTailwind from 'eslint-plugin-better-tailwindcss'
import tseslint from 'typescript-eslint'

const unusedUnderscore = [
  'error',
  { argsIgnorePattern: '^_', varsIgnorePattern: '^_', destructuredArrayIgnorePattern: '^_' },
]

export default tseslint.config(
  {
    ignores: [
      'games/**',
      '**/dist/**',
      'output/**',
      'packages/rc-shared/**',
      // old non-Vue code, replaced by later tasks
      'apps/game/**',
    ],
  },
  {
    files: ['packages/**/*.ts'],
    extends: [tseslint.configs.recommended],
    rules: { '@typescript-eslint/no-unused-vars': unusedUnderscore },
  },
  {
    files: ['apps/**/*.{ts,vue}'],
    extends: [tseslint.configs.recommended, pluginVue.configs['flat/recommended']],
    languageOptions: { parserOptions: { parser: tseslint.parser, extraFileExtensions: ['.vue'] } },
    plugins: { 'better-tailwindcss': betterTailwind },
    settings: {
      'better-tailwindcss': { entryPoint: 'packages/ui/theme.css', detectComponentClasses: true },
    },
    rules: {
      '@typescript-eslint/no-unused-vars': unusedUnderscore,
      'vue/no-restricted-block': ['error', 'style'],
      'vue/no-static-inline-styles': 'error',
      'vue/no-restricted-static-attribute': ['error', 'style'],
      'better-tailwindcss/no-unknown-classes': 'error',
      'better-tailwindcss/no-conflicting-classes': 'error',
      'better-tailwindcss/no-restricted-classes': [
        'error',
        {
          restrict: [
            { pattern: '\\[([^\\[\\]]*?)\\](?!:)', message: 'No arbitrary values: put the look in packages/ui/theme.css' },
            {
              pattern:
                '^(.*:)?(bg|text|border|ring|outline|fill|stroke|from|to|via)-(slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose|black|white)(-\\d+)?(/\\d+)?$',
              message: 'No raw palette colours: use theme colours',
            },
            { pattern: '^(.*:)?(rounded|shadow)(-.*)?$', message: 'No radius/shadow overrides: the theme owns them' },
            { pattern: '^(.*:)?border-\\d+$', message: 'No border width overrides: the theme owns them' },
          ],
        },
      ],
    },
  },
)
