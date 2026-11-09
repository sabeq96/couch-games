import { ESLint } from 'eslint'
import { describe, expect, it } from 'vitest'

const eslint = new ESLint({ cwd: new URL('../..', import.meta.url).pathname })

async function ruleIds(template: string): Promise<string[]> {
  const code = `<template>${template}</template>`
  const [result] = await eslint.lintText(code, { filePath: 'apps/shell/src/ClassProbe.vue' })
  return result.messages.map((m) => m.ruleId ?? 'parse-error')
}

describe('lint keeps the look in the theme', () => {
  it.each([
    ['raw palette colour', '<div class="btn bg-pink-300" />', 'better-tailwindcss/no-restricted-classes'],
    ['arbitrary value', '<div class="text-[#fff]" />', 'better-tailwindcss/no-restricted-classes'],
    ['radius override', '<div class="btn rounded-none" />', 'better-tailwindcss/no-restricted-classes'],
    ['shadow override', '<div class="card shadow-xl" />', 'better-tailwindcss/no-restricted-classes'],
    ['unknown class', '<div class="btnn" />', 'better-tailwindcss/no-unknown-classes'],
    ['static inline style', '<div style="color:red" />', 'vue/no-static-inline-styles'],
  ])('rejects %s', async (_name, template, rule) => {
    expect(await ruleIds(template)).toContain(rule)
  })

  it('rejects a style block', async () => {
    const [result] = await eslint.lintText('<template><div /></template>\n<style>.a{}</style>', {
      filePath: 'apps/shell/src/ClassProbe.vue',
    })
    expect(result.messages.map((m) => m.ruleId)).toContain('vue/no-restricted-block')
  })

  it('accepts theme classes and layout utilities', async () => {
    const template = '<div class="btn btn-primary flex gap-2 bg-player-2 text-base-content" />'
    expect(await ruleIds(template)).toEqual([])
  })
})
