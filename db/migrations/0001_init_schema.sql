-- Sistema Personal de Inteligencia de Inversión — esquema inicial
-- Corresponde a la sección 3 de docs/01-diseno-tecnico.md.
-- Vocabularios cerrados (CHECK constraints) están tomados literalmente del brief
-- financiero (docs/00-diseno-sistema-inversion.md) — no son un criterio nuevo.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- system_config: parámetros del motor, versionados. Nunca hardcodear estos
-- valores en el código del pipeline (n8n/Claude) — siempre leerlos de aquí.
-- ---------------------------------------------------------------------------
create table system_config (
    id              uuid primary key default gen_random_uuid(),
    config_key      text not null,
    config_value    jsonb not null,
    version         int not null default 1,
    is_active       boolean not null default true,
    effective_from  timestamptz not null default now(),
    created_at      timestamptz not null default now(),
    notes           text,
    unique (config_key, version)
);

-- Regla dura: nunca puede haber dos versiones activas del mismo parámetro a
-- la vez (evita que el pipeline lea valores ambiguos si alguien olvida
-- desactivar la versión anterior al recalibrar — ver db/README.md).
create unique index idx_system_config_one_active_per_key on system_config (config_key) where is_active;

-- ---------------------------------------------------------------------------
-- investment_thesis: tesis escrita antes de comprar, con invalidación explícita.
-- ---------------------------------------------------------------------------
create table investment_thesis (
    id                      uuid primary key default gen_random_uuid(),
    ticker                  text not null,
    sleeve                  text not null check (sleeve in ('core', 'satellite')),
    opened_at               timestamptz not null default now(),
    thesis_text             text not null,
    invalidation_criteria   text not null,
    technical_stop          numeric,
    status                  text not null default 'vigente'
                                check (status in ('vigente', 'invalidada', 'cerrada_utilidad', 'cerrada_perdida')),
    closed_at               timestamptz,
    closed_reason           text
);

create index idx_thesis_ticker on investment_thesis (ticker);
create index idx_thesis_status on investment_thesis (status);

-- ---------------------------------------------------------------------------
-- portfolio: estado actual de cada posición. Se recalcula desde `transactions`,
-- no se edita a mano (evita que quede desincronizado del efectivo real).
-- ---------------------------------------------------------------------------
create table portfolio (
    id              uuid primary key default gen_random_uuid(),
    ticker          text not null,
    market          text not null check (market in ('BMV', 'SIC', 'ETF', 'FIBRA', 'CETES')),
    sleeve          text not null check (sleeve in ('core', 'satellite')),
    quantity        numeric not null check (quantity >= 0),
    average_cost    numeric not null check (average_cost >= 0),
    currency        text not null,
    opened_at       timestamptz not null default now(),
    last_updated    timestamptz not null default now(),
    thesis_id       uuid references investment_thesis (id),
    unique (ticker, market)
);

-- ---------------------------------------------------------------------------
-- transactions: LEDGER — fuente de verdad del efectivo disponible.
-- efectivo_disponible = sum(amount); capital_total = efectivo_disponible +
-- sum(quantity * precio_actual) sobre `portfolio`. Nunca se asume ninguno de
-- los dos: todo cálculo de sizing lee de aquí (sección 15 del diseño financiero).
-- ---------------------------------------------------------------------------
create table transactions (
    id              uuid primary key default gen_random_uuid(),
    type            text not null check (type in ('contribution', 'buy', 'sell', 'dividend', 'withdrawal')),
    ticker          text,
    quantity        numeric,
    price           numeric,
    amount          numeric not null,
    fee             numeric not null default 0,
    currency        text not null,
    executed_at     timestamptz not null,
    recorded_at     timestamptz not null default now(),
    notes           text
);

create index idx_transactions_ticker on transactions (ticker);
create index idx_transactions_executed_at on transactions (executed_at);

-- ---------------------------------------------------------------------------
-- watchlist
-- ---------------------------------------------------------------------------
create table watchlist (
    id                      uuid primary key default gen_random_uuid(),
    ticker                  text not null unique,
    category                text not null check (category in (
        'COMPRAR AHORA', 'CERCA DE COMPRA', 'ESPERAR CORRECCIÓN',
        'ESPERAR BREAKOUT', 'MANTENER EN OBSERVACIÓN', 'DESCARTAR'
    )),
    condition_to_change     text not null,
    target_sleeve           text check (target_sleeve in ('core', 'satellite')),
    added_at                timestamptz not null default now(),
    last_reviewed_at        timestamptz
);

-- ---------------------------------------------------------------------------
-- market_snapshots: régimen de mercado y benchmarks permanentes (sección 9B).
-- ---------------------------------------------------------------------------
create table market_snapshots (
    id                          uuid primary key default gen_random_uuid(),
    snapshot_date               date not null unique,
    sp500                       numeric,
    nasdaq100                   numeric,
    dow_jones                   numeric,
    ipc                         numeric,
    vix                         numeric,
    treasury_10y                numeric,
    usdmxn                      numeric,
    dxy                         numeric,
    breadth_pct_above_200sma    numeric,
    regime                      text check (regime in (
        'risk_on_fuerte', 'risk_on_moderado', 'neutral', 'risk_off_moderado', 'risk_off_fuerte'
    )),
    regime_notes                text
);

-- ---------------------------------------------------------------------------
-- fundamentals
-- ---------------------------------------------------------------------------
create table fundamentals (
    id                  uuid primary key default gen_random_uuid(),
    ticker              text not null,
    period              text not null,
    revenue             numeric,
    revenue_growth_yoy  numeric,
    gross_margin        numeric,
    operating_margin    numeric,
    ebitda_margin       numeric,
    net_margin          numeric,
    roe                 numeric,
    roic                numeric,
    roa                 numeric,
    fcf                 numeric,
    fcf_growth_yoy      numeric,
    net_debt_ebitda     numeric,
    interest_coverage   numeric,
    source              text not null,
    retrieved_at        timestamptz not null default now(),
    unique (ticker, period, source)
);

create index idx_fundamentals_ticker on fundamentals (ticker);

-- ---------------------------------------------------------------------------
-- analysis: snapshot histórico del análisis de las 4 lentes (no se sobreescribe).
-- ---------------------------------------------------------------------------
create table analysis (
    id                  uuid primary key default gen_random_uuid(),
    ticker              text not null,
    analyzed_at         timestamptz not null default now(),
    business_quality    text check (business_quality in ('EXCEPCIONAL', 'MUY BUENA', 'BUENA', 'PROMEDIO', 'DÉBIL')),
    valuation_class      text check (valuation_class in (
        'AMPLIO MARGEN DE SEGURIDAD', 'MARGEN ATRACTIVO', 'MARGEN MODERADO', 'SIN MARGEN', 'SOBREVALUADA'
    )),
    technical_state      text,
    entry_quality        text check (entry_quality in (
        'EXCEPCIONAL', 'MUY ATRACTIVA', 'ATRACTIVA', 'ACEPTABLE', 'MALA', 'MUY MALA'
    )),
    fair_value_low       numeric,
    fair_value_base      numeric,
    fair_value_high      numeric,
    scenario_bear         jsonb,
    scenario_base         jsonb,
    scenario_bull         jsonb,
    expected_value        numeric,
    thesis_summary        text,
    bear_case             text,
    bull_case              text,
    risks                 jsonb,
    catalysts             jsonb
);

create index idx_analysis_ticker on analysis (ticker, analyzed_at desc);

-- ---------------------------------------------------------------------------
-- signals: cada Score/Decisión emitido. Tabla base del aprendizaje del sistema.
-- ---------------------------------------------------------------------------
create table signals (
    id                  uuid primary key default gen_random_uuid(),
    ticker              text not null,
    sleeve              text not null check (sleeve in ('core', 'satellite')),
    generated_at        timestamptz not null default now(),
    config_version      int not null,
    score               numeric not null check (score between 0 and 100),
    confidence          numeric not null check (confidence between 0 and 100),
    decision            text not null check (decision in (
        'COMPRA FUERTE', 'COMPRA', 'COMPRA PARCIAL', 'ESPERAR', 'MANTENER',
        'AUMENTAR POSICIÓN', 'REDUCIR', 'TOMAR UTILIDADES', 'VENDER', 'VENDER TOTALMENTE'
    )),
    entry_price_ref     numeric,
    buy_zone_1          jsonb,
    buy_zone_2          jsonb,
    invalidation        numeric,
    target_base         numeric,
    target_bull         numeric,
    risk_reward         numeric,
    suggested_weight    numeric,
    market_regime       text,
    raw_json            jsonb not null,
    return_1d           numeric,
    return_7d           numeric,
    return_30d          numeric,
    return_90d          numeric,
    mfe                 numeric,
    mae                 numeric,
    outcome_evaluated_at timestamptz
);

create index idx_signals_ticker on signals (ticker, generated_at desc);
create index idx_signals_pending_outcome on signals (generated_at) where outcome_evaluated_at is null;

-- ---------------------------------------------------------------------------
-- alerts
-- ---------------------------------------------------------------------------
create table alerts (
    id                  uuid primary key default gen_random_uuid(),
    signal_id           uuid not null references signals (id),
    ticker              text not null,
    alert_type          text not null, -- catálogo libre (sección 26 del brief); ver comentario abajo
    priority            text not null check (priority in ('alta', 'media', 'baja')),
    sent_at             timestamptz,
    channel             text not null default 'whatsapp',
    cooldown_until       timestamptz,
    last_state_hash      text,
    delivered            boolean not null default false
);

comment on column alerts.alert_type is
    'Catálogo de referencia (sección 26 del brief), no forzado por CHECK porque puede ampliarse: '
    'ENTRO_ZONA_COMPRA, BREAKOUT_CONFIRMADO, VALUACION_ATRACTIVA, CERCA_DE_ZONA, EARNINGS_PROXIMO, '
    'OBJETIVO_ALCANZADO, TOMA_DE_UTILIDADES, INVALIDACION, STOP, DETERIORO_FUNDAMENTAL, NOTICIA_MATERIAL.';

create index idx_alerts_ticker_cooldown on alerts (ticker, cooldown_until);

-- ---------------------------------------------------------------------------
-- news
-- ---------------------------------------------------------------------------
create table news (
    id                  uuid primary key default gen_random_uuid(),
    ticker              text,
    headline            text not null,
    source              text not null,
    published_at        timestamptz not null,
    classification       text check (classification in (
        'RUIDO', 'NOTICIA RELEVANTE', 'NOTICIA MATERIAL', 'EVENTO QUE CAMBIA LA TESIS'
    )),
    impact_summary       text,
    retrieved_at         timestamptz not null default now()
);

create index idx_news_ticker on news (ticker, published_at desc);

-- ---------------------------------------------------------------------------
-- performance: snapshot periódico del portafolio agregado.
-- ---------------------------------------------------------------------------
create table performance (
    id                      uuid primary key default gen_random_uuid(),
    snapshot_date           date not null unique,
    total_value             numeric not null,
    cash_value              numeric not null,
    core_weight_pct         numeric,
    satellite_weight_pct    numeric,
    cash_weight_pct         numeric,
    drawdown_current_pct    numeric,
    return_since_inception  numeric,
    benchmark_sp500_return  numeric,
    benchmark_ipc_return    numeric
);

-- ---------------------------------------------------------------------------
-- backtests
-- ---------------------------------------------------------------------------
create table backtests (
    id                      uuid primary key default gen_random_uuid(),
    run_at                  timestamptz not null default now(),
    config_version_tested   int not null,
    period_start            date not null,
    period_end              date not null,
    universe                text not null,
    win_rate                numeric,
    avg_win                 numeric,
    avg_loss                numeric,
    expectancy              numeric,
    profit_factor           numeric,
    max_drawdown            numeric,
    benchmark_return        numeric,
    costs_included           boolean not null default true,
    slippage_included        boolean not null default true,
    notes                    text
);

-- ---------------------------------------------------------------------------
-- Row Level Security: habilitada en todas las tablas, sin políticas todavía.
-- Efecto: la `service_role key` (la que usa n8n — sección 9 del diseño
-- técnico) sigue teniendo acceso total, porque ese rol siempre ignora RLS en
-- Supabase. La clave `anon`/`authenticated` (la que usaría un futuro
-- frontend/dashboard) queda sin ningún acceso hasta que se definan políticas
-- explícitas — correcto para esta etapa, donde el único cliente es el
-- pipeline, no hay dashboard público todavía (sección 47 del brief).
-- ---------------------------------------------------------------------------
alter table system_config enable row level security;
alter table investment_thesis enable row level security;
alter table portfolio enable row level security;
alter table transactions enable row level security;
alter table watchlist enable row level security;
alter table market_snapshots enable row level security;
alter table fundamentals enable row level security;
alter table analysis enable row level security;
alter table signals enable row level security;
alter table alerts enable row level security;
alter table news enable row level security;
alter table performance enable row level security;
alter table backtests enable row level security;
