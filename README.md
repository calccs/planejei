# Planejei — Planejador Financeiro

Planejador financeiro completo em uma página (HTML + Chart.js), com:

- 9 abas: dados, carteira, projeção, aposentadoria, metas, orçamento, proteção, educação e dívidas
- Importação da declaração de IRPF (arquivo `.DEC`, layout 2026)
- **Tela de login** obrigatória com validação por e-mail e senha (criar conta / entrar)
- Salvamento local (localStorage) e **na nuvem** (PostgreSQL via Railway)

## Estrutura

```
planejador.html   ← aplicação completa (frontend)
package.json      ← ponto de entrada para o Railway (npm start)
api/
  server.js       ← API Express: login por e-mail/senha + salvar/carregar
  schema.sql      ← tabelas PostgreSQL (criadas automaticamente no boot)
```

## Tabelas no banco

| Tabela | Conteúdo |
|---|---|
| `clientes` | e-mail, nome, senha (hash scrypt) |
| `sessoes` | tokens de login (validade 90 dias) |
| `perfil_campos` | campos avulsos do formulário (idade, premissas etc.) |
| `dependentes` | nome, idade, observações |
| `ativos_financeiros` | descrição, valor, %CDI, taxa fixa, categoria |
| `imoveis` | descrição, valor, gera renda?, aluguel mensal |
| `metas` | nome, valor alvo, valor atual, prazo em meses |
| `receitas` / `despesas` | orçamento mensal |
| `projetos_protecao` | proteção familiar (tipo F/P, valor, prazo) |
| `receitas_futuras` | recebíveis futuros |
| `dividas` | descrição, saldo, prazo, taxa, abater do patrimônio? |
| `educacao` | custo por fase escolar |

## Deploy no Railway

1. Crie conta em [railway.com](https://railway.com) (login com GitHub).
2. **New Project → Deploy from GitHub repo** → selecione este repositório.
3. No projeto, **+ New → Database → PostgreSQL**.
4. No serviço da aplicação: **Variables → + New Variable → Add Reference → `DATABASE_URL`** (do Postgres).
5. **Settings → Networking → Generate Domain** para obter a URL pública.

Pronto: a URL serve o planejador e a API juntos. As tabelas são criadas automaticamente na primeira inicialização.

## Rodar localmente

```bash
npm install
# opcional: defina DATABASE_URL para testar a nuvem localmente
npm start          # http://localhost:3000
```

Sem `DATABASE_URL`, o servidor funciona normalmente, mas os botões de nuvem retornam erro 503.

## Login e nuvem

Ao abrir o app aparece a **tela de login** (obrigatória):

- **Criar conta**: nome, e-mail e senha (mínimo 6 caracteres; armazenada como hash scrypt). O estado atual do planejador é salvo na conta nova.
- **Entrar**: valida e-mail/senha e carrega tudo do banco: campos, carteira, imóveis, dívidas, orçamento, metas, proteção e educação.

Logado, o botão **💾 Salvar** grava no navegador **e** no banco. A sessão dura 90 dias (auto-login ao reabrir); **Sair** encerra a sessão.

## Privacidade

O `.gitignore` usa whitelist: só `planejador.html`, `README.md`, `package.json` e `api/` são versionados. Declarações de IR (`.DEC`/PDF) e planilhas pessoais **nunca** entram no repositório. O servidor serve apenas o `planejador.html`, nunca a pasta inteira.
