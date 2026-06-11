-- ════════════════════════════════════════════════════════════
-- Planejador Financeiro Planejei — Schema PostgreSQL (Railway)
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

CREATE TABLE IF NOT EXISTS sessoes (
  token      TEXT PRIMARY KEY,
  cliente_id INT NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  criado_em  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Múltiplos planejamentos por usuário
CREATE TABLE IF NOT EXISTS planejamentos (
  id            SERIAL PRIMARY KEY,
  cliente_id    INT NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  nome          TEXT NOT NULL DEFAULT 'Meu Planejamento',
  criado_em     TIMESTAMPTZ NOT NULL DEFAULT now(),
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Campos avulsos do formulário escopados por planejamento
CREATE TABLE IF NOT EXISTS perfil_campos (
  planejamento_id INT  NOT NULL REFERENCES planejamentos(id) ON DELETE CASCADE,
  campo           TEXT NOT NULL,
  valor           TEXT,
  PRIMARY KEY (planejamento_id, campo)
);

CREATE TABLE IF NOT EXISTS dependentes (
  id              SERIAL PRIMARY KEY,
  planejamento_id INT NOT NULL REFERENCES planejamentos(id) ON DELETE CASCADE,
  nome            TEXT,
  idade           NUMERIC,
  observacoes     TEXT
);

CREATE TABLE IF NOT EXISTS ativos_financeiros (
  id              SERIAL PRIMARY KEY,
  planejamento_id INT NOT NULL REFERENCES planejamentos(id) ON DELETE CASCADE,
  descricao       TEXT,
  valor           NUMERIC,
  pct_cdi         NUMERIC,
  taxa_fixa       NUMERIC,
  categoria       TEXT
);

CREATE TABLE IF NOT EXISTS imoveis (
  id              SERIAL PRIMARY KEY,
  planejamento_id INT NOT NULL REFERENCES planejamentos(id) ON DELETE CASCADE,
  descricao       TEXT,
  valor           NUMERIC,
  gera_renda      TEXT,
  aluguel_mensal  NUMERIC
);

CREATE TABLE IF NOT EXISTS metas (
  id              SERIAL PRIMARY KEY,
  planejamento_id INT NOT NULL REFERENCES planejamentos(id) ON DELETE CASCADE,
  nome            TEXT,
  valor_alvo      NUMERIC,
  valor_atual     NUMERIC,
  prazo_meses     NUMERIC
);

CREATE TABLE IF NOT EXISTS receitas (
  id              SERIAL PRIMARY KEY,
  planejamento_id INT NOT NULL REFERENCES planejamentos(id) ON DELETE CASCADE,
  categoria       TEXT,
  valor_mensal    NUMERIC
);

CREATE TABLE IF NOT EXISTS despesas (
  id              SERIAL PRIMARY KEY,
  planejamento_id INT NOT NULL REFERENCES planejamentos(id) ON DELETE CASCADE,
  categoria       TEXT,
  valor_mensal    NUMERIC
);

CREATE TABLE IF NOT EXISTS projetos_protecao (
  id              SERIAL PRIMARY KEY,
  planejamento_id INT NOT NULL REFERENCES planejamentos(id) ON DELETE CASCADE,
  nome            TEXT,
  tipo            TEXT,
  valor           NUMERIC,
  prazo_anos      NUMERIC
);

CREATE TABLE IF NOT EXISTS receitas_futuras (
  id              SERIAL PRIMARY KEY,
  planejamento_id INT NOT NULL REFERENCES planejamentos(id) ON DELETE CASCADE,
  descricao       TEXT,
  valor           NUMERIC,
  observacoes     TEXT
);

CREATE TABLE IF NOT EXISTS dividas (
  id                SERIAL PRIMARY KEY,
  planejamento_id   INT NOT NULL REFERENCES planejamentos(id) ON DELETE CASCADE,
  descricao         TEXT,
  saldo             NUMERIC,
  prazo_anos        NUMERIC,
  taxa_anual        NUMERIC,
  parcela_mensal    NUMERIC,
  abater_patrimonio TEXT
);

CREATE TABLE IF NOT EXISTS educacao (
  id              SERIAL PRIMARY KEY,
  planejamento_id INT NOT NULL REFERENCES planejamentos(id) ON DELETE CASCADE,
  custo_total     NUMERIC,
  observacoes     TEXT
);

-- Família extensa (pais, irmãos, outros parentes relevantes)
CREATE TABLE IF NOT EXISTS familia_extensa (
  id              SERIAL PRIMARY KEY,
  planejamento_id INT NOT NULL REFERENCES planejamentos(id) ON DELETE CASCADE,
  nome            TEXT,
  parentesco      TEXT,
  idade           NUMERIC,
  observacoes     TEXT
);

-- ════════════════════════════════════════════════════════════
-- MIGRAÇÕES INCREMENTAIS (idempotentes)
-- ════════════════════════════════════════════════════════════

-- 1. Adicionar planejamento_id nas tabelas que usavam cliente_id
ALTER TABLE perfil_campos      ADD COLUMN IF NOT EXISTS planejamento_id INT REFERENCES planejamentos(id) ON DELETE CASCADE;
ALTER TABLE dependentes        ADD COLUMN IF NOT EXISTS planejamento_id INT REFERENCES planejamentos(id) ON DELETE CASCADE;
ALTER TABLE ativos_financeiros ADD COLUMN IF NOT EXISTS planejamento_id INT REFERENCES planejamentos(id) ON DELETE CASCADE;
ALTER TABLE imoveis            ADD COLUMN IF NOT EXISTS planejamento_id INT REFERENCES planejamentos(id) ON DELETE CASCADE;
ALTER TABLE metas              ADD COLUMN IF NOT EXISTS planejamento_id INT REFERENCES planejamentos(id) ON DELETE CASCADE;
ALTER TABLE receitas           ADD COLUMN IF NOT EXISTS planejamento_id INT REFERENCES planejamentos(id) ON DELETE CASCADE;
ALTER TABLE despesas           ADD COLUMN IF NOT EXISTS planejamento_id INT REFERENCES planejamentos(id) ON DELETE CASCADE;
ALTER TABLE projetos_protecao  ADD COLUMN IF NOT EXISTS planejamento_id INT REFERENCES planejamentos(id) ON DELETE CASCADE;
ALTER TABLE receitas_futuras   ADD COLUMN IF NOT EXISTS planejamento_id INT REFERENCES planejamentos(id) ON DELETE CASCADE;
ALTER TABLE dividas            ADD COLUMN IF NOT EXISTS planejamento_id INT REFERENCES planejamentos(id) ON DELETE CASCADE;
ALTER TABLE educacao           ADD COLUMN IF NOT EXISTS planejamento_id INT REFERENCES planejamentos(id) ON DELETE CASCADE;

-- 2. Coluna parcela_mensal em dividas (adicionada em versão anterior)
ALTER TABLE dividas ADD COLUMN IF NOT EXISTS parcela_mensal NUMERIC;

-- 3. Migrar dados legados (cliente_id sem planejamento_id) para planos padrão
DO $$
DECLARE
  r   RECORD;
  pid INT;
BEGIN
  -- Para cada cliente com dados legados sem planejamento_id, cria plano padrão
  FOR r IN (
    SELECT DISTINCT cliente_id FROM (
      SELECT cliente_id FROM perfil_campos      WHERE planejamento_id IS NULL AND cliente_id IS NOT NULL
      UNION
      SELECT cliente_id FROM ativos_financeiros WHERE planejamento_id IS NULL AND cliente_id IS NOT NULL
      UNION
      SELECT cliente_id FROM dividas            WHERE planejamento_id IS NULL AND cliente_id IS NOT NULL
    ) sub
  ) LOOP
    -- Verifica se já existe plano para este cliente
    SELECT id INTO pid FROM planejamentos WHERE cliente_id = r.cliente_id ORDER BY id LIMIT 1;
    IF pid IS NULL THEN
      INSERT INTO planejamentos (cliente_id, nome) VALUES (r.cliente_id, 'Meu Planejamento') RETURNING id INTO pid;
    END IF;
    -- Vincula todos os dados órfãos a este plano
    UPDATE perfil_campos      SET planejamento_id = pid WHERE cliente_id = r.cliente_id AND planejamento_id IS NULL;
    UPDATE dependentes        SET planejamento_id = pid WHERE cliente_id = r.cliente_id AND planejamento_id IS NULL;
    UPDATE ativos_financeiros SET planejamento_id = pid WHERE cliente_id = r.cliente_id AND planejamento_id IS NULL;
    UPDATE imoveis            SET planejamento_id = pid WHERE cliente_id = r.cliente_id AND planejamento_id IS NULL;
    UPDATE metas              SET planejamento_id = pid WHERE cliente_id = r.cliente_id AND planejamento_id IS NULL;
    UPDATE receitas           SET planejamento_id = pid WHERE cliente_id = r.cliente_id AND planejamento_id IS NULL;
    UPDATE despesas           SET planejamento_id = pid WHERE cliente_id = r.cliente_id AND planejamento_id IS NULL;
    UPDATE projetos_protecao  SET planejamento_id = pid WHERE cliente_id = r.cliente_id AND planejamento_id IS NULL;
    UPDATE receitas_futuras   SET planejamento_id = pid WHERE cliente_id = r.cliente_id AND planejamento_id IS NULL;
    UPDATE dividas            SET planejamento_id = pid WHERE cliente_id = r.cliente_id AND planejamento_id IS NULL;
    UPDATE educacao           SET planejamento_id = pid WHERE cliente_id = r.cliente_id AND planejamento_id IS NULL;
  END LOOP;
END $$;

-- 4. Corrigir PK de perfil_campos: era (cliente_id, campo), precisa ser (planejamento_id, campo)
ALTER TABLE perfil_campos DROP CONSTRAINT IF EXISTS perfil_campos_pkey;
CREATE UNIQUE INDEX IF NOT EXISTS perfil_campos_plan_campo
  ON perfil_campos(planejamento_id, campo)
  WHERE planejamento_id IS NOT NULL;
