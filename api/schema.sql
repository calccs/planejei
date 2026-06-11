-- ════════════════════════════════════════════════════════════
-- Planejador Financeiro Superei — Schema PostgreSQL (Railway)
-- Executado automaticamente pelo servidor na inicialização.
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS clientes (
  id            SERIAL PRIMARY KEY,
  email         TEXT UNIQUE NOT NULL,
  nome          TEXT,
  senha_hash    TEXT NOT NULL,
  criado_em     TIMESTAMPTZ NOT NULL DEFAULT now(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Sessões de login (token aleatório devolvido ao navegador)
CREATE TABLE IF NOT EXISTS sessoes (
  token      TEXT PRIMARY KEY,
  cliente_id INT NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  criado_em  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Campos avulsos do formulário (idade, premissas, aposentadoria etc.)
CREATE TABLE IF NOT EXISTS perfil_campos (
  cliente_id INT  NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  campo      TEXT NOT NULL,
  valor      TEXT,
  PRIMARY KEY (cliente_id, campo)
);

CREATE TABLE IF NOT EXISTS dependentes (
  id          SERIAL PRIMARY KEY,
  cliente_id  INT NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  nome        TEXT,
  idade       NUMERIC,
  observacoes TEXT
);

CREATE TABLE IF NOT EXISTS ativos_financeiros (
  id         SERIAL PRIMARY KEY,
  cliente_id INT NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  descricao  TEXT,
  valor      NUMERIC,
  pct_cdi    NUMERIC,
  taxa_fixa  NUMERIC,
  categoria  TEXT
);

CREATE TABLE IF NOT EXISTS imoveis (
  id             SERIAL PRIMARY KEY,
  cliente_id     INT NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  descricao      TEXT,
  valor          NUMERIC,
  gera_renda     TEXT,
  aluguel_mensal NUMERIC
);

CREATE TABLE IF NOT EXISTS metas (
  id          SERIAL PRIMARY KEY,
  cliente_id  INT NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  nome        TEXT,
  valor_alvo  NUMERIC,
  valor_atual NUMERIC,
  prazo_meses NUMERIC
);

CREATE TABLE IF NOT EXISTS receitas (
  id           SERIAL PRIMARY KEY,
  cliente_id   INT NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  categoria    TEXT,
  valor_mensal NUMERIC
);

CREATE TABLE IF NOT EXISTS despesas (
  id           SERIAL PRIMARY KEY,
  cliente_id   INT NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  categoria    TEXT,
  valor_mensal NUMERIC
);

-- Proteção familiar: projetos a garantir (F=futuro, P=presente)
CREATE TABLE IF NOT EXISTS projetos_protecao (
  id         SERIAL PRIMARY KEY,
  cliente_id INT NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  nome       TEXT,
  tipo       TEXT,
  valor      NUMERIC,
  prazo_anos NUMERIC
);

CREATE TABLE IF NOT EXISTS receitas_futuras (
  id          SERIAL PRIMARY KEY,
  cliente_id  INT NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  descricao   TEXT,
  valor       NUMERIC,
  observacoes TEXT
);

CREATE TABLE IF NOT EXISTS dividas (
  id                SERIAL PRIMARY KEY,
  cliente_id        INT NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  descricao         TEXT,
  saldo             NUMERIC,
  prazo_anos        NUMERIC,
  taxa_anual        NUMERIC,
  parcela_mensal    NUMERIC,
  abater_patrimonio TEXT
);

-- Migração para bancos criados antes da coluna parcela_mensal
ALTER TABLE dividas ADD COLUMN IF NOT EXISTS parcela_mensal NUMERIC;

-- Educação: 5 fases fixas (Pré-Escola → Pós), na ordem do planejador
CREATE TABLE IF NOT EXISTS educacao (
  id          SERIAL PRIMARY KEY,
  cliente_id  INT NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  custo_total NUMERIC,
  observacoes TEXT
);
