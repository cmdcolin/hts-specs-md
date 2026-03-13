import { defineConfig } from 'astro/config';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import rehypeAutolinkHeadings from 'rehype-autolink-headings';

// https://astro.build/config
export default defineConfig({
  site: 'https://cmdcolin.github.io',
  base: '/hts-specs-md',
  markdown: {
    syntaxHighlight: false,
    remarkPlugins: [remarkMath],
    rehypePlugins: [
      [rehypeKatex, { output: 'mathml' }],
      [rehypeAutolinkHeadings, {
        behavior: 'append',
        properties: { className: ['header-anchor'], ariaHidden: true },
        content: { type: 'text', value: '#' },
      }],
    ],
  },
});
