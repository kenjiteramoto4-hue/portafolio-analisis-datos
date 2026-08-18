-- =====================================================================
-- Análisis de costos e inventario de refacciones de refrigeración
-- Autor: Kenji Teramoto
-- Tabla principal: inventario
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. CALIDAD DE DATOS
-- ---------------------------------------------------------------------

-- 1.1 Volumen, duplicados, nulos y cantidades inválidas

SELECT
    COUNT(*) AS total_movimientos,
    COUNT(DISTINCT id_movimiento) AS movimientos_unicos,
    SUM(CASE WHEN costo_unitario IS NULL THEN 1 ELSE 0 END) AS sin_costo,
    SUM(CASE WHEN cantidad IS NULL THEN 1 ELSE 0 END) AS sin_cantidad,
    SUM(CASE WHEN cantidad < 0 THEN 1 ELSE 0 END) AS cantidades_negativas
FROM inventario;


-- 1.2 Revisión de consistencia en regiones

SELECT
    region,
    TRIM(UPPER(region)) AS region_normalizada,
    COUNT(*) AS movimientos
FROM inventario
GROUP BY region
ORDER BY region_normalizada;


-- ---------------------------------------------------------------------
-- 2. GASTO POR CATEGORÍA
-- ---------------------------------------------------------------------

SELECT
    categoria,
    COUNT(*) AS movimientos,
    ROUND(SUM(cantidad * costo_unitario), 0) AS gasto_total,
    ROUND(
        100.0 * SUM(cantidad * costo_unitario)
        / (
            SELECT SUM(cantidad * costo_unitario)
            FROM inventario
            WHERE cantidad > 0
              AND costo_unitario IS NOT NULL
        ),
        1
    ) AS pct_del_gasto
FROM inventario
WHERE cantidad > 0
  AND costo_unitario IS NOT NULL
GROUP BY categoria
ORDER BY gasto_total DESC;


-- ---------------------------------------------------------------------
-- 3. ANÁLISIS DE PARETO POR REFACCIÓN
-- ---------------------------------------------------------------------

SELECT
    refaccion,
    ROUND(SUM(cantidad * costo_unitario), 0) AS gasto_total,
    ROUND(
        100.0 * SUM(cantidad * costo_unitario)
        / (
            SELECT SUM(cantidad * costo_unitario)
            FROM inventario
            WHERE cantidad > 0
              AND costo_unitario IS NOT NULL
        ),
        1
    ) AS pct_del_gasto
FROM inventario
WHERE cantidad > 0
  AND costo_unitario IS NOT NULL
GROUP BY refaccion
ORDER BY gasto_total DESC;


-- ---------------------------------------------------------------------
-- 4. QUIEBRES DE STOCK
--    Comparación entre piezas críticas y no críticas
-- ---------------------------------------------------------------------

SELECT
    critica,
    COUNT(*) AS movimientos,
    SUM(
        CASE
            WHEN hubo_stockout IN ('True', '1') THEN 1
            ELSE 0
        END
    ) AS quiebres,
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN hubo_stockout IN ('True', '1') THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        1
    ) AS tasa_quiebre_pct
FROM inventario
WHERE cantidad > 0
GROUP BY critica;


-- ---------------------------------------------------------------------
-- 5. ESTACIONALIDAD DE LOS QUIEBRES
-- ---------------------------------------------------------------------

SELECT
    SUBSTR(fecha, 4, 2) AS mes,
    COUNT(*) AS movimientos,
    SUM(
        CASE
            WHEN hubo_stockout IN ('True', '1') THEN 1
            ELSE 0
        END
    ) AS quiebres,
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN hubo_stockout IN ('True', '1') THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        1
    ) AS tasa_quiebre_pct
FROM inventario
WHERE cantidad > 0
GROUP BY SUBSTR(fecha, 4, 2)
ORDER BY mes;


-- ---------------------------------------------------------------------
-- 6. GASTO, LEAD TIME Y QUIEBRES POR REGIÓN
-- ---------------------------------------------------------------------

SELECT
    TRIM(region) AS region,
    ROUND(SUM(cantidad * costo_unitario), 0) AS gasto_total,
    ROUND(AVG(lead_time_dias), 1) AS lead_time_promedio,
    SUM(
        CASE
            WHEN hubo_stockout IN ('True', '1') THEN 1
            ELSE 0
        END
    ) AS quiebres,
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN hubo_stockout IN ('True', '1') THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        1
    ) AS tasa_quiebre_pct
FROM inventario
WHERE cantidad > 0
  AND costo_unitario IS NOT NULL
GROUP BY TRIM(region)
ORDER BY gasto_total DESC;


-- ---------------------------------------------------------------------
-- 7. PRIORIZACIÓN DE REFACCIONES
--    Identifica piezas que combinan:
--    • alto gasto
--    • alta tasa de quiebre
--    • criticidad
--    • lead time
-- ---------------------------------------------------------------------

WITH resumen AS (

    SELECT
        refaccion,
        MAX(critica) AS critica,
        ROUND(SUM(cantidad * costo_unitario), 0) AS gasto_total,
        ROUND(AVG(lead_time_dias), 1) AS lead_time_promedio,

        ROUND(
            100.0 *
            SUM(
                CASE
                    WHEN hubo_stockout IN ('True', '1') THEN 1
                    ELSE 0
                END
            ) / COUNT(*),
            1
        ) AS tasa_quiebre_pct

    FROM inventario

    WHERE cantidad > 0
      AND costo_unitario IS NOT NULL

    GROUP BY refaccion
)

SELECT
    refaccion,
    critica,
    gasto_total,
    lead_time_promedio,
    tasa_quiebre_pct,

    CASE
        WHEN critica IN ('True', '1')
             AND tasa_quiebre_pct >= 20
        THEN 'ALTA'

        WHEN tasa_quiebre_pct >= 10
             OR critica IN ('True', '1')
        THEN 'MEDIA'

        ELSE 'BAJA'
    END AS prioridad

FROM resumen

ORDER BY
    CASE
        WHEN critica IN ('True', '1')
             AND tasa_quiebre_pct >= 20
        THEN 1

        WHEN tasa_quiebre_pct >= 10
             OR critica IN ('True', '1')
        THEN 2

        ELSE 3
    END,
    gasto_total DESC;
