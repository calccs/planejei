// ════════════════════════════════════════════════════════════
// Planejador Financeiro Superei — API (Express + PostgreSQL)
// Deploy: Railway (detecta package.json na raiz e roda npm start)
// Variável necessária: DATABASE_URL (referência ao Postgres do Railway)
// ════════════════════════════════════════════════════════════
const path   = require('path');
const fs     = require('fs');
const crypto = require('crypto');
const express = require('express');
const { Pool } = require('pg');

const app = express();
app.use(express.json({ limit: '2mb' }));

// Serve APENAS o planejador (nunca a pasta inteira — há arquivos pessoais nela)
const HTML = path.join(__dirname, '..', 'planejador.html');
app.get('/', (_req, res) => res.sendFile(HTML));

const DATABASE_URL = process.env.DATABASE_URL;
const pool = DATABASE_URL ? new Pool({
  connectionString: DATABASE_URL,
  ssl: (DATABASE_URL.includes('railway.internal') || DATABASE_URL.includes('localhost'))
    ? false : { rejectUnauthorized: false },
}) : null;

// ── Mapa: chave do snapshot → tabela e colunas (na ordem das células)
// num = índices das colunas numéricas (valores chegam em formato pt-BR)
const TABELAS = {
  dep:    { tabela: 'dependentes',        cols: ['nome','idade','observacoes'],                              num: [1] },
  fin:    { tabela: 'ativos_financeiros', cols: ['descricao','valor','pct_cdi','taxa_fixa','categoria'],     num: [1,2,3] },
  imovel: { tabela: 'imoveis',            cols: ['descricao','valor','gera_renda','aluguel_mensal'],         num: [1,3] },
  metas:  { tabela: 'metas',              cols: ['nome','valor_alvo','valor_atual','prazo_meses'],           num: [1,2,3] },
  rec:    { tabela: 'receitas',           cols: ['categoria','valor_mensal'],                                num: [1] },
  desp:   { tabela: 'despesas',           cols: ['categoria','valor_mensal'],                                num: [1] },
  proj:   { tabela: 'projetos_protecao',  cols: ['nome','tipo','valor','prazo_anos'],                        num: [2,3] },
  recfut: { tabela: 'receitas_futuras',   cols: ['descricao','valor','observacoes'],                         num: [1] },
  div:    { tabela: 'dividas',            cols: ['descricao','saldo','prazo_anos','taxa_anual','parcela_mensal','abater_patrimonio'], num: [1,2,3,4] },
  edu:    { tabela: 'educacao',           cols: ['custo_total','observacoes'],                               num: [0] },
};

// "46.320,46" → 46320.46 | "100" → 100 | inválido → null
const parseBR = s => {
  if (s == null) return null;
  s = String(s).trim();
  if (!s) return null;
  const n = s.includes(',') ? +s.replace(/\./g, '').replace(',', '.') : +s;
  return Number.isFinite(n) ? n : null;
};

const hashSenha = senha => new Promise((ok, err) => {
  const salt = crypto.randomBytes(16).toString('hex');
  crypto.scrypt(senha, salt, 64, (e, dk) => e ? err(e) : ok(salt + ':' + dk.toString('hex')));
});
const verificaSenha = (senha, hash) => new Promise((ok, err) => {
  const [salt, dk] = String(hash).split(':');
  crypto.scrypt(senha, salt, 64, (e, dk2) =>
    e ? err(e) : ok(crypto.timingSafeEqual(Buffer.from(dk, 'hex'), dk2)));
});

app.get('/api/health', async (_req, res) => {
  let db = false;
  try { if (pool) { await pool.query('SELECT 1'); db = true; } } catch {}
  res.json({ ok: true, db });
});

// ── Sessões ────────────────────────────────────────────────
const novoToken = () => crypto.randomBytes(32).toString('hex');

// Devolve {id, email, nome} do cliente dono do token, ou null
async function clientePorToken(token) {
  if (!token) return null;
  const { rows } = await pool.query(
    `SELECT c.id, c.email, c.nome FROM sessoes s
       JOIN clientes c ON c.id = s.cliente_id
      WHERE s.token = $1 AND s.criado_em > now() - interval '90 days'`, [token]);
  return rows[0] || null;
}

// ── Criar conta ────────────────────────────────────────────
app.post('/api/registrar', async (req, res) => {
  if (!pool) return res.status(503).json({ erro: 'Banco de dados não configurado (DATABASE_URL ausente)' });
  let { email, senha, nome } = req.body || {};
  email = String(email || '').trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email))
    return res.status(400).json({ erro: 'E-mail inválido' });
  if (!senha || String(senha).length < 6)
    return res.status(400).json({ erro: 'A senha precisa ter pelo menos 6 caracteres' });
  try {
    const existe = await pool.query('SELECT 1 FROM clientes WHERE email=$1', [email]);
    if (existe.rows.length > 0)
      return res.status(409).json({ erro: 'E-mail já cadastrado — use Entrar' });
    const hash = await hashSenha(String(senha));
    const { rows } = await pool.query(
      'INSERT INTO clientes (email, nome, senha_hash) VALUES ($1,$2,$3) RETURNING id',
      [email, nome || null, hash]);
    const token = novoToken();
    await pool.query('INSERT INTO sessoes (token, cliente_id) VALUES ($1,$2)', [token, rows[0].id]);
    res.json({ token, email, nome: nome || '' });
  } catch (e) {
    console.error('Erro em /api/registrar:', e);
    res.status(500).json({ erro: 'Erro interno ao registrar' });
  }
});

// ── Entrar ─────────────────────────────────────────────────
app.post('/api/login', async (req, res) => {
  if (!pool) return res.status(503).json({ erro: 'Banco de dados não configurado (DATABASE_URL ausente)' });
  let { email, senha } = req.body || {};
  email = String(email || '').trim().toLowerCase();
  if (!email || !senha) return res.status(400).json({ erro: 'Informe e-mail e senha' });
  try {
    const { rows } = await pool.query('SELECT id, nome, senha_hash FROM clientes WHERE email=$1', [email]);
    if (rows.length === 0) return res.status(404).json({ erro: 'E-mail não cadastrado — crie uma conta' });
    if (!(await verificaSenha(String(senha), rows[0].senha_hash)))
      return res.status(401).json({ erro: 'Senha incorreta' });
    const token = novoToken();
    await pool.query('INSERT INTO sessoes (token, cliente_id) VALUES ($1,$2)', [token, rows[0].id]);
    res.json({ token, email, nome: rows[0].nome || '' });
  } catch (e) {
    console.error('Erro em /api/login:', e);
    res.status(500).json({ erro: 'Erro interno ao entrar' });
  }
});

// ── Validar sessão existente (auto-login ao reabrir) ───────
app.post('/api/sessao', async (req, res) => {
  if (!pool) return res.status(503).json({ erro: 'Banco de dados não configurado (DATABASE_URL ausente)' });
  try {
    const cli = await clientePorToken((req.body || {}).token);
    if (!cli) return res.status(401).json({ erro: 'Sessão expirada — entre novamente' });
    res.json({ email: cli.email, nome: cli.nome || '' });
  } catch (e) {
    console.error('Erro em /api/sessao:', e);
    res.status(500).json({ erro: 'Erro interno' });
  }
});

// ── Sair ───────────────────────────────────────────────────
app.post('/api/logout', async (req, res) => {
  if (!pool) return res.json({ ok: true });
  try { await pool.query('DELETE FROM sessoes WHERE token=$1', [String((req.body || {}).token || '')]); } catch {}
  res.json({ ok: true });
});

// ── Salvar dados do planejador (requer sessão) ─────────────
app.post('/api/salvar', async (req, res) => {
  if (!pool) return res.status(503).json({ erro: 'Banco de dados não configurado (DATABASE_URL ausente)' });
  const { token, nome, campos = {}, tabelas = {} } = req.body || {};
  const cli = await clientePorToken(token).catch(() => null);
  if (!cli) return res.status(401).json({ erro: 'Sessão expirada — entre novamente' });
  const clienteId = cli.id;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('UPDATE clientes SET nome=COALESCE($2,nome), atualizado_em=now() WHERE id=$1',
      [clienteId, nome || null]);

    await client.query('DELETE FROM perfil_campos WHERE cliente_id=$1', [clienteId]);
    for (const [campo, valor] of Object.entries(campos))
      await client.query('INSERT INTO perfil_campos (cliente_id, campo, valor) VALUES ($1,$2,$3)',
        [clienteId, campo, String(valor ?? '')]);

    for (const [chave, cfg] of Object.entries(TABELAS)) {
      await client.query(`DELETE FROM ${cfg.tabela} WHERE cliente_id=$1`, [clienteId]);
      const linhas = Array.isArray(tabelas[chave]) ? tabelas[chave] : [];
      for (const vals of linhas) {
        const colVals = cfg.cols.map((_, i) =>
          cfg.num.includes(i) ? parseBR(vals[i]) : (vals[i] ?? null));
        const ph = cfg.cols.map((_, i) => '$' + (i + 2)).join(',');
        await client.query(
          `INSERT INTO ${cfg.tabela} (cliente_id, ${cfg.cols.join(',')}) VALUES ($1, ${ph})`,
          [clienteId, ...colVals]);
      }
    }

    await client.query('COMMIT');
    res.json({ ok: true });
  } catch (e) {
    await client.query('ROLLBACK');
    console.error('Erro em /api/salvar:', e);
    res.status(500).json({ erro: 'Erro interno ao salvar' });
  } finally {
    client.release();
  }
});

// ── Carregar: devolve o snapshot completo do cliente (requer sessão)
app.post('/api/carregar', async (req, res) => {
  if (!pool) return res.status(503).json({ erro: 'Banco de dados não configurado (DATABASE_URL ausente)' });
  const cli = await clientePorToken((req.body || {}).token).catch(() => null);
  if (!cli) return res.status(401).json({ erro: 'Sessão expirada — entre novamente' });
  const clienteId = cli.id;

  try {
    const campos = {};
    (await pool.query('SELECT campo, valor FROM perfil_campos WHERE cliente_id=$1', [clienteId]))
      .rows.forEach(({ campo, valor }) =>
        campos[campo] = valor === 'true' ? true : valor === 'false' ? false : valor);

    const tabelas = {};
    for (const [chave, cfg] of Object.entries(TABELAS)) {
      const { rows } = await pool.query(
        `SELECT ${cfg.cols.join(',')} FROM ${cfg.tabela} WHERE cliente_id=$1 ORDER BY id`,
        [clienteId]);
      tabelas[chave] = rows.map(row => cfg.cols.map(c => row[c] == null ? '' : String(row[c])));
    }

    res.json({ campos, tabelas });
  } catch (e) {
    console.error('Erro em /api/carregar:', e);
    res.status(500).json({ erro: 'Erro interno ao carregar' });
  }
});

// ── Boot: cria as tabelas (idempotente) e sobe o servidor
async function init() {
  if (pool) {
    const sql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
    await pool.query(sql);
    console.log('Banco de dados pronto (tabelas verificadas).');
  } else {
    console.warn('AVISO: DATABASE_URL não definida — servindo só o HTML, sem salvar dados.');
  }
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => console.log('Planejador no ar: http://localhost:' + PORT));
}
init().catch(e => { console.error('Falha ao iniciar:', e); process.exit(1); });
