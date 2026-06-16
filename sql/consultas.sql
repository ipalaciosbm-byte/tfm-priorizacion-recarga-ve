-- ============================================================
-- Fact Indicadores Zonales por Periodo
-- ============================================================

DROP TABLE IF EXISTS fact_indicadores_zonales;

CREATE TABLE fact_indicadores_zonales AS
WITH puntos_recarga_barrio AS (
    SELECT
        cod_bar::bigint AS cod_bar,
        COUNT(*) AS num_puntos_recarga,
        SUM(numero_equipos::numeric) AS total_equipos_recarga,
        SUM(potencia_total_kw::numeric) AS potencia_total_kw,
        MAX(potencia_max_kw::numeric) AS potencia_max_kw
    FROM dim_puntos_recarga
    GROUP BY cod_bar
),

vehiculos_barrio AS (
    SELECT
        cod_barrio::bigint AS cod_bar,
        SUM(total_vehiculos::numeric) AS total_vehiculos,
        SUM(vehiculos_eco::numeric) AS vehiculos_eco,
        SUM(vehiculos_cero::numeric) AS vehiculos_cero,
        SUM(vehiculos_electricos::numeric) AS vehiculos_electricos,
        AVG(pct_eco::numeric) AS pct_eco,
        AVG(pct_cero::numeric) AS pct_cero,
        AVG(pct_electricos::numeric) AS pct_electricos
    FROM dim_vehiculos
    WHERE cod_barrio != 0
    GROUP BY cod_barrio
),

demografia_barrio AS (
    SELECT
        cod_barrio::bigint AS cod_bar,
        AVG(media::numeric) AS renta_media_hogar,
        AVG(indice_de_envejecimiento::numeric) AS indice_envejecimiento,
        AVG(indice_de_juventud::numeric) AS indice_juventud,
        AVG(indice_de_dependencia::numeric) AS indice_dependencia
    FROM silver_indicadores_demograficos_barrio
    GROUP BY cod_barrio
)

SELECT
    ROW_NUMBER() OVER () AS id_fact,

    g.cod_bar::bigint AS fk_cod_bar,
    g.cod_dis::int AS fk_cod_dis,
    t.id_tiempo::int AS fk_id_tiempo,

    g.nombre_barrio,
    g.nombre_distrito,
    t.anio,
    t.mes,

    -- Contaminación
    no2.no2_media_mes_barrio::numeric AS no2_media_mes_barrio,
    no2.no2_media_mes_barrio_weighted::numeric AS no2_media_mes_barrio_weighted,
    no2.dias_validos_total::numeric AS dias_validos_no2,
    no2.n_estaciones::numeric AS n_estaciones_no2,

    -- Tráfico
    traf.trafico_medio_laborable::numeric AS trafico_medio_laborable,
    traf.n_cinturones::numeric AS n_cinturones,

    -- Vivienda
    viv.viv_total::numeric AS viv_total,
    viv.viv_principal::numeric AS viv_principal,
    viv.viv_alquiler::numeric AS viv_alquiler,
    viv.viv_propiedad::numeric AS viv_propiedad,
    viv.pct_alquiler_principal::numeric AS pct_alquiler_principal,
    viv.pct_propiedad_principal::numeric AS pct_propiedad_principal,

    -- Demografía
    demo.renta_media_hogar,
    demo.indice_envejecimiento,
    demo.indice_juventud,
    demo.indice_dependencia,

    -- Vehículos
    veh.total_vehiculos,
    veh.vehiculos_eco,
    veh.vehiculos_cero,
    veh.vehiculos_electricos,
    veh.pct_eco,
    veh.pct_cero,
    veh.pct_electricos,

    -- Recarga
    pr.num_puntos_recarga,
    pr.total_equipos_recarga,
    pr.potencia_total_kw,
    pr.potencia_max_kw,

    -- Scoring futuro
    NULL::numeric AS scoring_final_prioridad

FROM dim_geografia g

JOIN dim_tiempo t
    ON t.id_tiempo BETWEEN 202501 AND 202512

LEFT JOIN silver_no2_barrio_mes no2
    ON no2."COD_BAR"::bigint = g.cod_bar::bigint
   AND no2."ID_TIEMPO"::int = t.id_tiempo::int

LEFT JOIN silver_trafico_barrio_mes_m40 traf
    ON traf."COD_BAR"::bigint = g.cod_bar::bigint
   AND traf."ID_TIEMPO"::int = t.id_tiempo::int

LEFT JOIN silver_vivienda_barrio_2021 viv
    ON viv.cod_bar::bigint = g.cod_bar::bigint

LEFT JOIN demografia_barrio demo
    ON demo.cod_bar = g.cod_bar::bigint

LEFT JOIN vehiculos_barrio veh
    ON veh.cod_bar = g.cod_bar::bigint

LEFT JOIN puntos_recarga_barrio pr
    ON pr.cod_bar = g.cod_bar::bigint;

-- ============================================================
-- Set Primary and Foreign Keys for Fact and Dimension Tables
-- ============================================================
-- PK FACT
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'pk_fact_indicadores_zonales'
    ) THEN

        ALTER TABLE fact_indicadores_zonales
        ADD CONSTRAINT pk_fact_indicadores_zonales
        PRIMARY KEY (id_fact);

    END IF;
END $$;


-- =====================================================
-- PK DIM_GEOGRAFIA
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'pk_dim_geografia'
    ) THEN

        ALTER TABLE dim_geografia
        ADD CONSTRAINT pk_dim_geografia
        PRIMARY KEY (cod_bar);

    END IF;
END $$;


-- =====================================================
-- PK DIM_TIEMPO
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'pk_dim_tiempo'
    ) THEN

        ALTER TABLE dim_tiempo
        ADD CONSTRAINT pk_dim_tiempo
        PRIMARY KEY (id_tiempo);

    END IF;
END $$;


-- =====================================================
-- FK FACT → GEOGRAFIA
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_fact_geografia'
    ) THEN

        ALTER TABLE fact_indicadores_zonales
        ADD CONSTRAINT fk_fact_geografia
        FOREIGN KEY (fk_cod_bar)
        REFERENCES dim_geografia(cod_bar);

    END IF;
END $$;


-- =====================================================
-- FK FACT → TIEMPO
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_fact_tiempo'
    ) THEN

        ALTER TABLE fact_indicadores_zonales
        ADD CONSTRAINT fk_fact_tiempo
        FOREIGN KEY (fk_id_tiempo)
        REFERENCES dim_tiempo(id_tiempo);

    END IF;
END $$;

-- ============================================================
-- Top Barrios por Porcentaje de Alquiler Principal (Ene 2025)
-- ============================================================
SELECT 
    COUNT(vehiculos_electricos) as con_electricos,
    COUNT(vehiculos_eco) as con_eco,
    COUNT(vehiculos_cero) as con_cero,
    COUNT(pct_alquiler_principal) as con_alquiler,
    COUNT(renta_media_hogar) as con_renta,
    COUNT(trafico_medio_laborable) as con_trafico,
    COUNT(no2_media_mes_barrio) as con_no2,
    COUNT(num_puntos_recarga) as con_recarga,
    COUNT(indice_envejecimiento) as con_envejecimiento,
    COUNT(indice_juventud) as con_juventud
FROM fact_indicadores_zonales;

-- ============================================================
-- Monthly Barrio Data Coverage Summary
-- ============================================================
SELECT 
    fk_id_tiempo,
    anio,
    mes,
    COUNT(DISTINCT fk_cod_bar) as barrios_con_dato,
    COUNT(no2_media_mes_barrio) as barrios_con_no2,
    COUNT(trafico_medio_laborable) as barrios_con_trafico,
    COUNT(vehiculos_electricos) as barrios_con_vehiculos,
    COUNT(renta_media_hogar) as barrios_con_renta
FROM fact_indicadores_zonales
GROUP BY fk_id_tiempo, anio, mes
ORDER BY fk_id_tiempo;

SELECT 
    COUNT(*) as total_filas,
    MIN(fk_id_tiempo) as primer_mes,
    MAX(fk_id_tiempo) as ultimo_mes,
    COUNT(DISTINCT fk_cod_bar) as total_barrios

SELECT 
    COUNT(*) as total,
    COUNT(vehiculos_eco) as con_eco,
    COUNT(vehiculos_cero) as con_cero,
    COUNT(pct_alquiler_principal) as con_alquiler,
    COUNT(renta_media_hogar) as con_renta,
    COUNT(trafico_medio_laborable) as con_trafico,
    COUNT(no2_media_mes_barrio) as con_no2,
    COUNT(num_puntos_recarga) as con_recarga,
    COUNT(indice_juventud) as con_juventud,
    COUNT(indice_envejecimiento) as con_envejecimiento
FROM fact_indicadores_zonales;
SELECT 
    COUNT(*) as total,
    COUNT(vehiculos_eco) as con_eco,
    COUNT(vehiculos_cero) as con_cero,
    COUNT(pct_alquiler_principal) as con_alquiler,
    COUNT(renta_media_hogar) as con_renta,
    COUNT(trafico_medio_laborable) as con_trafico,
    COUNT(no2_media_mes_barrio) as con_no2,
    COUNT(num_puntos_recarga) as con_recarga,
    COUNT(indice_juventud) as con_juventud,
    COUNT(indice_envejecimiento) as con_envejecimiento,
    COUNT(vehiculos_electricos) as con_electricos,
    COUNT(pct_electricos) as con_pct_electricos
FROM fact_indicadores_zonales;
-- ============================================================
-- Barrio Scoring View (2025)
-- ============================================================
CREATE OR REPLACE VIEW v_scoring_barrio AS
SELECT
    fk_cod_bar,
    nombre_barrio,
    nombre_distrito,
    fk_cod_dis,
    AVG(scoring_final_prioridad)                        AS scoring_final,
    AVG(vehiculos_eco + vehiculos_cero)                 AS demanda_ev,
    AVG(pct_alquiler_principal)                         AS pct_alquiler,
    AVG(renta_media_hogar)                              AS renta_media,
    AVG(trafico_medio_laborable)                        AS trafico_medio,
    AVG(indice_juventud)                                AS indice_juventud,
    COALESCE(AVG(num_puntos_recarga), 0)                AS num_puntos_recarga,
    AVG(no2_media_mes_barrio)                           AS no2_medio,
    AVG(vehiculos_electricos)                           AS vehiculos_electricos,
    AVG(total_vehiculos)                                AS total_vehiculos
FROM fact_indicadores_zonales
WHERE anio = 2025
GROUP BY
    fk_cod_bar,
    nombre_barrio,
    nombre_distrito,
    fk_cod_dis;

SELECT 
    nombre_barrio,
    nombre_distrito,
    ROUND(scoring_final::numeric, 2) as scoring
FROM v_scoring_barrio
ORDER BY scoring_final DESC
LIMIT 10;
-- ============================================================
-- Column Types for dim_puntos_recarga
-- ============================================================
-- =====================================================
-- FACT 1: PUNTOS DE RECARGA (grano: 1 punto)
-- =====================================================
DROP TABLE IF EXISTS fact_puntos_recarga CASCADE;

CREATE TABLE fact_puntos_recarga AS
SELECT
    ROW_NUMBER() OVER () AS id_fact_recarga,
    cod_bar::bigint AS fk_cod_bar,
    cod_dis::bigint AS fk_cod_dis,
    id_punto,
    operador,
    ubicacion,
    direccion_completa,
    emplazamiento,
    numero_equipos::bigint AS numero_equipos,
    potencia_total_kw::numeric AS potencia_total_kw,
    potencia_max_kw::numeric AS potencia_max_kw,
    latitud::numeric AS latitud,
    longitud::numeric AS longitud
FROM dim_puntos_recarga;

-- =====================================================
-- FACT 2: DEMOGRAFÍA (grano: barrio, sin tiempo)
-- =====================================================
DROP TABLE IF EXISTS fact_demografia CASCADE;

CREATE TABLE fact_demografia AS
SELECT
    ROW_NUMBER() OVER () AS id_fact_dem,
    d.cod_barrio::bigint AS fk_cod_bar,
    d.coddis::bigint AS fk_cod_dis,

    -- Renta
    AVG(d.media::numeric) AS renta_media_hogar,

    -- Índices demográficos
    AVG(d.indice_de_juventud::numeric) AS indice_juventud,
    AVG(d.indice_de_envejecimiento::numeric) AS indice_envejecimiento,
    AVG(d.indice_de_dependencia::numeric) AS indice_dependencia,
    AVG(d.proporcion_de_juventud::numeric) AS proporcion_juventud,
    AVG(d.proporcion_de_envejecimiento::numeric) AS proporcion_envejecimiento,

    -- Vivienda
    AVG(viv.pct_alquiler_principal::numeric) AS pct_alquiler_principal,
    AVG(viv.pct_propiedad_principal::numeric) AS pct_propiedad_principal,
    AVG(viv.viv_total::numeric) AS viv_total,
    AVG(viv.viv_alquiler::numeric) AS viv_alquiler,
    AVG(viv.viv_propiedad::numeric) AS viv_propiedad

FROM silver_indicadores_demograficos_barrio d
LEFT JOIN silver_vivienda_barrio_2021 viv
    ON viv.cod_bar::bigint = d.cod_barrio::bigint
GROUP BY d.cod_barrio, d.coddis;

-- =====================================================
-- FACT 3: VEHÍCULOS HISTÓRICO (grano: barrio-año)
-- =====================================================
DROP TABLE IF EXISTS fact_vehiculos_historico CASCADE;

CREATE TABLE fact_vehiculos_historico AS
SELECT
    ROW_NUMBER() OVER () AS id_fact_veh_hist,
    vh.cod_barrio::bigint AS fk_cod_bar,
    vh.cod_distrito::bigint AS fk_cod_dis,
    vh.ejercicio::int AS anio,
    vh.total_vehiculos,
    vh.vehiculos_eco,
    vh.vehiculos_cero,
    vh.vehiculos_eco_cero,
    vh.vehiculos_electricos,
    vh.pct_eco,
    vh.pct_cero,
    vh.pct_electricos
FROM dim_vehiculos_historico vh
WHERE vh.cod_barrio IN (SELECT cod_bar FROM dim_geografia);

-- =====================================================
-- FACT 4: CALIDAD DEL AIRE NO2 (grano: barrio-mes)
-- =====================================================
DROP TABLE IF EXISTS fact_calidad_aire CASCADE;

CREATE TABLE fact_calidad_aire AS
SELECT
    ROW_NUMBER() OVER () AS id_fact_aire,
    "COD_BAR"::bigint AS fk_cod_bar,
    "COD_DIS"::bigint AS fk_cod_dis,
    "ID_TIEMPO"::bigint AS fk_id_tiempo,
    "ANO" AS anio,
    "MES" AS mes,
    no2_media_mes_barrio::numeric AS no2_media_mes_barrio,
    no2_media_mes_barrio_weighted::numeric AS no2_media_mes_barrio_weighted,
    dias_validos_total::bigint AS dias_validos_total,
    n_estaciones::bigint AS n_estaciones
FROM silver_no2_barrio_mes;

-- =====================================================
-- FACT 5: TRÁFICO (grano: barrio-mes)
-- =====================================================
DROP TABLE IF EXISTS fact_trafico CASCADE;

CREATE TABLE fact_trafico AS
SELECT
    ROW_NUMBER() OVER () AS id_fact_trafico,
    "COD_BAR"::bigint AS fk_cod_bar,
    "COD_DIS"::bigint AS fk_cod_dis,
    "ID_TIEMPO"::bigint AS fk_id_tiempo,
    "ANO" AS anio,
    "MES" AS mes,
    trafico_medio_laborable::numeric AS trafico_medio_laborable,
    n_cinturones::bigint AS n_cinturones
FROM silver_trafico_barrio_mes_m40;

-- =====================================================
-- FACT 6: SCORING (grano: barrio-mes)
-- =====================================================
DROP TABLE IF EXISTS fact_scoring CASCADE;

CREATE TABLE fact_scoring AS
SELECT
    id_fact,
    fk_cod_bar,
    fk_cod_dis,
    fk_id_tiempo,
    anio,
    mes,
    scoring_final_prioridad,
    scoring_con_no2
FROM fact_indicadores_zonales;

-- =====================================================
-- PRIMARY KEYS
-- =====================================================
ALTER TABLE fact_puntos_recarga
ADD CONSTRAINT pk_fact_puntos_recarga PRIMARY KEY (id_fact_recarga);

ALTER TABLE fact_demografia
ADD CONSTRAINT pk_fact_demografia PRIMARY KEY (id_fact_dem);

ALTER TABLE fact_vehiculos_historico
ADD CONSTRAINT pk_fact_veh_hist PRIMARY KEY (id_fact_veh_hist);

ALTER TABLE fact_calidad_aire
ADD CONSTRAINT pk_fact_aire PRIMARY KEY (id_fact_aire);

ALTER TABLE fact_trafico
ADD CONSTRAINT pk_fact_trafico PRIMARY KEY (id_fact_trafico);

ALTER TABLE fact_scoring
ADD CONSTRAINT pk_fact_scoring PRIMARY KEY (id_fact);

-- =====================================================
-- FOREIGN KEYS → DIM_GEOGRAFIA
-- =====================================================
ALTER TABLE fact_puntos_recarga
ADD CONSTRAINT fk_recarga_geografia
FOREIGN KEY (fk_cod_bar) REFERENCES dim_geografia(cod_bar);

ALTER TABLE fact_demografia
ADD CONSTRAINT fk_demografia_geografia
FOREIGN KEY (fk_cod_bar) REFERENCES dim_geografia(cod_bar);

ALTER TABLE fact_vehiculos_historico
ADD CONSTRAINT fk_veh_hist_geografia
FOREIGN KEY (fk_cod_bar) REFERENCES dim_geografia(cod_bar);

ALTER TABLE fact_calidad_aire
ADD CONSTRAINT fk_aire_geografia
FOREIGN KEY (fk_cod_bar) REFERENCES dim_geografia(cod_bar);

ALTER TABLE fact_trafico
ADD CONSTRAINT fk_trafico_geografia
FOREIGN KEY (fk_cod_bar) REFERENCES dim_geografia(cod_bar);

ALTER TABLE fact_scoring
ADD CONSTRAINT fk_scoring_geografia
FOREIGN KEY (fk_cod_bar) REFERENCES dim_geografia(cod_bar);

-- =====================================================
-- FOREIGN KEYS → DIM_TIEMPO
-- =====================================================
ALTER TABLE fact_calidad_aire
ADD CONSTRAINT fk_aire_tiempo
FOREIGN KEY (fk_id_tiempo) REFERENCES dim_tiempo(id_tiempo);

ALTER TABLE fact_trafico
ADD CONSTRAINT fk_trafico_tiempo
FOREIGN KEY (fk_id_tiempo) REFERENCES dim_tiempo(id_tiempo);

ALTER TABLE fact_scoring
ADD CONSTRAINT fk_scoring_tiempo
FOREIGN KEY (fk_id_tiempo) REFERENCES dim_tiempo(id_tiempo);

DROP TABLE IF EXISTS fact_vehiculos_demografia CASCADE;

-- ============================================================
-- Find Orphan Barcodes
-- ============================================================

DROP TABLE IF EXISTS fact_puntos_recarga CASCADE;

CREATE TABLE fact_puntos_recarga AS
SELECT
    ROW_NUMBER() OVER () AS id_fact_recarga,
    cod_bar::bigint AS fk_cod_bar,
    cod_dis::bigint AS fk_cod_dis,
    id_punto,
    operador,
    ubicacion,
    direccion_completa,
    emplazamiento,
    numero_equipos::bigint AS numero_equipos,
    potencia_total_kw::numeric AS potencia_total_kw,
    potencia_max_kw::numeric AS potencia_max_kw,
    latitud::numeric AS latitud,
    longitud::numeric AS longitud
FROM dim_puntos_recarga;

ALTER TABLE fact_puntos_recarga
ADD CONSTRAINT pk_fact_puntos_recarga PRIMARY KEY (id_fact_recarga);

SELECT DISTINCT pr.fk_cod_bar
FROM fact_puntos_recarga pr
LEFT JOIN dim_geografia g ON pr.fk_cod_bar = g.cod_bar
WHERE g.cod_bar IS NULL;

ALTER TABLE dim_geografia
ADD CONSTRAINT pk_dim_geografia PRIMARY KEY (cod_bar);

ALTER TABLE dim_tiempo
ADD CONSTRAINT pk_dim_tiempo PRIMARY KEY (id_tiempo);
-- ============================================================
-- Remove Foreign Keys and Primary Keys
-- ============================================================
-- Eliminar FKs que dependen de dim_tiempo
ALTER TABLE fact_calidad_aire DROP CONSTRAINT IF EXISTS fk_aire_tiempo;
ALTER TABLE fact_trafico DROP CONSTRAINT IF EXISTS fk_trafico_tiempo;
ALTER TABLE fact_scoring DROP CONSTRAINT IF EXISTS fk_scoring_tiempo;

-- Eliminar FK de dim_geografia
ALTER TABLE fact_puntos_recarga DROP CONSTRAINT IF EXISTS fk_recarga_geografia;
ALTER TABLE fact_calidad_aire DROP CONSTRAINT IF EXISTS fk_aire_geografia;
ALTER TABLE fact_trafico DROP CONSTRAINT IF EXISTS fk_trafico_geografia;
ALTER TABLE fact_scoring DROP CONSTRAINT IF EXISTS fk_scoring_geografia;
ALTER TABLE fact_vehiculos_demografia DROP CONSTRAINT IF EXISTS fk_vehiculos_geografia;

-- Eliminar PKs de dimensiones
ALTER TABLE dim_geografia DROP CONSTRAINT IF EXISTS pk_dim_geografia;
ALTER TABLE dim_tiempo DROP CONSTRAINT IF EXISTS pk_dim_tiempo;

-- ============================================================
-- Add scoring field for NO2 concentrations
-- ============================================================

ALTER TABLE fact_scoring
ADD COLUMN IF NOT EXISTS scoring_con_no2 numeric;

-- ============================================================
-- Top 10 barrios by priority scoring
-- ============================================================
SELECT 
    g.nombre_barrio,
    g.nombre_distrito,
    ROUND(fs.scoring_final_prioridad::numeric, 2) as scoring,
    ROUND(fs.scoring_con_no2::numeric, 2) as scoring_no2
FROM fact_scoring fs
JOIN dim_geografia g ON g.cod_bar = fs.fk_cod_bar
WHERE fs.mes = 1
ORDER BY fs.scoring_final_prioridad DESC
LIMIT 10;

-- ============================================================
-- Top 10 barrios by priority scoring
-- ============================================================



-- ============================================================
-- Vista: modelo economico
-- ============================================================

DROP VIEW IF EXISTS v_modelo_economico;

CREATE OR REPLACE VIEW v_modelo_economico AS
WITH params AS (
  SELECT
    11::numeric    AS potencia_punto_kw,   -- punto AC semirrápido (kW)
    1.3::numeric   AS kw_por_ve_afir,      -- AFIR: 1,3 kW por VE
    0.5::numeric   AS factor_cobertura,    -- escala % alquiler -> % recarga pública
    10000::numeric AS coste_punto,         -- € instalación punto público AC
    800::numeric   AS opex_anual,          -- € mantenimiento+conectividad/año
    14.8::numeric  AS kwh_recarga,         -- kWh por sesión (uso urbano)
    0.45::numeric  AS precio_kwh,          -- € cobrado al usuario
    0.15::numeric  AS coste_kwh            -- € coste energía comprada
),
base AS (
  SELECT
    s.fk_cod_bar, s.nombre_barrio, s.nombre_distrito,
    s.scoring_final AS scoring,
    s.pct_alquiler,
    p.vehiculos_eco_cero_prediccion AS ve_2028,
    (s.pct_alquiler * par.factor_cobertura) AS pct_recarga_publica,
    GREATEST(1, CEIL(
      (p.vehiculos_eco_cero_prediccion * s.pct_alquiler * par.factor_cobertura)
      / (par.potencia_punto_kw / par.kw_por_ve_afir)
    ))::int AS puntos,
    -- CRITERIO 3: recargas/día continuas en función del scoring (2 a 6)
    (2 + ((s.scoring_final/100.0) * 4)) AS recargas_dia,
    par.coste_punto, par.opex_anual, par.kwh_recarga, par.precio_kwh, par.coste_kwh
  FROM v_scoring_barrio s
  JOIN fact_prediccion_vehiculos p
    ON p.fk_cod_bar = s.fk_cod_bar AND p.anio = 2028
  CROSS JOIN params par
)
SELECT
  fk_cod_bar, nombre_barrio, nombre_distrito,
  ROUND(scoring::numeric, 3) AS scoring,
  ROUND(ve_2028::numeric, 0) AS ve_2028,
  ROUND((pct_recarga_publica * 100)::numeric, 1) AS pct_publica,
  puntos,
  ROUND(recargas_dia::numeric, 1) AS recargas_dia,
  puntos * coste_punto AS inversion_total,
  ROUND(puntos * (recargas_dia * kwh_recarga * 365 * (precio_kwh - coste_kwh) - opex_anual), 0) AS margen_anual,
  ROUND( (puntos * coste_punto) /
         NULLIF(puntos * (recargas_dia * kwh_recarga * 365 * (precio_kwh - coste_kwh) - opex_anual), 0)
       , 2) AS break_even_anios
FROM base
ORDER BY scoring DESC;
