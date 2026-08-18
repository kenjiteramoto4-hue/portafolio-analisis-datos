"""
Genera un dataset sintetico de folios de servicio de refrigeracion comercial.
Los datos son ficticios pero replican la estructura y los problemas reales
de un sistema de gestion de servicios en campo.
"""
import numpy as np
import pandas as pd

rng = np.random.default_rng(42)
N = 1400

regiones = ["Centro", "Bajio", "Norte", "Occidente", "Sureste"]
peso_region = [0.34, 0.18, 0.22, 0.15, 0.11]

equipos = ["Congelador horizontal", "Refrigerador vertical", "Camara fria",
           "Vitrina refrigerada", "Maquina de hielo"]
peso_equipo = [0.26, 0.30, 0.14, 0.22, 0.08]

tipos = ["Correctivo", "Preventivo", "Instalacion"]
peso_tipo = [0.62, 0.30, 0.08]

fallas = ["Fuga de refrigerante", "Falla de compresor", "Termostato descalibrado",
          "Problema electrico", "Acumulacion de hielo", "Puerta / empaque danado",
          "Mantenimiento programado"]

clientes = [f"Cliente {i:03d}" for i in range(1, 61)]
tecnicos = [f"TEC-{i:03d}" for i in range(1, 39)]

# --- Fechas de apertura a lo largo de 12 meses ---
inicio = pd.Timestamp("2025-01-01")
dias = rng.integers(0, 365, N)
apertura = inicio + pd.to_timedelta(dias, unit="D")
apertura = apertura + pd.to_timedelta(rng.integers(7, 19, N), unit="h")

region = rng.choice(regiones, N, p=peso_region)
equipo = rng.choice(equipos, N, p=peso_equipo)
tipo = rng.choice(tipos, N, p=peso_tipo)
tecnico = rng.choice(tecnicos, N)
cliente = rng.choice(clientes, N)

# --- Falla coherente con el tipo de servicio ---
falla = []
for t in tipo:
    if t == "Preventivo":
        falla.append("Mantenimiento programado")
    else:
        falla.append(rng.choice(fallas[:6], p=[0.22, 0.16, 0.18, 0.17, 0.15, 0.12]))
falla = np.array(falla)

# --- Tiempo de respuesta (horas) con senales reales integradas ---
base = rng.gamma(shape=2.2, scale=9.0, size=N) + 2

# Efecto region: Sureste y Norte tardan mas (distancias y cobertura)
efecto_region = {"Centro": 0.0, "Bajio": 3.0, "Norte": 8.5, "Occidente": 4.0, "Sureste": 13.0}
base += np.array([efecto_region[r] for r in region])

# Efecto refaccion: si requiere pieza, el servicio se alarga bastante
requiere_refaccion = np.where(
    np.isin(falla, ["Falla de compresor", "Puerta / empaque danado", "Fuga de refrigerante"]),
    rng.random(N) < 0.72,
    rng.random(N) < 0.18)
base += requiere_refaccion * rng.gamma(shape=2.0, scale=14.0, size=N)

# Efecto fin de semana
fin_semana = apertura.dayofweek >= 5
base += fin_semana * rng.uniform(6, 20, N)

# Efecto temporada: verano satura la operacion
mes = apertura.month
verano = np.isin(mes, [5, 6, 7, 8])
base += verano * rng.uniform(2, 11, N)

# Preventivos son mas predecibles
base = np.where(tipo == "Preventivo", base * 0.55, base)

horas_respuesta = np.round(base, 1)

# --- Reincidencia: mismo equipo vuelve a fallar en menos de 30 dias ---
p_reinc = 0.08 + requiere_refaccion * 0.05 + (tipo == "Correctivo") * 0.07
reincidencia = rng.random(N) < p_reinc

costo = np.round(
    np.where(tipo == "Preventivo", rng.uniform(800, 2600, N),
             rng.uniform(1500, 14000, N)) + requiere_refaccion * rng.uniform(900, 6500, N), 2)

df = pd.DataFrame({
    "folio": [f"F-{2025}{i:05d}" for i in range(1, N + 1)],
    "fecha_apertura": apertura,
    "cliente": cliente,
    "region": region,
    "tipo_equipo": equipo,
    "tipo_servicio": tipo,
    "falla_reportada": falla,
    "tecnico_id": tecnico,
    "requiere_refaccion": np.where(requiere_refaccion, "Si", "No"),
    "horas_respuesta": horas_respuesta,
    "costo_servicio": costo,
    "reincidencia_30d": np.where(reincidencia, "Si", "No"),
})

df["fecha_cierre"] = df["fecha_apertura"] + pd.to_timedelta(df["horas_respuesta"], unit="h")
df["estatus"] = "Cerrado"

# =========================================================
# SUCIEDAD INTENCIONAL — para que la limpieza sea trabajo real
# =========================================================

# 1. Duplicados exactos
dups = df.sample(28, random_state=7)
df = pd.concat([df, dups], ignore_index=True)

# 2. Inconsistencias de texto en region
idx = df.sample(90, random_state=11).index
df.loc[idx[:30], "region"] = df.loc[idx[:30], "region"].str.upper()
df.loc[idx[30:60], "region"] = " " + df.loc[idx[30:60], "region"] + " "
df.loc[idx[60:], "region"] = df.loc[idx[60:], "region"].str.lower()

# 3. Valores nulos
df.loc[df.sample(46, random_state=13).index, "horas_respuesta"] = np.nan
df.loc[df.sample(31, random_state=17).index, "tecnico_id"] = np.nan
df.loc[df.sample(22, random_state=19).index, "costo_servicio"] = np.nan

# 4. Outliers imposibles (errores de captura)
idx_out = df.sample(14, random_state=23).index
df.loc[idx_out, "horas_respuesta"] = rng.uniform(900, 2400, len(idx_out)).round(1)

# 5. Horas negativas (capturas invertidas)
idx_neg = df.sample(9, random_state=29).index
df.loc[idx_neg, "horas_respuesta"] = -df.loc[idx_neg, "horas_respuesta"].abs()

# 6. Estatus inconsistente
df.loc[df.sample(55, random_state=31).index, "estatus"] = "En proceso"
df.loc[df.sample(18, random_state=37).index, "estatus"] = "cerrado"

# 7. Fechas como texto (formato mixto, tipico de exportaciones)
df["fecha_apertura"] = df["fecha_apertura"].dt.strftime("%Y-%m-%d %H:%M")
df["fecha_cierre"] = df["fecha_cierre"].dt.strftime("%Y-%m-%d %H:%M")

df = df.sample(frac=1, random_state=3).reset_index(drop=True)

cols = ["folio", "fecha_apertura", "fecha_cierre", "cliente", "region", "tipo_equipo",
        "tipo_servicio", "falla_reportada", "tecnico_id", "requiere_refaccion",
        "horas_respuesta", "costo_servicio", "reincidencia_30d", "estatus"]
df = df[cols]

df.to_csv("datos/servicios_refrigeracion.csv", index=False, encoding="utf-8")
print(f"Filas: {len(df)}  |  Columnas: {len(df.columns)}")
print(df.head(3).to_string())
