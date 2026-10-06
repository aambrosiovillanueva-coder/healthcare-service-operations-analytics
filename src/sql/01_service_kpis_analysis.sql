/* =============================================================================
   PROYECTO: Clinical Asset Service Operations & SLA Performance
   OBJETIVO: Consultas analíticas para extracción de métricas operativas (MTTR y SLA)
   MOTOR: PostgreSQL / ANSI SQL
   ============================================================================= */

-- 1. Vista de Cumplimiento de SLA en Equipos Críticos (Clase III)
WITH ordenes_enriquecidas AS (
    SELECT 
        f.id_orden,
        f.id_equipo,
        e.modalidad,
        e.clase_riesgo,
        h.nombre_hospital,
        f.fecha_solicitud,
        f.fecha_resolucion,
        -- Cálculo de tiempo de resolución en horas
        ROUND(EXTRACT(EPOCH FROM (f.fecha_resolucion - f.fecha_solicitud)) / 3600, 2) AS horas_resolucion,
        f.horas_paro_equipo,
        CASE 
            WHEN EXTRACT(EPOCH FROM (f.fecha_resolucion - f.fecha_solicitud)) / 3600 <= 24.0 THEN 1 
            ELSE 0 
        END AS dentro_sla_24h
    FROM FactServiceOrders f
    INNER JOIN DimEquipment e ON f.id_equipo = e.id_equipo
    INNER JOIN DimHospital h ON f.id_hospital = h.id_hospital
    WHERE f.tipo_servicio = 'Correctivo'
)
SELECT 
    modalidad,
    COUNT(id_orden) AS total_correctivos,
    SUM(dentro_sla_24h) AS ordenes_dentro_sla,
    ROUND((SUM(dentro_sla_24h)::NUMERIC / COUNT(id_orden)) * 100, 2) AS cumplimiento_sla_pct,
    ROUND(AVG(horas_paro_equipo), 2) AS mttr_promedio_horas
FROM ordenes_enriquecidas
WHERE clase_riesgo = 'Clase III - Soporte de Vida'
GROUP BY modalidad
ORDER BY cumplimiento_sla_pct ASC;


-- 2. Ranking de Fallas Repetitivas por Activo Médico (Window Function)
WITH fallas_por_activo AS (
    SELECT 
        e.id_equipo,
        e.numero_serie,
        e.modalidad,
        COUNT(f.id_orden) AS total_intervenciones,
        SUM(f.costo_refacciones) AS gasto_refacciones_acumulado,
        DENSE_RANK() OVER (
            PARTITION BY e.modalidad 
            ORDER BY COUNT(f.id_orden) DESC
        ) AS ranking_incidencia
    FROM FactServiceOrders f
    INNER JOIN DimEquipment e ON f.id_equipo = e.id_equipo
    GROUP BY e.id_equipo, e.numero_serie, e.modalidad
)
SELECT 
    modalidad,
    numero_serie,
    total_intervenciones,
    gasto_refacciones_acumulado,
    ranking_incidencia
FROM fallas_por_activo
WHERE ranking_incidencia <= 3;
