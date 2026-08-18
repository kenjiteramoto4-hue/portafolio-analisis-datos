-- =====================================================================
-- Análisis de tiempos de respuesta en servicios de refrigeración
-- Autor: Kenji Teramoto
--
-- Estas consultas replican en SQL el análisis del notebook de Python.
-- Tabla: servicios
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. DIAGNÓSTICO DE CALIDAD DE DATOS
--    Antes de analizar, cuantificar qué tan confiable es la tabla.
-- ---------------------------------------------------------------------

-- 1.1 Volumen general y valores faltantes
SELECT
    COUNT(*)                                            AS total_folios,
    COUNT(DISTINCT folio)                               AS folios_unicos,
    COUNT(*) - COUNT(DISTINCT folio)                    AS posibles_duplicados,
    SUM(CASE WHEN horas_respuesta IS NULL THEN 1 ELSE 0 END) AS sin_horas,
    SUM(CASE WHEN tecnico_id     IS NULL THEN 1 ELSE 0 END) AS sin_tecnico,
    SUM(CASE WHEN costo_servicio IS NULL THEN 1 ELSE 0 END) AS sin_costo
FROM servicios;


-- 1.2 Inconsistencias de captura en el campo region
--     La misma región aparece escrita de varias formas.
SELECT
    region              AS valor_crudo,
    UPPER(TRIM(region)) AS valor_normalizado,
    COUNT(*)            AS folios
FROM servicios
GROUP BY region
ORDER BY valor_normalizado, folios DESC;


-- 1.3 Registros fuera de rango (errores de captura)
SELECT
    SUM(CASE WHEN horas_respuesta <  0   THEN 1 ELSE 0 END) AS horas_negativas,
    SUM(CASE WHEN horas_respuesta > 720  THEN 1 ELSE 0 END) AS mayores_30_dias
FROM servicios;


-- ---------------------------------------------------------------------
-- 2. KPIs GENERALES
--    Se filtran los registros inválidos en cada consulta.
-- ---------------------------------------------------------------------

SELECT
    COUNT(*)                                        AS folios_validos,
    ROUND(AVG(horas_respuesta), 1)                  AS horas_promedio,
    ROUND(MIN(horas_respuesta), 1)                  AS horas_minimo,
    ROUND(MAX(horas_respuesta), 1)                  AS horas_maximo,
    ROUND(100.0 * SUM(CASE WHEN horas_respuesta <= 24 THEN 1 ELSE 0 END)
          / COUNT(*), 1)                            AS pct_cumple_sla_24h
FROM servicios
WHERE horas_respuesta > 0
  AND horas_respuesta <= 720;


-- ---------------------------------------------------------------------
-- 3. DESEMPEÑO POR REGIÓN
--    TRIM y UPPER corrigen las inconsistencias detectadas en 1.2.
-- ---------------------------------------------------------------------

SELECT
    UPPER(TRIM(region))                             AS region,
    COUNT(*)                                        AS folios,
    ROUND(AVG(horas_respuesta), 1)                  AS horas_promedio,
    ROUND(100.0 * SUM(CASE WHEN horas_respuesta <= 24 THEN 1 ELSE 0 END)
          / COUNT(*), 1)                            AS pct_cumple_sla
FROM servicios
WHERE horas_respuesta > 0
  AND horas_respuesta <= 720
GROUP BY UPPER(TRIM(region))
ORDER BY horas_promedio DESC;


-- ---------------------------------------------------------------------
-- 4. HALLAZGO PRINCIPAL: EL IMPACTO DE LAS REFACCIONES
-- ---------------------------------------------------------------------

SELECT
    requiere_refaccion,
    COUNT(*)                                        AS folios,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM servicios
                              WHERE horas_respuesta > 0
                                AND horas_respuesta <= 720), 1) AS pct_del_total,
    ROUND(AVG(horas_respuesta), 1)                  AS horas_promedio,
    ROUND(100.0 * SUM(CASE WHEN horas_respuesta <= 24 THEN 1 ELSE 0 END)
          / COUNT(*), 1)                            AS pct_cumple_sla
FROM servicios
WHERE horas_respuesta > 0
  AND horas_respuesta <= 720
GROUP BY requiere_refaccion;


-- ---------------------------------------------------------------------
-- 5. FALLAS QUE MÁS TIEMPO CONSUMEN
--    Cruza el tiempo promedio con qué tan seguido exigen refacción.
-- ---------------------------------------------------------------------

SELECT
    falla_reportada,
    COUNT(*)                                        AS folios,
    ROUND(AVG(horas_respuesta), 1)                  AS horas_promedio,
    ROUND(100.0 * SUM(CASE WHEN requiere_refaccion = 'Si' THEN 1 ELSE 0 END)
          / COUNT(*), 1)                            AS pct_requiere_refaccion
FROM servicios
WHERE horas_respuesta > 0
  AND horas_respuesta <= 720
GROUP BY falla_reportada
HAVING COUNT(*) >= 30
ORDER BY horas_promedio DESC;


-- ---------------------------------------------------------------------
-- 6. ESTACIONALIDAD
--    El mes se extrae del texto de la fecha (formato AAAA-MM-DD HH:MM).
-- ---------------------------------------------------------------------

SELECT
    SUBSTR(fecha_apertura, 6, 2)                    AS mes,
    COUNT(*)                                        AS folios,
    ROUND(AVG(horas_respuesta), 1)                  AS horas_promedio
FROM servicios
WHERE horas_respuesta > 0
  AND horas_respuesta <= 720
GROUP BY SUBSTR(fecha_apertura, 6, 2)
ORDER BY mes;


-- ---------------------------------------------------------------------
-- 7. TÉCNICOS CON MAYOR CARGA Y MENOR CUMPLIMIENTO
--    Solo técnicos con volumen suficiente para que el dato sea confiable.
-- ---------------------------------------------------------------------

SELECT
    tecnico_id,
    COUNT(*)                                        AS folios_atendidos,
    ROUND(AVG(horas_respuesta), 1)                  AS horas_promedio,
    ROUND(100.0 * SUM(CASE WHEN horas_respuesta <= 24 THEN 1 ELSE 0 END)
          / COUNT(*), 1)                            AS pct_cumple_sla
FROM servicios
WHERE horas_respuesta > 0
  AND horas_respuesta <= 720
  AND tecnico_id IS NOT NULL
GROUP BY tecnico_id
HAVING COUNT(*) >= 25
ORDER BY pct_cumple_sla ASC
LIMIT 10;


-- ---------------------------------------------------------------------
-- 8. REINCIDENCIAS Y SU COSTO
--    Cada reincidencia significa pagar dos veces por el mismo problema.
-- ---------------------------------------------------------------------

SELECT
    reincidencia_30d,
    COUNT(*)                                        AS folios,
    ROUND(AVG(horas_respuesta), 1)                  AS horas_promedio,
    ROUND(SUM(costo_servicio), 0)                   AS costo_total_mxn,
    ROUND(AVG(costo_servicio), 0)                   AS costo_promedio_mxn
FROM servicios
WHERE horas_respuesta > 0
  AND horas_respuesta <= 720
GROUP BY reincidencia_30d;


-- ---------------------------------------------------------------------
-- 9. CLIENTES CON PEOR NIVEL DE SERVICIO
--    Útil para priorizar planes de recuperación de cuenta.
-- ---------------------------------------------------------------------

SELECT
    cliente,
    COUNT(*)                                        AS folios,
    ROUND(AVG(horas_respuesta), 1)                  AS horas_promedio,
    SUM(CASE WHEN reincidencia_30d = 'Si' THEN 1 ELSE 0 END) AS reincidencias
FROM servicios
WHERE horas_respuesta > 0
  AND horas_respuesta <= 720
GROUP BY cliente
HAVING COUNT(*) >= 15
ORDER BY horas_promedio DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- 10. VISTA CONSOLIDADA: REGIÓN x REFACCIÓN
--     Cruce de los dos factores para ubicar dónde actuar primero.
-- ---------------------------------------------------------------------

SELECT
    UPPER(TRIM(region))                             AS region,
    requiere_refaccion,
    COUNT(*)                                        AS folios,
    ROUND(AVG(horas_respuesta), 1)                  AS horas_promedio
FROM servicios
WHERE horas_respuesta > 0
  AND horas_respuesta <= 720
GROUP BY UPPER(TRIM(region)), requiere_refaccion
ORDER BY region, requiere_refaccion;
