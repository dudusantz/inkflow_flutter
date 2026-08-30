# Documentação InkFlow

| Documento | Descrição |
|-----------|-----------|
| [analise-tecnica.md](./analise-tecnica.md) · [PDF](./analise-tecnica.pdf) | Análise técnica do código: segurança/LGPD, bugs, arquitetura, testes e infraestrutura, com o que foi corrigido e o que continua em aberto |
| [requisitos-funcionais.md](./requisitos-funcionais.md) | RFs 01–10 com cenários BDD (Dado/Quando/Então) e status de implementação |
| [preview_route.md](./preview_route.md) | Rota temporária de visualização direta para ArtistHomeScreen |
| [changelog_seguro.md](./changelog_seguro.md) | Controle de Alterações (navegação segura) e guia de banco de dados |

## Como gerar o PDF

O PDF da análise é gerado a partir do próprio Markdown, usando o Edge ou o Chrome
já instalado na máquina (sem `npm install`):

```bash
node tool/docs_pdf.js Docs/analise-tecnica.md
```

O Markdown é a fonte da verdade — edite o `.md` e regenere o PDF.
