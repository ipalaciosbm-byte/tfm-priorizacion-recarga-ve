# tfm-priorizacion-recarga-ve
Pipeline end-to-end para priorizar barrios de Madrid para infraestructura de recarga de VE (TFM)
# Priorización de barrios de Madrid para infraestructura de recarga de vehículo eléctrico

*Pipeline* de datos *end-to-end* que prioriza los **131 barrios de Madrid** para la instalación de nuevos puntos de recarga de vehículo eléctrico, combinando un modelo de decisión multicriterio, una capa predictiva y un análisis económico. Trabajo de Fin de Máster.

## Qué hace

A partir de fuentes públicas (puntos de recarga existentes, padrón de vehículos, calidad del aire, tráfico, vivienda y demografía), el proyecto:

1. Integra y limpia los datos en una base de datos PostgreSQL siguiendo una **arquitectura Medallion** (bronze → silver → gold).
2. Modela la información en un **esquema en estrella** (tablas de hechos y dimensiones).
3. Calcula un **scoring multicriterio (MCDA)** por barrio y una **regresión predictiva** de la evolución del vehículo eléctrico.
4. Añade una **capa económica** con el cálculo de *payback* (retorno de la inversión) por barrio.
5. Presenta los resultados en **cuadros de mando interactivos en Power BI**.

## Stack técnico

- **Lenguaje:** Python (pandas, NumPy, SQLAlchemy, geopy)
- **Base de datos:** PostgreSQL sobre Supabase
- **Arquitectura de datos:** Medallion (bronze/silver/gold), modelo en estrella
- **Análisis:** modelo de decisión multicriterio (MCDA), regresión predictiva, análisis de *break-even*
- **Visualización:** Power BI

## Estructura del repositorio

```
.
├── README.md
├── pipeline_etl.ipynb        # ETL: extracción, limpieza y carga a PostgreSQL
└── sql/
    ├── 01_esquema.sql        # claves, tipos de columnas y tabla de hechos
    ├── 02_scoring.sql        # columnas y vista de scoring (incl. NO2)
    └── 03_analisis.sql       # top barrios, break-even, predicciones y vivienda
```

## Fuentes de datos

Datos abiertos del Ayuntamiento de Madrid y otras fuentes oficiales: histórico de puntos de recarga, padrón de vehículos, indicadores demográficos por barrio, calidad del aire (NO₂), intensidad de tráfico y régimen de tenencia de vivienda.

## Cómo ejecutarlo

1. Instala las dependencias:

   ```bash
   pip install pandas sqlalchemy psycopg2-binary openpyxl numpy geopy xlrd
   ```

2. Configura la conexión a tu base de datos **de forma segura**, sin escribir la contraseña en el código. En Google Colab, guarda la cadena de conexión en *Secrets* con el nombre `DB_URL`; el notebook la lee automáticamente. Formato esperado:

   ```
   postgresql+psycopg2://USUARIO:CONTRASENA@HOST.pooler.supabase.com:5432/postgres?sslmode=require
   ```

3. Ejecuta `pipeline_etl.ipynb` para poblar la base de datos y, a continuación, las consultas de la carpeta `sql/` en orden.

## Dashboard (Power BI)

El archivo `.pbix` no se incluye en el repositorio por su tamaño. A continuación, algunas capturas de los cuadros de mando:

<img width="700" height="435" alt="image" src="https://github.com/user-attachments/assets/c2c15881-ed57-421a-a20c-88e149e01826" />


## Autora

Irene Palacios Barrenechea-Moxó — Máster en Business Analytics & Data Strategy
