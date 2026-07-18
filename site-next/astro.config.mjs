import { defineConfig } from 'astro/config';

// Static output for GitHub Pages. `site` matches the production domain so
// canonical URLs resolve; base stays '/' because the repo deploys at the apex.
export default defineConfig({
  site: 'https://ancientwisdomatlas.com',
  output: 'static',
  build: {
    format: 'directory',
  },
});
