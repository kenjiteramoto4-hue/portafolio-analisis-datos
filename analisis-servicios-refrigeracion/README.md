# Tiempos de respuesta en servicios de refrigeración

## Descripción

Análisis de tiempos de respuesta en servicios de refrigeración comercial para identificar los principales factores que afectan el cierre de los servicios.

El proyecto analiza 1,428 folios de servicio utilizando Python, pandas y SQL.

## Objetivo

Identificar qué factores tienen mayor impacto en el tiempo necesario para cerrar un servicio y encontrar oportunidades de mejora operativa.

## Hallazgo principal

El principal cuello de botella son las **refacciones**, no la geografía.

Los servicios que requieren una refacción tardan aproximadamente **55 horas**, frente a **27 horas** para los servicios que no requieren pieza.

Los servicios con necesidad de refacción representan aproximadamente el **38% de los folios**.

## Herramientas

- Python
- pandas
- SQL
- Análisis exploratorio de datos
- Visualización de datos

## Estructura del proyecto

- `datos/` — Dataset utilizado para el análisis.
- `imagenes/` — Visualizaciones y resultados.
- `notebooks/` — Análisis realizado en Python.
- `sql/` — Consultas SQL utilizadas.
- `generar_datos.py` — Script para generar los datos sintéticos.

## Resultado

El análisis permite identificar a las refacciones como el principal punto de atención para reducir los tiempos de cierre de los servicios.

Los datasets utilizados son sintéticos y fueron generados para el análisis. No contienen información de ninguna empresa real.
