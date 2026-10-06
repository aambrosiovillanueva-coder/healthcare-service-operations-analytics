# Clinical Asset Service Operations & SLA Performance Dashboard

Centralized dimensional analytics model designed to monitor medical equipment service tickets, optimize Mean Time to Repair (MTTR), and evaluate Service Level Agreement (SLA) compliance across hospital accounts.

---

## 🏥 Contexto Operativo y Problema de Negocio

En operaciones de servicio técnico hospitalario, el tiempo de inactividad de equipos de soporte de vida e imagenología impacta directamente en la atención al paciente y genera penalizaciones por incumplimiento de contratos de servicio. 

Los sistemas transaccionales hospitalarios y ERPs suelen registrar eventos de servicio de forma desestructurada (solicitudes, asignaciones, refacciones y cierre de tickets), dificultando el cálculo confiable de tiempos reales de respuesta y la identificación de fallas repetitivas.

**Objetivos del Proyecto:**
- Centralizar más de 50,000 registros transaccionales de órdenes de servicio en un esquema analítico optimizado.
- Monitorear el cumplimiento de SLA contractual (resolución en < 24h para equipos críticos clase III).
- Calcular y desglosar el **MTTR (Mean Time to Repair)** y **MTBF (Mean Time Between Failures)** por fabricante y tipo de tecnología médica.
- Identificar cuellos de botella en la logística de refacciones y disponibilidad de ingenieros de campo.

---

## 📐 Arquitectura del Modelo Dimensional (Esquema en Estrella)

Siguiendo la metodología de Ralph Kimball, el modelo desacopla transacciones de entidades maestras para garantizar granularidad atómica y máximo rendimiento del motor tabular:
              +-------------------+
              |      DimDate      |
              +-------------------+
                        | 1
                        |
                        | *
+-------------------+     +-------------------------+     +-------------------+
|   DimEquipment    |---->|   FactServiceOrders     |<----|    DimHospital    |
+-------------------+ 1 * +-------------------------+ * 1 +-------------------+
| *
|
| 1
+-------------------+
|   DimTechnician   |
+-------------------+
### Granularidad y Diccionario de Tablas:
* **`FactServiceOrders` (Hecho Transaccional):** Una fila por cada evento/orden de servicio completada o cancelada. Contiene claves foráneas, marcas temporales (fecha solicitud, fecha resolución) y métricas cuantitativas (`Horas_Paro`, `Costo_Mano_Obra`, `Costo_Refacciones`).
* **`DimEquipment` (Dimensión):** Catálogo de activos (`ID_Equipo`, `Numero_Serie`, `Clase_Riesgo`, `Modalidad` [p. ej. Rayos X, Monitor, Resonancia], `Fecha_Instalacion`).
* **`DimHospital` (Dimensión):** Clientes y sedes clínicas (`ID_Sede`, `Nombre_Hospital`, `Nivel_Atencion`, `Region_Geografica`).
* **`DimTechnician` (Dimensión):** Equipo de soporte técnico (`ID_Tecnico`, `Nombre`, `Certificacion_Modalidad`, `Disponibilidad`).
* **`DimDate` (Dimensión):** Tabla de calendario construida para habilitar funciones de Time Intelligence sin dependencias de fechas automáticas.

---

## ⚙️ Métricas Clave y Lógica DAX

Las medidas analíticas fueron estructuradas evitando columnas calculadas y aplicando variables (`VAR`) para optimizar el contexto de evaluación y rendimiento de memoria:

### 1. Cumplimiento de SLA en Equipos Críticos (%)
```dax
SLA_Compliance_Critical_Pct = 
VAR TotalCriticalOrders = 
    CALCULATE(
        COUNTROWS(FactServiceOrders),
        DimEquipment[Clase_Riesgo] = "Clase III - Soporte de Vida"
    )
VAR ResolvedOnTime = 
    CALCULATE(
        COUNTROWS(FactServiceOrders),
        DimEquipment[Clase_Riesgo] = "Clase III - Soporte de Vida",
        FactServiceOrders[Dentro_SLA_Flag] = 1
    )
RETURN
````
###2. Mean Time to Repair (MTTR en Horas)
MTTR_Hours = 
VAR TotalDowntimeHours = SUM(FactServiceOrders[Horas_Paro_Equipo])
VAR TotalCorrectiveOrders = 
    CALCULATE(
        COUNTROWS(FactServiceOrders),
        FactServiceOrders[Tipo_Servicio] = "Correctivo"
    )
RETURN
    DIVIDE(TotalDowntimeHours, TotalCorrectiveOrders, BLANK())
🗂️ Estructura del Repositorio:
├── data/
│   ├── raw/                 # Esquemas y datos sintéticos normalizados
│   └── data_dictionary.md   # Definición formal de atributos y campos
├── src/
│   ├── sql/                 # Consultas de extracción, agregación y validación
│   └── powerquery/          # Scripts M para tipado y profiling de fuentes
├── reports/
│   └── clinical_service_dashboard.pbit  # Plantilla de reporte Power BI
└── docs/
    └── screenshots/         # Vistas del modelo estrella y dashboard final

    
  
🛠️ Tecnologías y Prácticas Implementadas
Power BI / DAX: Variables de ejecución, separación de medidas en carpetas semánticas y Time Intelligence.

Power Query (M): Perfilado de calidad de datos, normalización de marcas de tiempo y tipos de datos numéricos estrictos.

Modelado Dimensional: Diseño de Star Schema evitando relaciones Many-to-Many (* : *) y filtros bidireccionales.

Git / GitHub: Control de versiones de especificaciones analíticas y código SQL
