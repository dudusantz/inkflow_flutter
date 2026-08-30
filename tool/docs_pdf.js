// Converte um documento de Docs/ em PDF, imprimindo via navegador headless.
//
// Uso: node tool/docs_pdf.js Docs/analise-tecnica.md
//
// Não depende de npm install: usa o Edge ou o Chrome já instalado na máquina.
// O HTML intermediário é gravado em build/ (ignorado pelo git) e removido ao fim.

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');

const BROWSERS = [
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  '/usr/bin/microsoft-edge',
  '/usr/bin/google-chrome',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
];

function findBrowser() {
  const found = BROWSERS.find((p) => fs.existsSync(p));
  if (!found) {
    throw new Error(
      'Nenhum navegador baseado em Chromium encontrado. Instale o Edge ou o Chrome.',
    );
  }
  return found;
}

const escapeHtml = (s) =>
  s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');

// Formatação dentro de uma linha, aplicada depois do escape de HTML.
function inline(text) {
  return escapeHtml(text)
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/(^|[^*])\*([^*]+)\*/g, '$1<em>$2</em>')
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
}

const splitRow = (line) =>
  line
    .trim()
    .replace(/^\||\|$/g, '')
    .split('|')
    .map((c) => c.trim());

const isDivider = (line) => /^\|?[\s:|-]+\|[\s:|-]*$/.test(line);

function renderMarkdown(md) {
  const lines = md.split(/\r?\n/);
  const out = [];
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];

    if (!line.trim()) {
      i++;
      continue;
    }

    if (/^---+$/.test(line.trim())) {
      out.push('<hr>');
      i++;
      continue;
    }

    const heading = line.match(/^(#{1,6})\s+(.*)$/);
    if (heading) {
      const level = heading[1].length;
      out.push(`<h${level}>${inline(heading[2])}</h${level}>`);
      i++;
      continue;
    }

    // Tabela: cabeçalho + linha divisória + corpo.
    if (line.includes('|') && i + 1 < lines.length && isDivider(lines[i + 1])) {
      const head = splitRow(line);
      i += 2;
      const body = [];
      while (i < lines.length && lines[i].includes('|') && lines[i].trim()) {
        body.push(splitRow(lines[i]));
        i++;
      }
      const th = head.map((c) => `<th>${inline(c)}</th>`).join('');
      const rows = body
        .map((r) => `<tr>${r.map((c) => `<td>${inline(c)}</td>`).join('')}</tr>`)
        .join('');
      out.push(`<table><thead><tr>${th}</tr></thead><tbody>${rows}</tbody></table>`);
      continue;
    }

    if (/^>\s?/.test(line)) {
      const buf = [];
      while (i < lines.length && /^>\s?/.test(lines[i])) {
        buf.push(lines[i].replace(/^>\s?/, ''));
        i++;
      }
      out.push(`<blockquote>${renderMarkdown(buf.join('\n'))}</blockquote>`);
      continue;
    }

    const listMatch = line.match(/^(\s*)([-*]|\d+\.)\s+/);
    if (listMatch) {
      const ordered = /\d/.test(listMatch[2]);
      const items = [];
      while (i < lines.length && /^\s*([-*]|\d+\.)\s+/.test(lines[i])) {
        items.push(inline(lines[i].replace(/^\s*([-*]|\d+\.)\s+/, '')));
        i++;
      }
      const tag = ordered ? 'ol' : 'ul';
      out.push(`<${tag}>${items.map((t) => `<li>${t}</li>`).join('')}</${tag}>`);
      continue;
    }

    const buf = [];
    while (
      i < lines.length &&
      lines[i].trim() &&
      !/^(#{1,6}\s|>|\s*([-*]|\d+\.)\s)/.test(lines[i]) &&
      !/^---+$/.test(lines[i].trim())
    ) {
      buf.push(lines[i]);
      i++;
    }
    out.push(`<p>${inline(buf.join(' '))}</p>`);
  }

  return out.join('\n');
}

const STYLE = `
  @page { size: A4; margin: 18mm 16mm; }
  body { font-family: "Segoe UI", Arial, sans-serif; font-size: 10.5pt;
         line-height: 1.55; color: #1f2430; }
  h1 { font-size: 22pt; margin: 0 0 4pt; color: #111827; }
  h2 { font-size: 15pt; margin: 22pt 0 6pt; padding-bottom: 4pt;
       border-bottom: 1px solid #e5e7eb; color: #111827;
       break-after: avoid; }
  h3 { font-size: 12pt; margin: 14pt 0 4pt; color: #374151; break-after: avoid; }
  p { margin: 6pt 0; text-align: justify; }
  hr { border: 0; border-top: 1px solid #e5e7eb; margin: 16pt 0; }
  ul, ol { margin: 6pt 0 6pt 16pt; padding: 0; }
  li { margin: 3pt 0; }
  code { font-family: Consolas, "Courier New", monospace; font-size: 9pt;
         background: #f3f4f6; padding: 1px 4px; border-radius: 3px; }
  table { width: 100%; border-collapse: collapse; margin: 8pt 0;
          font-size: 9.5pt; break-inside: avoid; }
  th { background: #f3f4f6; text-align: left; font-weight: 600; }
  th, td { border: 1px solid #d9dde3; padding: 5pt 7pt; vertical-align: top; }
  blockquote { margin: 8pt 0; padding: 6pt 12pt; background: #fff8e6;
               border-left: 3px solid #f0b429; break-inside: avoid; }
  blockquote p { margin: 2pt 0; }
  a { color: #1d4ed8; text-decoration: none; }
`;

function main() {
  const input = process.argv[2];
  if (!input) {
    console.error('Uso: node tool/docs_pdf.js <arquivo.md>');
    process.exit(1);
  }

  const root = path.resolve(__dirname, '..');
  const source = path.resolve(root, input);
  const pdf = source.replace(/\.md$/, '.pdf');

  const title = path.basename(source, '.md');
  const html = `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">
<title>${title}</title><style>${STYLE}</style></head>
<body>${renderMarkdown(fs.readFileSync(source, 'utf8'))}</body></html>`;

  const buildDir = path.join(root, 'build');
  fs.mkdirSync(buildDir, { recursive: true });
  const tmpHtml = path.join(buildDir, `${title}.html`);
  fs.writeFileSync(tmpHtml, html, 'utf8');

  // O Chromium exige um perfil gravável mesmo em modo headless.
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'docs-pdf-'));

  try {
    execFileSync(findBrowser(), [
      '--headless=new',
      '--disable-gpu',
      '--no-sandbox',
      `--user-data-dir=${profile}`,
      '--no-pdf-header-footer',
      `--print-to-pdf=${pdf}`,
      `file:///${tmpHtml.replace(/\\/g, '/')}`,
    ], { stdio: 'inherit' });
  } finally {
    fs.rmSync(tmpHtml, { force: true });
    fs.rmSync(profile, { recursive: true, force: true });
  }

  console.log(`PDF gerado: ${path.relative(root, pdf)}`);
}

main();
