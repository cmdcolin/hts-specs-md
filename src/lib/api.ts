// Post API utilities for Astro

interface PostModule {
  frontmatter: {
    title: string
    date: string
    commit?: string
    [key: string]: unknown
  }
  getHeadings: () => { depth: number, slug: string, text: string }[]
  default: any
}

export async function getAllPosts() {
  const postModules = import.meta.glob<PostModule>('/src/_posts/*.md', {
    eager: true,
  })

  return Object.entries(postModules).map(([path, module]) => {
    const filename = path.split('/').pop()!.replace('.md', '')
    return {
      id: filename,
      title: module.frontmatter.title || filename,
      date: module.frontmatter.date,
      commit: module.frontmatter.commit,
      frontmatter: module.frontmatter,
      headings: module.getHeadings(),
    }
  }).sort((a, b) => a.title.localeCompare(b.title))
}

export async function getPostById(id: string) {
  const postModules = import.meta.glob<PostModule>('/src/_posts/*.md', {
    eager: true,
  })
  const postPath = `/src/_posts/${id}.md`
  const module = postModules[postPath]

  if (!module) {
    throw new Error(`Post not found: ${id}`)
  }

  return {
    id,
    title: module.frontmatter.title || id,
    date: module.frontmatter.date,
    commit: module.frontmatter.commit,
    frontmatter: module.frontmatter,
    Content: module.default,
    headings: module.getHeadings(),
  }
}
