# Base de datos

Esquema correspondiente a la sección 3 de `docs/01-diseno-tecnico.md`. Probado localmente contra Postgres 16 (creación de las 13 tablas y verificación de que los CHECK constraints de vocabulario cerrado — decisiones, clasificaciones, régimen, etc. — realmente rechazan valores fuera del catálogo definido en el brief).

## Archivos

- `migrations/0001_init_schema.sql` — crea las 13 tablas (`system_config`, `investment_thesis`, `portfolio`, `transactions`, `watchlist`, `market_snapshots`, `fundamentals`, `analysis`, `signals`, `alerts`, `news`, `performance`, `backtests`).
- `seed/0001_system_config.sql` — carga los parámetros ya cerrados en el diseño financiero (pesos de scoring, umbrales de compra por tramo, bandas Core/Satélite/Liquidez, límites de drawdown y de posición, universo de instrumentos, benchmarks de régimen). Insertar solo una vez, al desplegar por primera vez.

## Cómo aplicarlo en Supabase

1. Crea el proyecto en [supabase.com](https://supabase.com) (plan Free alcanza para el Nivel 1 — ver `docs/01-diseno-tecnico.md` sección 10).
2. En el **SQL Editor** del proyecto, pega y ejecuta `migrations/0001_init_schema.sql`.
3. Ejecuta `seed/0001_system_config.sql`.
4. Copia la URL del proyecto y la `service_role key` (Project Settings → API) a tu `.env` (ver `.env.example` en la raíz).

## Cómo probarlo localmente (sin Supabase)

Requiere Postgres instalado localmente.

```bash
createdb inversion_test
psql -d inversion_test -f migrations/0001_init_schema.sql
psql -d inversion_test -f seed/0001_system_config.sql
```

## Recalibración de parámetros

`system_config` está diseñada para no editarse por UPDATE: cuando el backtesting (sección 20 del diseño financiero) sugiera un ajuste, se inserta una **nueva fila** con el mismo `config_key`, `version` incrementada, y se marca `is_active = false` en la fila anterior — así queda el historial completo de qué parámetros produjo qué resultados, en vez de perder la calibración anterior.
