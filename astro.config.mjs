import { defineConfig } from 'astro/config';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';
import rehypeAutolinkHeadings from 'rehype-autolink-headings';
import { visit } from 'unist-util-visit';

function remarkStripHeaderAnchors() {
  return (tree) => {
    visit(tree, 'heading', (node) => {
      node.children = node.children.filter(
        child => !(child.type === 'html' && child.value.includes('header-anchor'))
      );
      while (node.children.length > 0) {
        const last = node.children[node.children.length - 1];
        if (last.type === 'text' && last.value.trim() === '') {
          node.children.pop();
        } else {
          break;
        }
      }
    });
  };
}

// https://astro.build/config
export default defineConfig({
  site: 'https://cmdcolin.github.io',
  base: '/hts-specs-md',
  markdown: {
    syntaxHighlight: false,
    remarkPlugins: [remarkStripHeaderAnchors, remarkMath],
    rehypePlugins: [
      [rehypeKatex, { output: 'mathml', strict: false }],
      [rehypeAutolinkHeadings, {
        behavior: 'append',
        properties: { className: ['header-anchor'], ariaHidden: true },
        content: { type: 'text', value: '#' },
      }],
    ],
  },
});
