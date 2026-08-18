-- =====================================================================
-- Análisis de costos e inventario de refacciones de refrigeración
-- Autor: Kenji Teramoto
-- Tabla: inventario
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. CALIDAD DE DATOS
-- ---------------------------------------------------------------------

-- 1.1 Volumen, duplicados y nulos
SELECT
    COUNT(*)                                                 AS total_movimientos,
    COUNT(DISTINCT id_movimiento)                            AS movimientos_unicos,
    SUM(CASE WHEN costo_unitario IS NULL THEN 1 ELSE 0 END)  AS sin_costo,
    SUM(CASE WHEN cantidad       IS NULL THEN 1 ELSE 0 END)  AS sin_cantidad,
    SUM(CASE WHEN cantidad < 0 THEN 1 ELSE 0 END)            AS cantidades_negativas
FROM inventario;

-- 1.2 Inconsistencias de captura en region
SELECT region, TRIM(UPPER(region)) AS normalizada, COUNT(*) AS n
FROM inventario
GROUP BY region
ORDER BY normalizada;


-- ---------------------------------------------------------------------
-- 2. GASTO POR CATEGORÍA
--    Filtra registros inválidos (nulos y cantidades no positivas).
-- ---------------------------------------------------------------------

SELECT
    categoria,
    COUNT(*)                                        AS movimientos,
    ROUND(SUM(cantidad * costo_unitario), 0)        AS gasto_total,
    ROUND(100.0 * SUM(cantidad * costo_unitario)
          / (SELECT SUM(cantidad * costo_unitario)
             FROM inventario
             WHERE cantidad > 0 AND costo_unitario IS NOT NULL), 1) AS pct_del_gasto
FROM inventario
WHERE cantidad > 0
  AND costo_unitario IS NOT NULL
GROUP BY categoria
ORDER BY gasto_total DESC;


-- ---------------------------------------------------------------------
-- 3. ANÁLISIS DE PARETO POR REFACCIÓN
--    ¿Qué piezas concentran el gasto? (regla 80/20)
-- ---------------------------------------------------------------------

SELECT
    refaccion,
    ROUND(SUM(cantidad * costo_unitario), 0)        AS gasto_total,
    ROUND(100.0 * SUM(cantidad * costo_unitario)
          / (SELECT SUM(cantidad * costo_unitario)
             FROM inventario
             WHERE cantidad > 0 AND costo_unitario IS NOT NULL), 1) AS pct_del_gasto
FROM inventario
WHERE cantidad > 0
  AND costo_unitario IS NOT NULL
GROUP BY refaccion
ORDER BY gasto_total DESC;


-- ---------------------------------------------------------------------
-- 4. QUIEBRES DE STOCK: PIEZAS CRÍTICAS VS NO CRÍTICAS
-- ---------------------------------------------------------------------

SELECT
    critica,
    COUNT(*)                                        AS movimientos,
    SUM(CASE WHEN hubo_stockout IN ('True','1') THEN 1 ELSE 0 END) AS quiebres,
    ROUND(100.0 * SUM(CASE WHEN hubo_stockout IN ('True','1') THEN 1 ELSE 0 END)
          / COUNT(*), 1)                            AS tasa_quiebre_pct
FROM inventario
WHERE cantidad > 0
GROUP BY critica;


-- ---------------------------------------------------------------------
-- 5. ESTACIONALIDAD DE LOS QUIEBRES
--    El mes se extrae del texto de la fecha (formato DD/MM/AAAA).
-- ---------------------------------------------------------------------

SELECT
    SUBSTR(fecha, 4, 2)                             AS mes,
    COUNT(*)                                        AS movimientos,
    ROUND(100.0 * SUM(CASE WHEN hubo_stockout IN ('True','1') THEN 1 ELSE 0 END)
          / COUNT(*), 1)                            AS tasa_quiebre_pct
FROM inventario
WHERE cantidad > 0
GROUP BY SUBSTR(fecha, 4, 2)
ORDER BY mes;


-- ---------------------------------------------------------------------
-- 6. GASTO Y QUIEBRES POR REGIÓN
-- ---------------------------------------------------------------------

SELECT
    TRIM(region)                                    AS region,
    ROUND(SUM(cantidad * costo_unitario), 0)        AS gasto_total,
    ROUND(AVG(lead_time_dias), 1)                   AS lead_time_promedio,
    ROUND(100.0 * SUM(CASE WHEN hubo_stockout IN ('True','1') THEN 1 ELSE 0 END)
          / COUNT(*), 1)                            AS tasa_quiebre_pct
FROM inventario
WHERE cantidad > 0
  AND costo_unitario IS NOT NULL
GROUP BY TRIM(region)
ORDER BY gasto_total DESC;


-- ---------------------------------------------------------------------
-- 7. LAS 5 REFACCIONES A BLINDAR
--    Cruce de gasto alto + tasa de quiebre, para priorizar el inventario.
-- ---------------------------------------------------------------------

SELECT
    refaccion,
    critica,
    ROUND(SUM(cantidad * costo_unitario), 0)        AS gasto_total,
    ROUND(AVG(lead_time_dias), 0)                   AS lead_time,
    ROUND(100.0 * SUM(CASE WHEN hubo_stockout IN ('True','1') THEN 1 ELSE 0 END)
          / COUNT(*), 1)                            AS tasa_quiebre_pct
FROM inventario
WHERE cantidad > 0
  AND costo_unitario IS NOT NULL
GROUP BY refaccion, critica
ORDER BY gasto_total DESC
LIMIT 5;
