# Sistema Personal de Inteligencia de Inversión — Diseño Técnico (v0.2)

> **Estado: PROPUESTA PARA APROBACIÓN.** Continúa a `00-diseno-sistema-inversion.md` (diseño financiero, v1.5, cerrado). Este documento traduce ese motor financiero a arquitectura, base de datos y contratos de integración. Todavía **no se ha desplegado nada**: es diseño y selección de herramientas para tu aprobación, no infraestructura corriendo. La sección 2 (APIs) y 10 (costos) ya incorporan una investigación de precios/cobertura vigentes con fuentes citadas; las cifras marcadas ⚠️ no se verificaron directamente en la página del proveedor y deben confirmarse antes de contratar.

---

## 0. Principio rector: separación cálculo/IA

Recordatorio del punto 37 del brief, porque gobierna todo lo que sigue: **todo lo que se pueda calcular determinísticamente (RSI, SMAs, ATR, retornos, drawdown, Risk/Reward, el Score ponderado completo) se calcula en código, no por Claude.** Claude recibe los resultados ya calculados y el contexto estructurado, y su trabajo es exclusivamente **interpretar, sintetizar, redactar tesis, clasificar catalizadores/noticias y emitir el JSON final** (sección 5). Esto reduce alucinaciones y hace el sistema auditable: cualquier número en una alerta debe poder rastrearse a una fórmula, no a una inferencia del modelo.

## 1. Arquitectura cloud

```
┌─────────────────────┐     ┌──────────────────────┐     ┌─────────────────────┐
│  Proveedor(es) de    │     │  Fuente de noticias   │     │   GBM (manual)       │
│  datos de mercado     │     │  financieras          │     │   — tú registras     │
│  (OHLCV, fundamentals,│     │                        │     │   tus operaciones    │
│  earnings, corp.      │     │                        │     │   reales aquí        │
│  actions)              │     │                        │     │                       │
└──────────┬───────────┘     └──────────┬────────────┘     └──────────┬───────────┘
           │                             │                              │
           └─────────────┬───────────────┘                              │
                          ▼                                              ▼
                ┌───────────────────────┐                    ┌────────────────────┐
                │   n8n Cloud            │◄───────────────────┤  Registro manual    │
                │   (orquestación 24/7)  │                    │  de transacciones    │
                └──────────┬────────────┘                    │  (tú, vía formulario │
                           │                                   │  o tabla directa)    │
        ┌──────────────────┼──────────────────┐               └────────────────────┘
        ▼                  ▼                   ▼
┌───────────────┐  ┌───────────────┐  ┌─────────────────┐
│ Preprocesa-    │  │ Motor de       │  │ Motor de riesgo   │
│ miento         │→│ scoring        │→│ (sizing, límites   │
│ determinista   │  │ determinista   │  │ de portafolio,     │
│ (indicadores,  │  │ (pesos section │  │ bandas Core/Sat.,  │
│ valuación, R/R)│  │ 4, código)     │  │ drawdown)          │
└───────────────┘  └───────────────┘  └─────────┬─────────┘
                                                   ▼
                                        ┌────────────────────┐
                                        │   Claude API         │
                                        │   (interpretación,   │
                                        │   tesis, catalizado-  │
                                        │   res, clasificación  │
                                        │   de noticias, JSON   │
                                        │   final — sección 5)  │
                                        └─────────┬──────────┘
                                                   ▼
                                        ┌────────────────────┐
                                        │  Supabase/Postgres    │
                                        │  (sección 3 — tablas   │
                                        │  fuente de verdad)     │
                                        └─────────┬──────────┘
                                                   ▼
                                        ┌────────────────────┐
                                        │  Motor de reglas de   │
                                        │  alerta (umbrales     │
                                        │  sección 6, dedupli-   │
                                        │  cación sección 8)    │
                                        └─────────┬──────────┘
                                                   ▼
                                        ┌────────────────────┐
                                        │      WhatsApp         │
                                        │  (solo si hay algo     │
                                        │  accionable)           │
                                        └────────────────────┘
```

Todo corre 24/7 en n8n Cloud + Supabase; nada depende de tu computadora ni de una sesión de Claude Code activa. Claude Code se usa únicamente para desarrollar, configurar, probar y desplegar los workflows y el esquema de base de datos — nunca para ejecutar el pipeline en producción.

## 2. Selección de APIs de datos de mercado

Investigación de cobertura/precios vigentes hecha el 2026-09-09, contrastando páginas oficiales de cada proveedor. **Varias cifras quedan marcadas explícitamente como no verificadas** — no se van a usar en el presupuesto final sin confirmarlas directamente en la página del proveedor, por la regla de no inventar precios (punto 52 del brief).

### Hallazgo clave: cobertura de BMV (acciones mexicanas)

De los seis proveedores evaluados (Financial Modeling Prep, Polygon.io/Massive, Twelve Data, Finnhub, Tiingo, Alpha Vantage), **solo Twelve Data confirma cobertura documentada de la Bolsa Mexicana de Valores** (símbolo de mercado `XMEX`, ej. GMEXICOB) — y solo **end-of-day** (no intradía), disponible desde su tier **Pro ($99/mo)** en adelante; no viene incluida en el tier de entrada. Los otros cinco no mencionan México en ningún lado de su documentación pública, o lo excluyen explícitamente (ej. FMP limita expansión internacional a Reino Unido/Canadá; Polygon/Massive se declara "100% cobertura de EE. UU." sin mención de México). Finnhub no pudo verificarse en este punto (su página de precios bloqueó el acceso automatizado) — queda pendiente de una revisión manual si se quiere considerar.

### Recomendación: proveedor único por fases, no multi-provider desde el día uno

Dado que (a) no hay ejecución automática — por lo tanto datos EOD son suficientes, no hace falta tiempo real — y (b) el universo por fases del diseño financiero (sección 5A) ya prioriza ETFs sobre acciones individuales mientras el capital es pequeño, la selección se alinea con esa misma progresión en vez de pagar por cobertura de México desde el primer peso invertido:

| Fase del portafolio (5A) | Proveedor | Plan | Qué cubre |
|---|---|---|---|
| **1. Cimientos** (ETFs + CETES, screening amplio de EE. UU.) | **Twelve Data** | "Grow" — **$29/mo** (verificado en su página oficial) | Acciones EE. UU. (accesibles vía SIC) y ETFs en tiempo real, fundamentals básicos, 27 mercados — sin México todavía, que no se necesita en esta fase |
| **2. Expansión** (se activa el screening de acciones individuales, incluyendo MX) | **Twelve Data** | Upgrade a **"Pro" — $99/mo** (verificado) | Añade BMV (`XMEX`, EOD) sobre la misma integración ya construida — no se reconstruye el pipeline, solo se activa el mercado adicional |
| **3. Madurez** (si la cobertura/profundidad de fundamentals de Twelve Data resulta insuficiente en la práctica) | + **Financial Modeling Prep "Starter"** (≈$29/mo, **cifra no verificada directamente en su página — bloqueó el acceso automatizado, confirmar antes de presupuestar**) como complemento | Fundamentals más profundos y noticias para EE. UU. | Proveedor secundario opcional, no obligatorio desde el inicio |

Este orden evita el error de sobre-construir infraestructura de datos para un portafolio que todavía no tiene posiciones individuales en México — coherente con el principio de la sección 5A de no comprometer capital/complejidad antes de que la fase lo justifique.

### Otros hallazgos relevantes

- **Financial Modeling Prep**: fuerte en fundamentals/estados financieros y noticias de EE. UU. desde su tier de entrada, pero **sin cobertura de México en ningún tier** y con su precio exacto (~$29/$69 según fuentes secundarias) pendiente de confirmar en la página oficial (bloqueó el fetch automatizado).
- **Polygon.io** (rebrandeado **Massive** desde oct-2025, misma API/keys): excelente para EE. UU. (incluye corporate actions desde el tier gratuito), sin México, $29/mo el tier pagado de entrada (verificado).
- **Finnhub, Tiingo, Alpha Vantage**: sin evidencia de cobertura de México; se descartan para esa función. Podrían evaluarse como alternativas de EE. UU. si Twelve Data no satisface en pruebas, pero no son prioridad ahora.
- Ningún proveedor de los seis, en los tiers accesibles para un usuario individual, ofrece un SLA contractual claro por debajo de sus tiers más caros (~$300+/mo) — se documenta como riesgo aceptado dado el uso personal, no institucional, del sistema.

Con esto, la sección 2 queda cerrada para efectos de diseño: **Twelve Data como proveedor primario, con upgrade de tier (no de proveedor) al pasar de Fase 1 a Fase 2**, y FMP como complemento opcional a evaluar en la Fase 3 si hace falta.

## 3. Base de datos (Supabase / PostgreSQL)

Esquema de las 13 tablas del punto 41 del brief, diseñado para reflejar las decisiones ya cerradas del diseño financiero (capital real vía ledger, tramos Core/Satélite, umbrales parametrizados, drawdown, backtesting). Tipos son orientativos (Postgres); se refinan en implementación.

### `system_config`
Parámetros del motor, versionados — nunca hardcodeados en el código del pipeline.
```
id                      uuid PK
config_key              text            -- ej. 'score_weights_v2', 'buy_thresholds_core', 'buy_thresholds_satellite',
                                         --     'allocation_bands', 'drawdown_limits', 'phase_position_limits'
config_value            jsonb           -- valor estructurado (ver ejemplos abajo)
version                 int
is_active               boolean
effective_from          timestamptz
created_at              timestamptz
notes                   text            -- por qué se cambió (ej. "recalibrado tras backtest #4")
```
Ejemplos de `config_value`:
- `buy_thresholds_satellite` → `{"score_min": 80, "confidence_min": 75, "risk_reward_min": 2.5, "allow_binary_event": false}`
- `allocation_bands` → `{"core_min": 60, "core_max": 70, "satellite_min": 20, "satellite_max": 30, "cash_min": 5, "cash_max": 15}`
- `drawdown_limits` → `{"soft_warning_pct": 15, "hard_limit_pct": 25, "status": "confirmado_v1"}`
- `position_limits` → `{"core_normal": [5,8], "core_high_conviction": 10, "satellite_normal": [2,4], "satellite_high_conviction": [5,6], "absolute_cap": 10}`

### `portfolio`
Estado actual de cada posición — derivado de `transactions`, no editado a mano.
```
id                      uuid PK
ticker                  text
market                  text            -- 'BMV', 'SIC', 'ETF', 'FIBRA', 'CETES', ...
sleeve                  text            -- 'core' | 'satellite'
quantity                numeric
average_cost            numeric
currency                text
opened_at               timestamptz
last_updated            timestamptz
thesis_id               uuid FK → investment_thesis
```

### `transactions`
**Fuente de verdad del efectivo disponible** (ledger). Todo cálculo de sizing (sección 15 del diseño financiero) lee de aquí.
```
id                      uuid PK
type                    text            -- 'contribution' | 'buy' | 'sell' | 'dividend' | 'withdrawal'
ticker                  text            -- null si es aportación/retiro de efectivo
quantity                numeric
price                   numeric
amount                  numeric         -- monto neto en efectivo del movimiento (+ o -)
fee                     numeric
currency                text
executed_at             timestamptz     -- cuándo lo ejecutaste tú en GBM
recorded_at             timestamptz     -- cuándo se registró en el sistema
notes                   text
```
El **efectivo disponible actual** = suma de `amount` de todas las transacciones. El **capital total** = efectivo disponible + Σ(quantity × precio de mercado actual) de `portfolio`. Ninguno de los dos se asume nunca; ambos se derivan de esta tabla en cada evaluación.

### `watchlist`
```
id                      uuid PK
ticker                  text
category                text            -- 'comprar_ahora' | 'cerca_de_compra' | 'esperar_correccion' |
                                         --   'esperar_breakout' | 'mantener_observacion' | 'descartar'
condition_to_change     text            -- condición explícita para cambiar de categoría (sección 25 del brief)
target_sleeve           text            -- 'core' | 'satellite' (a qué tramo aspira a entrar)
added_at                timestamptz
last_reviewed_at        timestamptz
```

### `market_snapshots`
Régimen de mercado y benchmarks permanentes (sección 9B del diseño financiero).
```
id                      uuid PK
snapshot_date           date
sp500                   numeric
nasdaq100               numeric
dow_jones               numeric
ipc                     numeric
vix                     numeric
treasury_10y            numeric
usdmxn                  numeric
dxy                     numeric
breadth_pct_above_200sma numeric        -- nullable, si el proveedor lo da
regime                  text            -- 'risk_on_fuerte' | 'risk_on_moderado' | 'neutral' |
                                         --   'risk_off_moderado' | 'risk_off_fuerte'
regime_notes            text
```

### `fundamentals`
```
id                      uuid PK
ticker                  text
period                  text            -- 'FY2025', 'Q2-2026', etc.
revenue                 numeric
revenue_growth_yoy      numeric
gross_margin            numeric
operating_margin        numeric
ebitda_margin           numeric
net_margin              numeric
roe                     numeric
roic                    numeric
roa                     numeric
fcf                     numeric
fcf_growth_yoy          numeric
net_debt_ebitda         numeric
interest_coverage       numeric
source                  text
retrieved_at            timestamptz
```

### `analysis`
Snapshot del análisis de las 4 lentes por evaluación (histórico, no se sobreescribe).
```
id                      uuid PK
ticker                  text
analyzed_at             timestamptz
business_quality        text            -- 'excepcional'..'débil'
valuation_class         text            -- 'amplio_margen'..'sobrevaluada'
technical_state         text
entry_quality           text
fair_value_low          numeric
fair_value_base         numeric
fair_value_high         numeric
scenario_bear           jsonb           -- {probability, price, downside, condition}
scenario_base           jsonb
scenario_bull           jsonb
expected_value          numeric
thesis_summary          text
bear_case               text
bull_case               text
risks                   jsonb           -- array de strings
catalysts               jsonb           -- array de {description, impact, probability, horizon}
```

### `signals`
Cada Score/Decisión emitido — es la tabla que alimenta el aprendizaje del sistema (sección 20 del diseño financiero / puntos 44-46 del brief).
```
id                      uuid PK
ticker                  text
sleeve                  text            -- 'core' | 'satellite'
generated_at            timestamptz
config_version          int             -- qué versión de system_config se usó (trazabilidad)
score                   numeric
confidence              numeric
decision                text            -- una de las 9 etiquetas fijas (punto 18 del brief)
entry_price_ref         numeric
buy_zone_1              jsonb
buy_zone_2              jsonb
invalidation            numeric
target_base             numeric
target_bull             numeric
risk_reward             numeric
suggested_weight        numeric
market_regime           text
raw_json                jsonb           -- el JSON completo emitido (sección 5)
-- columnas rellenadas después, para medir desempeño (sección 44 del brief):
return_1d               numeric
return_7d                numeric
return_30d               numeric
return_90d                numeric
mfe                     numeric         -- Maximum Favorable Excursion
mae                     numeric         -- Maximum Adverse Excursion
outcome_evaluated_at    timestamptz
```

### `alerts`
```
id                      uuid PK
signal_id               uuid FK → signals
ticker                  text
alert_type              text            -- catálogo de la sección 26/emoji del brief
priority                text            -- 'alta' | 'media' | 'baja'
sent_at                 timestamptz
channel                 text            -- 'whatsapp'
cooldown_until          timestamptz     -- deduplicación (sección 43 del brief)
last_state_hash         text            -- hash del estado (score+precio+tesis) para detectar cambios reales
delivered               boolean
```

### `news`
```
id                      uuid PK
ticker                  text            -- nullable si es macro/mercado general
headline                text
source                  text
published_at            timestamptz
classification          text            -- 'ruido' | 'relevante' | 'material' | 'cambia_tesis' (sección 15 del brief)
impact_summary          text            -- cómo afecta revenue/margins/EPS/FCF/valuación/riesgo/catalizadores
retrieved_at            timestamptz
```

### `investment_thesis`
```
id                      uuid PK
ticker                  text
sleeve                  text
opened_at               timestamptz
thesis_text             text
invalidation_criteria   text            -- el evento fundamental explícito, definido antes de comprar (sección 16)
technical_stop          numeric
status                  text            -- 'vigente' | 'invalidada' | 'cerrada_utilidad' | 'cerrada_perdida'
closed_at               timestamptz
closed_reason           text
```

### `performance`
Snapshot periódico del portafolio agregado.
```
id                      uuid PK
snapshot_date           date
total_value             numeric
cash_value              numeric
core_weight_pct         numeric
satellite_weight_pct    numeric
cash_weight_pct         numeric
drawdown_current_pct    numeric
return_since_inception  numeric
benchmark_sp500_return  numeric
benchmark_ipc_return    numeric
```

### `backtests`
```
id                      uuid PK
run_at                  timestamptz
config_version_tested   int
period_start            date
period_end              date
universe                text            -- qué universo se probó
win_rate                numeric
avg_win                 numeric
avg_loss                numeric
expectancy              numeric
profit_factor           numeric
max_drawdown            numeric
benchmark_return        numeric
costs_included          boolean
slippage_included       boolean
notes                   text
```

## 4. Contrato JSON de salida de Claude (sección 39 del brief, ampliado)

Claude recibe el paquete estructurado (indicadores ya calculados, fundamentals, valuación, régimen, posición actual si existe, umbrales vigentes de `system_config`) y devuelve **exclusivamente** este JSON — nunca prosa libre en el pipeline (la prosa/tesis vive dentro de los campos de texto del JSON):

```json
{
  "ticker": "",
  "company": "",
  "timestamp": "",
  "currency": "",
  "sleeve": "core | satellite",
  "config_version": 0,
  "has_position": false,
  "current_price": 0,
  "average_cost": null,
  "portfolio_weight": null,
  "market_regime": "",
  "score": 0,
  "score_breakdown": {
    "business_quality": 0, "growth": 0, "valuation": 0,
    "financial_strength": 0, "momentum_technical": 0,
    "catalysts": 0, "risk_reward": 0, "risk_margin_of_safety": 0
  },
  "decision": "",
  "signal": "",
  "confidence": 0,
  "confidence_reasons": [],
  "business_quality": "",
  "fundamental_trend": "",
  "valuation": "",
  "technical_state": "",
  "entry_quality": "",
  "fair_value_low": 0,
  "fair_value_base": 0,
  "fair_value_high": 0,
  "buy_zone_1": { "min": 0, "max": 0 },
  "buy_zone_2": { "min": 0, "max": 0 },
  "max_entry": 0,
  "invalidation": 0,
  "invalidation_type": "fundamental | tecnica | ambas",
  "stop": 0,
  "target_base": 0,
  "target_bull": 0,
  "upside_base": 0,
  "downside": 0,
  "risk_reward": 0,
  "suggested_weight": 0,
  "suggested_weight_capped_by": "riesgo_operacion | concentracion_fase | efectivo_disponible",
  "catalysts": [],
  "risks": [],
  "binary_event_pending": false,
  "binary_event_covered_by_thesis": null,
  "thesis": "",
  "bear_case": "",
  "base_case": "",
  "bull_case": "",
  "expected_value": 0,
  "do_not_chase": false,
  "alert": false,
  "alert_type": "",
  "alert_priority": "",
  "alert_reason": ""
}
```

Añadidos sobre el schema original del brief, todos trazables a decisiones ya cerradas del diseño financiero: `sleeve` y `config_version` (para aplicar los umbrales correctos y poder auditar qué parámetros se usaron), `score_breakdown` (transparencia del cálculo determinista), `suggested_weight_capped_by` (cuál de los tres límites de sizing, sección 15, fue el vinculante), `invalidation_type`, `binary_event_pending`/`binary_event_covered_by_thesis` (regla dura del satélite, sección 6), `expected_value` y `do_not_chase` (secciones 17 y 14 del diseño financiero).

## 5. Motor de reglas de alerta

No es Claude quien decide si se manda una alerta — es una capa de reglas cuantitativas que consume el JSON de la sección 4 y lo contrasta contra `system_config`, siguiendo el punto 40 del brief:

```
señal_de_compra_valida =
    score >= umbral_score[sleeve]
    AND confidence >= umbral_confidence[sleeve]
    AND risk_reward >= umbral_rr[sleeve]
    AND NOT fundamental_deterioration_detected
    AND (NOT binary_event_pending OR binary_event_covered_by_thesis)
    AND do_not_chase == false
    AND entry_price WITHIN buy_zone_1 OR buy_zone_2
```

Solo si `señal_de_compra_valida` (o el equivalente para venta/reducción/aumento, con sus propios criterios de la sección 7 del diseño financiero) se evalúa la deduplicación (`alerts.cooldown_until`, `last_state_hash`) antes de enviar por WhatsApp. Esto es exactamente la combinación "reglas cuantitativas + interpretación de Claude" del punto 40 del brief: Claude decide *qué tan buena* es la oportunidad (Score, tesis, catalizadores), el motor de reglas decide *si eso ya cruzó la barra* para molestarte con una notificación.

## 6. Flujo n8n (diseño de workflow, alto nivel)

Workflows separados, no uno monolítico:

1. **`ingest-market-data`** (cron diario/intradía según proveedor): llama API(s) de datos → normaliza → escribe en `market_snapshots`/`fundamentals`.
2. **`ingest-news`** (cron más frecuente, ej. cada 1-4h): llama fuente de noticias → filtra por ticker relevante (watchlist + portfolio) → escribe en `news` (clasificación la hace Claude en el siguiente paso, no este ingest).
3. **`compute-regime`** (tras ingest-market-data): calcula régimen (reglas deterministas sobre los 5 benchmarks + complementarios) → actualiza `market_snapshots.regime`.
4. **`screen-universe`** (cron diario): aplica el filtro cuantitativo (sección 9 del diseño financiero) sobre el universo (9A) → produce lista corta de candidatos.
5. **`analyze-candidate`** (por cada candidato de (4), o por cada ticker en `portfolio`/`watchlist` en revisión periódica): calcula indicadores/valuación/R-R en código (nodo Function/Code) → arma el paquete estructurado → llama Claude API → valida el JSON recibido contra el schema (sección 4) → escribe en `analysis` y `signals`.
6. **`apply-alert-rules`** (tras cada `analyze-candidate`): evalúa el motor de reglas (sección 5) → si aplica y no está en cooldown → escribe en `alerts` → envía WhatsApp.
7. **`score-outcomes`** (cron diario, opera sobre `signals` con antigüedad ≥1D/7D/30D/90D pendientes de evaluar): calcula retornos/MFE/MAE reales → actualiza `signals`.
8. **`compute-performance`** (cron diario): recalcula `performance` a partir de `portfolio` + `transactions` + precios actuales.

Cada workflow usa n8n Credentials para las API keys (nunca hardcodeadas en el JSON del workflow) — sección 9.

## 7. Integración Claude API

- El nodo que llama a Claude en `analyze-candidate` **no le pide a Claude que calcule nada matemático**: el paquete estructurado ya trae RSI, SMAs, ATR, márgenes, múltiplos, DCF simplificado, Risk/Reward, todo calculado por código previo en el mismo workflow.
- El prompt del sistema fija el rol (CIO/analista, sección 1-1.1 del diseño financiero), las reglas absolutas (punto 52 del brief: no prometer ganancias, no inventar datos, separar datos de interpretación) y exige la salida **estrictamente** en el JSON de la sección 4 (se usa structured output / tool use de la API de Claude, no parsing de texto libre, para evitar errores de formato).
- Cualquier campo que Claude no pueda sustentar con el paquete recibido reduce `confidence`, nunca se rellena con un valor inventado — validado en el propio prompt y, como segunda capa, con una validación de esquema en n8n antes de escribir en `signals`.

## 8. WhatsApp

Plantilla ejecutiva (punto 42 del brief) generada a partir de los campos del JSON (sección 4), enviada solo si `apply-alert-rules` (sección 5/6) lo determina. Proveedor final (Meta Cloud API directo vs. Twilio) pendiente de la comparación de costo/complejidad de configuración (sección 10).

## 9. Seguridad

API keys de datos de mercado, Claude, WhatsApp y credenciales de Supabase viven en **n8n Credentials** y en **Supabase Secrets/variables de entorno**, nunca en el código de los workflows ni en este repositorio. Este repositorio, si llega a incluir código de despliegue, usa `.env.example` sin valores reales (punto 49 del brief).

## 10. Costos (MVP / Recomendado / Profesional)

Investigación de precios hecha el 2026-09-09 contra las páginas oficiales de cada proveedor. **Cifras marcadas ⚠️ no se confirmaron directamente en la página del proveedor** (bloqueó el acceso automatizado o solo hay fuentes secundarias) — verificarlas antes de comprometer presupuesto. El costo de **Claude API es variable, por uso** (tokens procesados), no una cuota fija — con el volumen de un portafolio personal (decenas de tickers analizados periódicamente, no miles) se espera del orden de unos pocos dólares/mes, pero no se estima una cifra exacta sin medir el uso real en pruebas (paso 5 del roadmap, sección 11). Todos los precios de proveedores están en USD salvo que se indique lo contrario; conviene convertir a MXN con el tipo de cambio vigente al momento de contratar, no con uno fijo en este documento.

### Nivel 1 — MVP (Fase 1 del portafolio: "Cimientos", solo ETFs/CETES)

| Componente | Proveedor / plan | Costo mensual | Fuente |
|---|---|---|---|
| Datos de mercado | Twelve Data "Grow" | **$29 USD** | Verificado, página oficial |
| Base de datos | Supabase Free | **$0** | Verificado, página oficial |
| Automatización | n8n Cloud "Starter" | **€20 ≈ $22 USD** | Verificado, página oficial (confirmar tipo de cambio/moneda de cobro al contratar) |
| WhatsApp | Meta Cloud API directo | **~$0-5 USD** (mensajes utility/servicio mayormente gratuitos dentro de ventana de 24h; volumen bajo esperado) | ⚠️ Tarifa exacta MX no verificada — Meta publica su tarifario como CSV/PDF descargable, revisar en WhatsApp Manager al dar de alta la cuenta |
| Claude API | Pago por uso | **~$5-15 USD** (estimado, a medir) | No verificable sin uso real |
| **Total aproximado** | | **≈ $61-71 USD/mes** | |

### Nivel 2 — Recomendado (Fase 2: "Expansión", incluye acciones MX individuales)

| Componente | Proveedor / plan | Costo mensual | Fuente |
|---|---|---|---|
| Datos de mercado | Twelve Data "Pro" (upgrade, añade BMV EOD) | **$99 USD** | Verificado, página oficial |
| Base de datos | Supabase "Pro" (sin auto-pausa, backups diarios) | **$25 USD** base + uso | Verificado, página oficial |
| Automatización | n8n Cloud "Starter" o "Pro" según volumen de ejecuciones | **€20-50 ≈ $22-55 USD** | Verificado, página oficial |
| WhatsApp | Meta Cloud API directo | **~$5-10 USD** | ⚠️ Tarifa MX exacta no verificada |
| Claude API | Pago por uso (mayor volumen de tickers analizados) | **~$15-30 USD** (estimado) | No verificable sin uso real |
| **Total aproximado** | | **≈ $166-219 USD/mes** | |

### Nivel 3 — Profesional (Fase 3: portafolio maduro, mayor profundidad de datos)

| Componente | Proveedor / plan | Costo mensual | Fuente |
|---|---|---|---|
| Datos de mercado | Twelve Data "Pro" + FMP "Starter" (complemento fundamentals/news EE. UU.) | **$99 + ⚠️~$29 USD** (FMP no verificado directamente) | Parcialmente verificado |
| Base de datos | Supabase "Pro" con mayor uso (egress/storage adicional) | **$25 USD** base + overages (variable) | Verificado el base, overages estimados |
| Automatización | n8n Cloud "Pro" | **€50 ≈ $55 USD** | Verificado |
| WhatsApp | Meta Cloud API directo (mayor volumen de alertas) | **~$10-20 USD** | ⚠️ Tarifa MX exacta no verificada |
| Claude API | Pago por uso (mayor volumen + análisis más frecuente) | **~$30-60 USD** (estimado) | No verificable sin uso real |
| **Total aproximado** | | **≈ $248-288 USD/mes** | |

### Notas sobre WhatsApp: Meta directo vs. Twilio

Se recomienda **Meta Cloud API directo** sobre Twilio para este caso: Twilio cobra una tarifa propia adicional confirmada de **$0.005 USD/mensaje** por encima de la tarifa base de Meta (verificado en la página oficial de Twilio), que para un uso personal de bajo volumen no compensa la comodidad de configuración adicional que ofrece — la verificación de Meta Business y aprobación de plantillas hay que hacerlas de todos modos incluso usando Twilio, porque Twilio no elimina ese requisito, solo lo envuelve. Si en la práctica la configuración directa con Meta resulta más complicada de lo esperado, Twilio queda como alternativa de respaldo con configuración más guiada.

### Qué falta verificar antes de comprometer presupuesto real

1. Precio exacto vigente de Financial Modeling Prep (su página de precios bloqueó el acceso automatizado dos veces).
2. Tarifa exacta de Meta WhatsApp Cloud API para mensajes a números en México (solo se pudo confirmar el orden de magnitud — sub-$0.05 USD/mensaje — no la cifra exacta).
3. Costo real de Claude API una vez medido con uso real en la fase de pruebas (paso 5 del roadmap).
4. Moneda/tipo de cambio de cobro efectivo de n8n Cloud (cotiza en euros).

## 11. Roadmap de implementación (retomando el punto 50 del brief, pasos 8-16)

1. ~~Motor financiero (filosofía, scoring, riesgo, alertas)~~ → cerrado en `00-diseno-sistema-inversion.md`.
2. Cerrar selección de APIs de datos (sección 2, pendiente de investigación).
3. Aprobar el esquema de base de datos (sección 3) y crearlo en Supabase.
4. Construir los workflows de n8n (sección 6), empezando por `ingest-market-data` + `compute-regime` (sin Claude ni WhatsApp todavía, para validar datos crudos).
5. Integrar Claude API (`analyze-candidate`) con el contrato de la sección 4, probando contra 3-5 tickers conocidos antes de escalar al universo completo.
6. Integrar el motor de reglas de alerta (sección 5) y WhatsApp (sección 8), con pruebas usando tu propio número antes de dejarlo corriendo solo.
7. Correr el sistema en modo "solo señales, sin decisiones de peso" por un periodo de prueba, comparando contra tu propio juicio manual.
8. Backtesting con datos históricos (sección 20 del diseño financiero / puntos 45-46 del brief) antes de darle peso real a las señales.
9. Dashboard (sección 47 del brief) — última etapa, una vez que hay histórico real que mostrar.

No se empieza el paso 4 antes de tener aprobados los pasos 2 y 3.
