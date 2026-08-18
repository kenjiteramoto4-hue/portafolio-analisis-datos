"""
Genera un dataset sintetico de movimientos de inventario de refacciones
de refrigeracion. Datos ficticios que replican la estructura y los problemas
reales de un almacen de refacciones con multiples bases regionales.
"""
import numpy as np
import pandas as pd

rng = np.random.default_rng(2025)

# --- Catalogo de refacciones ---
refacciones = [
    # (nombre, categoria, costo_unitario_aprox, lead_time_dias, critica)
    ("Compresor 1/3 HP",          "Compresor",     4800, 12, True),
    ("Compresor 1/2 HP",          "Compresor",     6200, 14, True),
    ("Compresor 3/4 HP",          "Compresor",     8100, 18, True),
    ("Gas refrigerante R-134a",   "Refrigerante",   950,  4, True),
    ("Gas refrigerante R-404a",   "Refrigerante",  1400,  6, True),
    ("Termostato digital",        "Control",        620,  5, False),
    ("Termostato mecanico",       "Control",        290,  3, False),
    ("Empaque de puerta",         "Sello",          480,  7, True),
    ("Ventilador evaporador",     "Ventilacion",    890,  8, False),
    ("Ventilador condensador",    "Ventilacion",   1050,  9, False),
    ("Rele de arranque",          "Electrico",      180,  3, False),
    ("Capacitor de arranque",     "Electrico",      240,  4, False),
    ("Filtro deshidratador",      "Filtro",         160,  5, False),
    ("Valvula de expansion",      "Control",       1350, 11, False),
    ("Resistencia de deshielo",   "Electrico",      540,  6, False),
    ("Motor de damper",           "Ventilacion",    780, 10, False),
    ("Sensor de temperatura",     "Control",        310,  4, False),
    ("Contactor",                 "Electrico",      420,  5, False),
]

cat = pd.DataFrame(refacciones, columns=["refaccion","categoria","costo_unitario","lead_time_dias","critica"])
cat["sku"] = ["REF-" + str(i+101) for i in range(len(cat))]

regiones = ["Centro", "Bajio", "Norte", "Occidente", "Sureste"]
peso_region = [0.34, 0.18, 0.22, 0.15, 0.11]

# --- Generar movimientos de salida (consumo) durante 12 meses ---
N = 2100
inicio = pd.Timestamp("2025-01-01")

# refacciones criticas se consumen mas
p_ref = np.where(cat.critica, 1.8, 1.0)
p_ref = p_ref / p_ref.sum()
idx_ref = rng.choice(len(cat), N, p=p_ref)

region = rng.choice(regiones, N, p=peso_region)
dias = rng.integers(0, 365, N)
fecha = inicio + pd.to_timedelta(dias, unit="D")
mes = fecha.month

# Estacionalidad: verano dispara el consumo de compresores y gas
cantidad = rng.integers(1, 4, N)
for i in range(N):
    c = cat.iloc[idx_ref[i]]
    if c.categoria in ("Compresor", "Refrigerante") and mes[i] in (5,6,7,8):
        if rng.random() < 0.5:
            cantidad[i] += rng.integers(1, 3)

rows = []
for i in range(N):
    c = cat.iloc[idx_ref[i]]
    costo_real = c.costo_unitario * rng.uniform(0.95, 1.15)  # variacion de precio de compra
    rows.append({
        "id_movimiento": f"MOV-{i+1:05d}",
        "fecha": fecha[i],
        "sku": c.sku,
        "refaccion": c.refaccion,
        "categoria": c.categoria,
        "region": region[i],
        "cantidad": int(cantidad[i]),
        "costo_unitario": round(costo_real, 2),
        "lead_time_dias": c.lead_time_dias,
        "critica": "Si" if c.critica else "No",
    })

df = pd.DataFrame(rows)
df["costo_total"] = (df.cantidad * df.costo_unitario).round(2)

# --- Simular quiebres de stock (stockout): fecha en que no habia pieza ---
# Mayor probabilidad en criticas, en verano y en regiones lejanas
p_stockout = 0.06 + (df.critica=="Si")*0.09 + df.region.isin(["Norte","Sureste"])*0.05
p_stockout = p_stockout + df.fecha.dt.month.isin([5,6,7,8])*0.05
df["hubo_stockout"] = rng.random(len(df)) < p_stockout

# --- SUCIEDAD INTENCIONAL ---
# 1. Duplicados
dup = df.sample(24, random_state=5)
df = pd.concat([df, dup], ignore_index=True)
# 2. Region inconsistente
idx = df.sample(70, random_state=8).index
df.loc[idx[:35], "region"] = df.loc[idx[:35], "region"].str.upper()
df.loc[idx[35:], "region"] = " " + df.loc[idx[35:], "region"]
# 3. Nulos en costo
df.loc[df.sample(38, random_state=12).index, "costo_unitario"] = np.nan
df.loc[df.sample(19, random_state=14).index, "cantidad"] = np.nan
# 4. Cantidad negativa (devoluciones mal capturadas)
idx_neg = df.sample(11, random_state=16).index
df.loc[idx_neg, "cantidad"] = -df.loc[idx_neg, "cantidad"].abs()
# 5. Fecha como texto
df["fecha"] = df["fecha"].dt.strftime("%d/%m/%Y")
# recalcular costo_total tras meter nulos (queda inconsistente a proposito)
df = df.sample(frac=1, random_state=3).reset_index(drop=True)

cols = ["id_movimiento","fecha","sku","refaccion","categoria","region",
        "cantidad","costo_unitario","costo_total","lead_time_dias","critica","hubo_stockout"]
df = df[cols]
df.to_csv("datos/inventario_refacciones.csv", index=False, encoding="utf-8")
cat.to_csv("datos/catalogo_refacciones.csv", index=False, encoding="utf-8")
print("Movimientos:", len(df), "| SKUs:", len(cat))
print(df.head(3).to_string())
