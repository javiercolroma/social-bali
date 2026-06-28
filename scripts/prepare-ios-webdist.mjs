import { readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

const webDistPath = join(process.cwd(), 'ios', 'WebDist')
const indexPath = join(webDistPath, 'index.html')

const indexHtml = readFileSync(indexPath, 'utf8')
  .replace(/<script type="module" crossorigin src="([^"]+)"><\/script>/, '<script defer src="$1"></script>')
  .replace(/<link rel="stylesheet" crossorigin href="([^"]+)">/, '<link rel="stylesheet" href="$1">')

writeFileSync(indexPath, indexHtml)
