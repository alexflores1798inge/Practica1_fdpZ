-- Valores iniciales de system_config, tomados directamente de las decisiones
-- ya cerradas en docs/00-diseno-sistema-inversion.md (v1.5). Son punto de
-- partida razonado, no definitivo: se recalibran con backtesting (sección 20).
-- Insertar solo una vez (al desplegar por primera vez) — actualizaciones
-- posteriores deben ir como nueva fila con version incrementada, nunca UPDATE
-- sobre una fila activa, para conservar el historial de calibración.

insert into system_config (config_key, config_value, version, is_active, notes) values

('score_weights', '{
    "business_quality": 20,
    "growth": 15,
    "valuation": 15,
    "financial_strength": 10,
    "momentum_technical": 15,
    "catalysts": 10,
    "risk_reward": 10,
    "risk_margin_of_safety": 5
}'::jsonb, 1, true, 'Ponderación v2, perfil agresivo con control de riesgo — diseño financiero sección 4'),

('buy_thresholds_core', '{
    "score_min": 75,
    "confidence_min": 70,
    "risk_reward_min": 2.0,
    "allow_binary_event_if_covered_by_thesis": true
}'::jsonb, 1, true, 'Umbral de compra tramo Core — diseño financiero sección 6'),

('buy_thresholds_satellite', '{
    "score_min": 80,
    "confidence_min": 75,
    "risk_reward_min": 2.5,
    "allow_binary_event_if_covered_by_thesis": false
}'::jsonb, 1, true, 'Umbral de compra tramo Satélite/Táctico, más exigente que Core — diseño financiero sección 6'),

('allocation_bands', '{
    "core_min_pct": 60,
    "core_max_pct": 70,
    "satellite_min_pct": 20,
    "satellite_max_pct": 30,
    "cash_min_pct": 5,
    "cash_max_pct": 15
}'::jsonb, 1, true, 'Bandas dinámicas Core/Satélite/Liquidez — diseño financiero sección 5B'),

('drawdown_limits', '{
    "soft_warning_pct": 15,
    "hard_limit_pct": 25
}'::jsonb, 1, true, 'Confirmado vía cuestionario de tolerancia al riesgo — diseño financiero sección 5 punto 5 y 1.1'),

('position_limits', '{
    "core_normal_pct": [5, 8],
    "core_high_conviction_pct": 10,
    "satellite_normal_pct": [2, 4],
    "satellite_high_conviction_pct": [5, 6],
    "absolute_cap_pct": 10
}'::jsonb, 1, true, 'Límites por posición individual, por tramo — diseño financiero sección 5A'),

('instrument_universe', '{
    "markets": ["BMV", "SIC", "ETF", "FIBRA", "CETES"],
    "index_tracking_etfs": ["S&P 500", "Nasdaq 100", "Dow Jones"]
}'::jsonb, 1, true, 'Universo de instrumentos confirmado — diseño financiero sección 9A'),

('regime_benchmarks', '{
    "permanent": ["SP500", "NASDAQ100", "DOWJONES", "IPC", "VIX"]
}'::jsonb, 1, true, 'Benchmarks de régimen monitoreados siempre — diseño financiero sección 9B'),

('portfolio_build_phase', '{
    "current_phase": 1,
    "phase_1_label": "Cimientos",
    "phase_2_label": "Expansión",
    "phase_3_label": "Madurez"
}'::jsonb, 1, true, 'Fase actual de construcción del portafolio — diseño financiero sección 5A. Se actualiza a mano conforme crece el capital.');
