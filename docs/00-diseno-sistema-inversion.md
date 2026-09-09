# Sistema Personal de Inteligencia de Inversión — Diseño Financiero (v1.1)

> **Estado: PROPUESTA PARA APROBACIÓN.** No se ha construido infraestructura ni automatización todavía. Este documento define el motor financiero — filosofía, reglas, scoring, riesgo — que la tecnología (n8n, Claude API, base de datos, WhatsApp) ejecutará más adelante. Nada de esto se conecta a GBM ni ejecuta operaciones: toda decisión de compra/venta la ejecutas tú manualmente.

---

## 1. Filosofía de inversión propuesta

**Calidad razonable a precio razonable, con paciencia y gestión activa de riesgo.** El objetivo no es maximizar operaciones ni predecir el mercado a corto plazo; es maximizar el crecimiento compuesto de tu patrimonio a largo plazo, aceptando riesgo solo cuando el rendimiento potencial lo justifica claramente.

Principios rectores:

1. **El precio y el valor son cosas distintas.** Compramos cuando el precio ofrece margen de seguridad frente al valor estimado; no perseguimos precio solo porque "está subiendo".
2. **La tesis manda, no la emoción.** Cada posición tiene una tesis escrita, explícita, con condiciones de invalidación definidas *antes* de comprar.
3. **El riesgo se gestiona, no se evita.** Buscamos asimetrías (upside > downside) en vez de evitar todo riesgo o asumir cualquier riesgo por FOMO.
4. **Efectivo y renta fija (CETES) son posiciones activas**, no un residuo. Si no hay oportunidad con margen de seguridad y risk/reward atractivo, la decisión correcta es esperar.
5. **Ningún dato aislado decide nada.** Ninguna señal técnica, múltiplo o noticia individual genera una decisión; la decisión emerge de la convergencia de evidencia fundamental, técnica, macro y de valuación.
6. **El sistema debe ser auditable.** Toda señal queda registrada con su resultado real, para poder medir honestamente si el proceso agrega valor.

## 1.1 Perfil de inversión registrado (actualizado)

- **Capital total**: no definido ni fijo — se está construyendo desde cero mediante aportaciones periódicas. El sistema **nunca asume un patrimonio objetivo**; toda referencia a "capital" en este documento significa el efectivo disponible registrado más el valor de mercado de las posiciones existentes, ambos leídos de tu registro real, no proyectados.
- **Aportaciones**: periódicas (monto/frecuencia a registrar conforme las hagas). Cada aportación dispara una re-evaluación de asignación (ver sección 5C).
- **Horizonte**: principal a largo plazo (~10 años) — este es el horizonte que gobierna el grueso del portafolio (núcleo/*core*). De forma secundaria, se aprovechan oportunidades de mediano plazo cuando el risk/reward es claramente atractivo (satélite/táctico) — ver sección 5B.
- **Tolerancia al riesgo**: disciplinada; prioridad explícita en evitar concentraciones excesivas, sobre todo mientras el portafolio es pequeño y cada posición pesa proporcionalmente más (ver sección 5A).
- **Necesidad de liquidez**: no inmediata (horizonte largo), pero se mantiene siempre un piso de efectivo/CETES para poder aprovechar correcciones sin vender posiciones existentes.
- **Portafolio actual, precio promedio, exposición sectorial/país/moneda, % en efectivo**: aún no registrados — se derivan automáticamente del registro de transacciones/efectivo conforme empieces a operar, nunca se asumen.

Este perfil reemplaza los supuestos placeholder usados en la v1.0 de este documento; los límites numéricos de las secciones 5 y 15 se actualizan a continuación para operar sobre capital real, no sobre un patrimonio objetivo.

## 2. Cómo tomarás decisiones

Proceso en cascada, cada etapa puede detener el análisis (si el régimen macro es muy adverso, no se buscan compras nuevas aunque el screening arroje candidatos):

```
Régimen de mercado (macro + breadth + volatilidad)
        ↓ ¿favorable o neutral para desplegar capital?
Rotación sectorial (dónde hay viento a favor / en contra)
        ↓
Screening cuantitativo (filtra universo por calidad+valuación+momentum)
        ↓
Análisis profundo (fundamental + técnico + valuación + catalizadores) de candidatos
        ↓
Scoring 0-100 + Confidence 0-100
        ↓
Risk/Reward + Position Sizing + contraste vs. CETES/ETF (costo de oportunidad)
        ↓
Decisión (una de las 9 etiquetas fijas, sección 18 del brief) + Alerta si aplica
```

Cada decisión se emite con la evidencia que la sustenta (no solo la conclusión), para que tú puedas auditar el razonamiento antes de ejecutar en GBM.

## 3. Framework financiero

Cuatro lentes obligatorias, siempre combinadas:

| Lente | Responde a | Ejemplos de insumos |
|---|---|---|
| **Macro/Régimen** | ¿Es buen momento para tomar riesgo en general? | Tasas, curva, VIX, breadth, Fed/Banxico, USD/MXN |
| **Fundamental** | ¿Es un buen negocio a buen ritmo de crecimiento? | Márgenes, ROIC, FCF, deuda, guidance |
| **Valuación** | ¿El precio ya refleja lo bueno (o lo malo)? | Múltiplos vs. histórico/sector, DCF simplificado |
| **Técnico** | ¿Es un buen punto de entrada/salida? | Estructura de precio, medias, RSI/MACD, volumen |

Ninguna decisión de COMPRA se emite si falta evidencia de 3 de las 4 lentes. Si falta una lente por datos insuficientes, se reduce explícitamente el **Confidence**, no el Score.

## 4. Sistema de scoring (0–100)

Ponderación propuesta (calibrable con backtesting, sección 20 y punto 40 del brief):

| Factor | Peso | Qué mide |
|---|---|---|
| Calidad del negocio | 15% | Moat, márgenes, consistencia, gestión |
| Crecimiento | 15% | Revenue/EPS/FCF growth 1-3-5 años |
| Valuación | 15% | Múltiplos vs. histórico/sector + DCF |
| Fortaleza financiera | 10% | Deuda neta/EBITDA, cobertura de intereses, liquidez |
| Flujo de efectivo | 10% | Conversión de utilidad a FCF, calidad de utilidades |
| Momentum / técnico | 15% | Tendencia, relative strength, estructura de precio |
| Catalizadores | 10% | Eventos con impacto y probabilidad razonable |
| Riesgo (penalización) | 5% (resta) | Concentración de clientes, riesgo regulatorio, binario |
| Margen de seguridad | 5% | Distancia precio actual vs. valor razonable |

Score ≥ 80 con Confidence ≥ 75 y Risk/Reward ≥ 2.5 → candidato a **COMPRA/COMPRA FUERTE**. Score 60-79 → zona de **ESPERAR/OBSERVAR**. Score < 50 → fuera del radar salvo tesis de reversión explícita.

**Confidence** es independiente del Score: mide calidad/consistencia de la evidencia (cobertura de datos, ausencia de contradicciones, ausencia de eventos binarios inminentes), **no** probabilidad de ganar.

## 5. Gestión de riesgo

Capas de control, de arriba hacia abajo. Todos los porcentajes se calculan sobre **capital total real** (efectivo disponible + valor de mercado de posiciones), recalculado en cada evaluación — nunca sobre un patrimonio objetivo futuro:

1. **Riesgo de portafolio**: exposición máxima por sector, por emisora individual y por país/moneda, escalonada por fase de construcción del portafolio (ver 5A) — un portafolio de 3 posiciones no puede aplicar los mismos límites que uno de 20. Piso mínimo permanente de efectivo/CETES.
2. **Riesgo por posición**: tamaño determinado por convicción (Score/Confidence), volatilidad (ATR), distancia a la invalidación **y efectivo real disponible** — nunca un porcentaje arbitrario fijo ni un tamaño que exceda el efectivo/aportación disponible en ese momento (ver sección 15).
3. **Riesgo por operación**: cada compra define invalidación (tesis) y stop técnico *antes* de entrar. El riesgo absoluto (precio de entrada − invalidación) determina cuánto capital se arriesga.
4. **Riesgo de concentración oculta**: el sistema revisa correlaciones (ej. dos posiciones "distintas" con el mismo driver macro) para evitar diversificación falsa — especialmente relevante en portafolios pequeños, donde 2-3 posiciones correlacionadas pueden actuar como una sola.
5. **Drawdown**: se monitorea el drawdown del portafolio contra tu tolerancia máxima declarada; si se aproxima al límite, el sistema recomienda reducir riesgo nuevo, no añadirlo.

### 5A. Fases de construcción del portafolio

Como el portafolio parte de cero, los límites de concentración y el tipo de instrumento priorizado cambian con la madurez del capital, no con un monto en pesos fijo (que dependerá de comisiones/mínimos reales de GBM a confirmar en la fase técnica):

| Fase | Condición (no monto fijo) | Prioridad de asignación | Límite por posición individual (no-ETF) |
|---|---|---|---|
| **1. Cimientos** | El capital disponible no alcanza para abrir ~8-10 posiciones individuales sin que la comisión mínima de GBM erosione significativamente el monto (regla, no cifra fija — se calibra con el esquema real de comisiones) | ETFs amplios de bajo costo (diversificación instantánea) + reserva CETES | No aplica aún posición individual relevante; si se abre alguna de alta convicción, tope estricto (ej. ≤15%) |
| **2. Expansión** | El capital ya permite 8-10+ posiciones diversificadas manteniendo comisión razonable (<~1-1.5% del monto por operación) | Se activa el motor de screening completo para acciones/FIBRAs individuales; el core ETF se mantiene como piso mínimo de la cartera | Límite intermedio (ej. ≤10-12%) |
| **3. Madurez** | Portafolio con suficientes posiciones para diversificación real entre sectores/países | Portafolio core + satélite pleno (sección 5B); rebalanceo activo | Límite estándar (ej. ≤8-10%) |

Los porcentajes de esta tabla son una propuesta inicial sujeta a tu aprobación (ver "Próximo paso"); lo que no es negociable es el principio: **nunca se recomienda un tamaño de posición que comprometa la diversificación mínima de la fase en la que está el portafolio en ese momento.**

### 5B. Núcleo (Core) vs. Satélite (Táctico)

Dado tu horizonte principal de 10 años con espacio para oportunismo de mediano plazo:

- **Núcleo (Core)** — mayoría del capital desplegado (propuesta inicial: ~70-85%). ETFs amplios de bajo costo + empresas de altísima calidad con Score sostenido en el tiempo. Horizonte 10 años, rotación mínima. Solo sale por deterioro fundamental real, sobrevaluación extrema o rebalanceo por concentración — nunca por ruido técnico de corto plazo.
- **Satélite (Táctico)** — resto del capital, con **tope explícito** (propuesta inicial: ~15-30% del capital total desplegado, nunca del 100% de una aportación). Oportunidades de mediano plazo con Risk/Reward ≥ 2.5-3, invalidación más ajustada, horizonte de tenencia esperado menor. El satélite nunca se financia reduciendo el piso de diversificación del núcleo.

Esta separación evita que una "buena oportunidad táctica" te saque, sin darte cuenta, de tu plan de largo plazo.

### 5C. Asignación de aportaciones periódicas

Cada vez que registres efectivo nuevo (aportación o venta), el sistema evalúa, en este orden, y **nunca asume que todo el capital nuevo debe invertirse de inmediato**:

1. ¿Alguna posición existente está en zona de "AUMENTAR" (tesis vigente, Score sostenido) y sigue por debajo de su límite de concentración de fase? → prioridad si el resto de condiciones de compra se cumplen.
2. ¿El core ETF está por debajo de su piso de asignación (5B)? → se prioriza ahí para no perder diversificación mientras se evalúan oportunidades tácticas.
3. ¿Existe una oportunidad nueva con Score/Confidence/R-R por encima del umbral de compra (sección 6) que además supere el costo de oportunidad de CETES/ETF (sección 18)? → se evalúa como candidata, respetando siempre los límites de fase (5A) y el tope del satélite (5B).
4. Si nada de lo anterior aplica → la aportación se queda explícitamente en CETES/efectivo. Eso también es una decisión válida y se reporta como tal, no como "sin analizar".

## 6. Cómo detectarás compras

Una señal de compra requiere converger:
- Score ≥ 75 y Confidence ≥ 70.
- Margen de seguridad "atractivo" o "amplio" (valuación por debajo de valor razonable base).
- Entrada técnica "aceptable" o mejor (no extendida, cerca de soporte/zona de entrada, no en clímax de sobrecompra).
- Risk/Reward ≥ 2:1 (idealmente ≥ 3:1 para COMPRA FUERTE).
- Catalizador identificable o tendencia fundamental confirmada (no solo "se ve barata").
- Sin riesgo binario crítico no cubierto (ej. decisión regulatoria pendiente sin visibilidad).
- Rendimiento esperado supera claramente el costo de oportunidad (CETES/ETF, punto 24 del brief).

Si falta cualquiera de estos, la salida es **ESPERAR**, no una compra "a medias" disfrazada.

## 7. Cómo detectarás ventas

Se separan explícitamente cinco disparadores de salida (nunca se mezclan en una sola "señal de venta" genérica):

- **Toma de utilidades**: el precio alcanza el target base/optimista y el margen de seguridad se agotó, sin que la tesis original vaya más allá.
- **Reducción**: la posición excede el tamaño máximo por concentración, o el Score se deterioró parcialmente (ej. de 85 a 65) sin romper la tesis.
- **Venta por valuación**: el precio supera significativamente el valor razonable optimista sin justificación fundamental nueva.
- **Venta por deterioro**: cae calidad del negocio, márgenes, guidance, o el crecimiento se frena de forma estructural (no un trimestre ruidoso).
- **Venta por invalidación de tesis**: ocurre el evento que tú definiste de antemano como "esto significa que me equivoqué" (ej. pérdida de un cliente clave, ruptura de soporte estructural con deterioro fundamental simultáneo).

## 8. Cómo analizarás posiciones existentes

Cada posición en tu portafolio se re-evalúa con el mismo motor que un candidato nuevo (mismo Score, mismas 4 lentes), más:
- Precio promedio, P&L no realizado, retorno %.
- Peso actual vs. peso objetivo/máximo.
- Si la tesis original sigue vigente (checklist explícito escrito al comprar).
- Comparación contra el costo de oportunidad: "¿este capital rendiría mejor en otra posición, ETF o CETES ahora mismo?"

La salida siempre es una de: AUMENTAR, MANTENER, REDUCIR, TOMAR UTILIDAD, VENDER — nunca un genérico "sigue siendo buena empresa".

## 9. Cómo buscarás nuevas oportunidades

Screening en dos fases:
1. **Cuantitativo (amplio, determinista)**: filtra el universo (acciones MX, SIC, ETFs, FIBRAs, renta fija) por combinaciones de calidad + valuación + momentum + catalizadores agendados (earnings), sin sesgo hacia "lo popular".
2. **Cualitativo (profundo, en candidatos que pasan el filtro)**: análisis completo de las 4 lentes, generación de tesis, escenarios y JSON estructurado.

No se restringe a un índice o lista fija; se documentan los criterios de inclusión/exclusión para que el proceso sea repetible y auditable.

## 10. Qué datos necesitas

Por activo: precio y OHLCV histórico, estados financieros (income/balance/cash flow), estimados de analistas y guidance, corporate actions (splits, dividendos, buybacks), noticias con fecha/fuente, y — cuando aplica — tu posición actual (costo promedio, cantidad). A nivel mercado: índices (S&P 500, Nasdaq 100, Dow, Russell 2000, IPC), VIX, breadth, curva de Treasuries, USD/MXN, DXY, petróleo, oro, cobre, y calendario macro (Fed, Banxico, inflación, empleo). Ver también sección 38 del brief (paquete estructurado que recibe Claude).

## 11. Indicadores que utilizaré

- **Tendencia/estructura**: SMA 20/50/100/200, higher-highs/higher-lows (o su inverso), soportes/resistencias, consolidaciones, breakouts con retest.
- **Momentum**: RSI (contexto, no gatillo único), MACD, relative strength vs. benchmark/sector.
- **Volatilidad/riesgo**: ATR (para stops y position sizing), drawdown.
- **Volumen**: confirmación de breakouts, divergencias precio-volumen.
- **Valuación**: P/E, forward P/E, PEG, EV/EBITDA, EV/EBIT, P/S, P/B, P/FCF, FCF yield, dividend yield — la mezcla apropiada según el tipo de negocio (no todos aplican a todos los sectores).
- **Calidad/rentabilidad**: márgenes (bruto, operativo, EBITDA, neto), ROE, ROIC, ROA, Debt/EBITDA, cobertura de intereses.

## 12. Indicadores que NO utilizaré como gatillo único (y por qué)

- **RSI aislado**: sobrecompra/sobreventa no implica reversión en tendencias fuertes; solo se usa como contexto de "qué tan extendido" está el precio.
- **Cruces de una sola media móvil**: generan demasiadas señales falsas en mercados laterales; se usan como confirmación de estructura, no como gatillo.
- **Un solo múltiplo de valuación (ej. solo P/E)**: distorsiona en negocios cíclicos, con deuda alta, o con utilidades no representativas del flujo real — de ahí el uso de múltiples múltiplos + DCF.
- **Precio objetivo de un solo analista**: sesgo institucional/de cobertura; se usa como insumo agregado (rango de consenso), nunca como ancla única.
- **Sentiment de una sola noticia**: el ruido de titulares no distingue "material" de "irrelevante" (ver punto 15 del brief); toda noticia se clasifica antes de pesar en la decisión.
- **Indicadores rezagados en solitario** (ej. medias largas) sin contexto de volumen/fundamentales: confirman tendencia tarde, nunca deben ser la única razón de entrada o salida.

## 13. Cómo combinaré fundamentales + técnico + macro + valuación

Cada lente aporta una clasificación independiente (Calidad de negocio, Tendencia fundamental, Valuación, Estado técnico) que entra al Score ponderado (sección 4). El técnico **nunca** anula una tesis fundamental sólida por sí solo (una corrección técnica en una tesis intacta es oportunidad, no señal de venta), y viceversa: un "breakout" técnico sin sustento fundamental ni valuación razonable no genera una señal de COMPRA, como máximo entra a watchlist como "esperar confirmación fundamental".

## 14. Cómo evitaré FOMO / no perseguir precio

Regla explícita (punto 13 del brief): si el precio está significativamente extendido sobre sus medias, con RSI en zona de clímax y sin corrección/consolidación reciente, el sistema marca **"NO PERSEGUIR EL PRECIO"** y en su lugar entrega: precio ideal de entrada, precio aceptable, precio máximo a pagar, y qué confirmación técnica/fundamental esperar (ej. retest de soporte, consolidación, próximo reporte). Ninguna alerta de "COMPRA" se emite sobre una acción en esa condición, sin importar qué tan buena sea la empresa.

## 15. Cómo calcularé tamaño de posición

El tamaño de posición es el **mínimo** de tres límites independientes — nunca se usa un "% fijo para todas las compras" ni se asume capital que no está registrado:

1. **Límite por riesgo de la operación**: riesgo tolerado en la operación (definido por tu perfil, no arbitrario) ÷ distancia porcentual entre entrada e invalidación.
2. **Límite por concentración de fase**: el tope por emisora/sector vigente según la fase de construcción del portafolio (sección 5A) y, si es táctica, el tope del satélite (sección 5B).
3. **Límite por efectivo real disponible**: nunca se recomienda un monto mayor al efectivo disponible registrado en ese momento (aportación reciente + caja libre existente). El sistema no proyecta ni "reserva" capital futuro — si el efectivo disponible no alcanza para el tamaño ideal por riesgo/concentración, la recomendación se ajusta hacia abajo (o, si queda por debajo de un mínimo operativo razonable dados los costos de comisión de GBM, se recomienda esperar a la siguiente aportación en vez de forzar una compra subóptima).

Todo el cálculo se recalcula en cada evaluación sobre el capital total real (efectivo + valor de mercado de posiciones) del momento — nunca sobre una cifra objetivo futura. No se promedia automáticamente a la baja: solo se aumenta una posición si la tesis sigue vigente y el nuevo tamaño respeta los tres límites anteriores.

## 16. Cómo definiré invalidación

La invalidación combina dos componentes, y se documenta **antes** de comprar:
- **Invalidación de tesis (fundamental)**: el hecho concreto que, de ocurrir, significa que la razón original de comprar dejó de ser cierta (ej. pérdida de cuota de mercado sostenida, ruptura de guidance, deterioro de márgenes estructural).
- **Invalidación técnica (stop)**: nivel de precio ligado a estructura real (ruptura de soporte relevante con volumen, no un número redondo arbitrario).

Ambas se muestran en la alerta; el precio de invalidación técnica normalmente actúa como límite de riesgo operativo, mientras que la invalidación fundamental es la que obliga a re-evaluar la tesis completa aunque el precio no la haya tocado.

## 17. Cómo definiré targets

Se generan tres escenarios (pesimista/base/optimista, punto 16 del brief) con probabilidad estimada, precio objetivo y condición que debe cumplirse para cada uno, derivados de valuación (múltiplos + DCF simplificado) y no solo de proyección técnica. El **target base** ancla la toma de utilidades parcial; el **target optimista** ancla la salida completa o reducción mayor, salvo que surjan catalizadores nuevos que justifiquen extender la tesis. Se calcula también un valor esperado ponderado, siempre con la aclaración explícita de que no es una predicción garantizada.

## 18. Cómo compararé alternativas

Antes de aprobar capital nuevo hacia una idea, se compara explícitamente contra: mantener efectivo, CETES/renta fija, y un ETF amplio relevante (S&P 500 / Nasdaq / IPC según el universo), respondiendo la pregunta obligatoria del punto 24 del brief: *¿el riesgo adicional está compensado suficientemente frente a la alternativa más simple?* Si no, la recomendación es la alternativa simple, no la idea "interesante".

## 19. Qué benchmarks utilizaré

- **Renta variable EE. UU.**: S&P 500, Nasdaq 100 (y Russell 2000 para small caps).
- **Renta variable México**: IPC.
- **Riesgo/volatilidad**: VIX.
- **Renta fija/costo de oportunidad**: CETES (28/91/182/364 días) y curva de Treasuries.
- **Divisa**: USD/MXN, DXY (para exposición cambiaria del portafolio).
- Cada posición y el portafolio completo se miden contra el benchmark más relevante a su geografía/sector, no solo contra un índice genérico.

## 20. Cómo mediré si el sistema realmente funciona

Toda señal emitida se guarda con timestamp, precio de entrada sugerido y contexto completo (Score, Confidence, régimen). Posteriormente se calculan de forma determinista (no vía IA): retorno a 1D/7D/30D/90D, Maximum Favorable/Adverse Excursion, win rate, ganancia/pérdida promedio, expectancy y profit factor — todo comparado contra el benchmark correspondiente (sección 44 del brief). El backtesting inicial (sección 45) se hace fuera de muestra, con costos/spreads incluidos, evitando look-ahead y survivorship bias, antes de confiar capital relevante a las señales del sistema. Esto permite identificar qué condiciones/señales agregan valor real y recalibrar parámetros (sección 40 y 46) sin usar información futura.

---

## Parte técnica (resumen, pendiente de tu aprobación del diseño financiero)

Con el diseño financiero anterior aprobado, la implementación seguiría la arquitectura ya definida en el brief original:

- **21. Arquitectura cloud**: Datos de mercado/noticias → n8n Cloud (orquestación 24/7) → preprocesamiento determinista (indicadores, valuación, risk/reward calculados por código, no por IA) → Claude API (interpretación/síntesis/tesis) → motor de riesgo (position sizing, límites de portafolio) → base de datos (Supabase/Postgres) → motor de reglas de alerta → WhatsApp. Nada depende de tu computadora ni de Claude Code en ejecución continua; Claude Code se usa solo para desarrollar/desplegar.
- **22. APIs recomendadas**: arquitectura multi-provider (ninguna API cubre US + México + fundamentals + news igual de bien) — a evaluar entre Financial Modeling Prep / Polygon / Twelve Data / Finnhub / Tiingo, combinando la mejor cobertura US, la mejor cobertura MX/SIC disponible, y una fuente de noticias financieras confiable.
- **23. Base de datos**: Supabase/PostgreSQL con las tablas del punto 41 del brief (watchlist, portfolio, transactions, market_snapshots, fundamentals, analysis, signals, alerts, news, investment_thesis, performance, system_config, backtests). Las tablas `transactions` y `portfolio` son la **fuente de verdad del efectivo disponible** (ledger de aportaciones, compras/ventas y caja libre) — todo cálculo de sizing (sección 15) lee de ahí, nunca de un valor asumido.
- **24. n8n**: orquesta el pipeline completo en n8n Cloud, con credenciales gestionadas vía n8n Credentials (nunca hardcodeadas).
- **25. Claude API**: recibe el paquete estructurado (punto 38 del brief) y devuelve exclusivamente el JSON del punto 39, ampliado si hace falta; el cálculo cuantitativo (RSI, SMA, ATR, R/R, drawdown) ocurre en código antes de llegar a Claude, para reducir alucinaciones (punto 37).
- **26. WhatsApp**: Meta WhatsApp Cloud API o Twilio, con plantilla ejecutiva (punto 42) y deduplicación por cooldown/cambio de estado (punto 43).
- **27. Costos**: se propondrán tres niveles (MVP económico / recomendado / profesional) una vez elegidos los providers de datos, cubriendo market data, Claude API, n8n, Supabase, WhatsApp y hosting.
- **28. Roadmap técnico**: motor financiero → JSON/scoring/riesgo/alertas (ya definidos aquí) → selección de APIs → base de datos → n8n → Claude → WhatsApp → pruebas → despliegue → backtesting → dashboard, en ese orden, sin empezar por infraestructura.

---

## Próximo paso

Este documento es la propuesta de **diseño financiero** solicitada. Antes de tocar infraestructura (APIs, base de datos, n8n, WhatsApp), necesito tu aprobación o ajustes sobre:

1. Las ponderaciones del scoring (sección 4).
2. Los porcentajes propuestos de las secciones 5A (límites por fase) y 5B (tope del satélite táctico, ~15-30%) — son punto de partida razonable, no cifras derivadas de datos tuyos, porque aún no hay historial de operaciones.
3. Tu drawdown máximo tolerable (aún no lo has definido) — pendiente para calibrar el punto 5 de gestión de riesgo (drawdown).
4. Los umbrales de señal de compra (Score ≥ 75, Confidence ≥ 70, R/R ≥ 2, sección 6).
5. El universo inicial de instrumentos a cubrir (¿empezamos con ETFs + acciones MX + SIC, o agregamos renta fija/FIBRAs desde el día uno además del piso de CETES ya contemplado en la fase 1?).

Con eso aprobado, avanzamos a la sección técnica (APIs, base de datos, n8n, Claude, WhatsApp, costos).
