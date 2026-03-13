import { defineConfig, defineCollection, z } from 'astro:content';

const specs = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string().optional(),
    date: z.string().optional(),
    commit: z.string().optional(),
  }),
});

export const collections = {
  'specs': specs,
};
