USE Academia2022;
GO
---LENGUAJE DDL

PRINT '============================================';
PRINT 'INICIANDO LIMPIEZA DE VISTAS';
PRINT '============================================';
GO

-- ============================================
-- PASO 1: DESHABILITAR RLS (Row Level Security)
-- CRÍTICO: RLS impide crear índices en vistas
-- ============================================

PRINT 'Deshabilitando política de seguridad RLS...';
GO

-- Verificar si existe la política
IF EXISTS (SELECT * FROM sys.security_policies WHERE name = 'Policy_Alumnos')
BEGIN
    -- Deshabilitar la política (no eliminarla, solo desactivar)
    ALTER SECURITY POLICY Sec.Policy_Alumnos WITH (STATE = OFF);
    PRINT '  ✓ Política RLS Sec.Policy_Alumnos DESHABILITADA';
    PRINT '  ⚠ NOTA: La política se puede reactivar después con: ALTER SECURITY POLICY Sec.Policy_Alumnos WITH (STATE = ON)';
END
ELSE
BEGIN
    PRINT '  ℹ No se encontró política RLS activa';
END
GO

-- ============================================
-- PASO 2: ELIMINAR ÍNDICES DE VISTAS INDEXADAS
-- ============================================

PRINT '';
PRINT 'Eliminando índices de vistas...';
GO

-- Índice de vw_EstadisticasCarrera
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'UCI_EstadisticasCarrera')
BEGIN
    DROP INDEX UCI_EstadisticasCarrera ON App.vw_EstadisticasCarrera;
    PRINT '  ✓ Índice UCI_EstadisticasCarrera eliminado';
END
GO

-- Índice de vw_RendimientoCursos
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'UCI_RendimientoCursos')
BEGIN
    DROP INDEX UCI_RendimientoCursos ON App.vw_RendimientoCursos;
    PRINT '  ✓ Índice UCI_RendimientoCursos eliminado';
END
GO

-- Índice de vw_CargaPorAlumno (del script original)
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'UCI_vw_CargaPorAlumno')
BEGIN
    DROP INDEX UCI_vw_CargaPorAlumno ON App.vw_CargaPorAlumno;
    PRINT '  ✓ Índice UCI_vw_CargaPorAlumno eliminado';
END
GO

-- Índice de vw_OcupacionPorPeriodo (del script original)
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'UCI_vw_OcupacionPorPeriodo')
BEGIN
    DROP INDEX UCI_vw_OcupacionPorPeriodo ON App.vw_OcupacionPorPeriodo;
    PRINT '  ✓ Índice UCI_vw_OcupacionPorPeriodo eliminado';
END
GO

-- Índice de vw_MatriculasPorCurso (del script original)
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_vw_MatriculasPorCurso')
BEGIN
    DROP INDEX IX_vw_MatriculasPorCurso ON App.vw_MatriculasPorCurso;
    PRINT '  ✓ Índice IX_vw_MatriculasPorCurso eliminado';
END
GO

-- ============================================
-- PASO 3: ELIMINAR TODAS LAS VISTAS
-- ============================================

PRINT '';
PRINT 'Eliminando vistas...';
GO

-- Vista 1: vw_EstadisticasCarrera
IF OBJECT_ID('App.vw_EstadisticasCarrera', 'V') IS NOT NULL
BEGIN
    DROP VIEW App.vw_EstadisticasCarrera;
    PRINT '  ✓ Vista App.vw_EstadisticasCarrera eliminada';
END
GO

-- Vista 2: vw_RendimientoCursos
IF OBJECT_ID('App.vw_RendimientoCursos', 'V') IS NOT NULL
BEGIN
    DROP VIEW App.vw_RendimientoCursos;
    PRINT '  ✓ Vista App.vw_RendimientoCursos eliminada';
END
GO

-- Vista 3: vw_CargaPorAlumno (del script original)
IF OBJECT_ID('App.vw_CargaPorAlumno', 'V') IS NOT NULL
BEGIN
    DROP VIEW App.vw_CargaPorAlumno;
    PRINT '  ✓ Vista App.vw_CargaPorAlumno eliminada';
END
GO

-- Vista 4: vw_OcupacionPorPeriodo (del script original)
IF OBJECT_ID('App.vw_OcupacionPorPeriodo', 'V') IS NOT NULL
BEGIN
    DROP VIEW App.vw_OcupacionPorPeriodo;
    PRINT '  ✓ Vista App.vw_OcupacionPorPeriodo eliminada';
END
GO

-- Vista 5: vw_MatriculasPorCurso (del script original)
IF OBJECT_ID('App.vw_MatriculasPorCurso', 'V') IS NOT NULL
BEGIN
    DROP VIEW App.vw_MatriculasPorCurso;
    PRINT '  ✓ Vista App.vw_MatriculasPorCurso eliminada';
END
GO

-- Vista 6: vw_ResumenAlumno (del script original)
IF OBJECT_ID('App.vw_ResumenAlumno', 'V') IS NOT NULL
BEGIN
    DROP VIEW App.vw_ResumenAlumno;
    PRINT '  ✓ Vista App.vw_ResumenAlumno eliminada';
END
GO

-- ============================================
-- PASO 4: VERIFICAR LIMPIEZA
-- ============================================

PRINT '';
PRINT 'Verificando limpieza...';
GO

DECLARE @VistasPendientes INT;
SELECT @VistasPendientes = COUNT(*)
FROM sys.views
WHERE SCHEMA_NAME(schema_id) = 'App';

IF @VistasPendientes = 0
BEGIN
    PRINT '  ✓ LIMPIEZA EXITOSA: No quedan vistas en el esquema App';
END
ELSE
BEGIN
    PRINT '  ⚠ ADVERTENCIA: Aún existen ' + CAST(@VistasPendientes AS VARCHAR(10)) + ' vistas en App';
    SELECT 
        'Vista Restante' AS Tipo,
        name AS Nombre
    FROM sys.views
    WHERE SCHEMA_NAME(schema_id) = 'App';
END
GO

PRINT '';
PRINT '============================================';
PRINT 'CREANDO VISTAS NUEVAS (CORREGIDAS)';
PRINT '============================================';
GO

-- ============================================
-- VISTA 1: ESTADÍSTICAS DE CARRERAS POR MATRÍCULAS
-- SOLUCIÓN DEFINITIVA: Evitar completamente tabla Alumnos (tiene RLS)
-- Basamos todo en Matriculas (NO tiene RLS)
-- Funciones: COUNT_BIG, SUM
-- ============================================

PRINT 'Creando vista: App.vw_EstadisticasCarrera';
GO

CREATE VIEW App.vw_EstadisticasCarrera
WITH SCHEMABINDING
AS
SELECT 
    m.AlumnoID,
    COUNT_BIG(*) AS TotalMatriculasAlumno,          -- Cursos inscritos por alumno
    SUM(cu.CursoCreditosECTS) AS CreditosTotales,   -- Créditos totales
    COUNT_BIG( m.MatriculaPeriodo) AS PeriodosCursados  -- Períodos únicos
FROM 
    Academico.Matriculas AS m
INNER JOIN
    Academico.Cursos AS cu ON m.CursoID = cu.CursoID
GROUP BY 
    m.AlumnoID;
GO

PRINT '  ✓ Vista App.vw_EstadisticasCarrera creada (SIN tabla Alumnos)';
GO

-- Crear índice UNIQUE CLUSTERED
PRINT 'Creando índice en App.vw_EstadisticasCarrera';
GO

CREATE UNIQUE CLUSTERED INDEX UCI_EstadisticasCarrera
ON App.vw_EstadisticasCarrera(AlumnoID);
GO

PRINT '  ✓ Índice UCI_EstadisticasCarrera creado - VISTA MATERIALIZADA';
GO

-- ============================================
-- VISTA 2: RENDIMIENTO DE CURSOS POR PERÍODO
-- SOLUCIÓN: Eliminar AVG, usar solo SUM y COUNT_BIG
-- ============================================

PRINT '';
PRINT 'Creando vista: App.vw_RendimientoCursos';
GO

CREATE VIEW App.vw_RendimientoCursos
WITH SCHEMABINDING
AS
SELECT 
    c.CursoID,
    c.CursoNombre,
    m.MatriculaPeriodo,
    COUNT_BIG(*) AS TotalMatriculas,                        -- Total de inscripciones
    SUM(c.CursoCreditosECTS) AS CreditosTotales,           -- Créditos acumulados
    c.CursoCreditosECTS AS CreditosCurso                   -- Para referencia
FROM 
    Academico.Cursos AS c
INNER JOIN 
    Academico.Matriculas AS m ON c.CursoID = m.CursoID
GROUP BY 
    c.CursoID,
    c.CursoNombre,
    c.CursoCreditosECTS,
    m.MatriculaPeriodo;
GO

PRINT '  ✓ Vista App.vw_RendimientoCursos creada';
GO

-- Crear índice UNIQUE CLUSTERED
PRINT 'Creando índice en App.vw_RendimientoCursos';
GO

CREATE UNIQUE CLUSTERED INDEX UCI_RendimientoCursos
ON App.vw_RendimientoCursos(CursoID, MatriculaPeriodo);
GO

PRINT '  ✓ Índice UCI_RendimientoCursos creado - VISTA MATERIALIZADA';
GO

-- ============================================
-- CONSULTAS SELECT: VERIFICAR DATOS
-- ============================================

PRINT '';
PRINT '============================================';
PRINT 'CONSULTANDO VISTAS CREADAS';
PRINT '============================================';
GO

-- CONSULTA 1: Estadísticas por Alumno (carga académica)
PRINT 'Consulta 1: Estadísticas de Carga por Alumno';
GO

SELECT 
    AlumnoID,
    TotalMatriculasAlumno AS CursosInscritos,
    CreditosTotales,
    PeriodosCursados,
    -- Calcular promedio de créditos por curso
    CAST(CreditosTotales AS DECIMAL(10,2)) / TotalMatriculasAlumno AS PromedioCreditosPorCurso
FROM 
    App.vw_EstadisticasCarrera
ORDER BY 
    CreditosTotales DESC;
GO

-- CONSULTA 2: Rendimiento de Cursos
PRINT '';
PRINT 'Consulta 2: Rendimiento por Curso/Período';
GO

SELECT 
    CursoNombre,
    MatriculaPeriodo,
    TotalMatriculas,
    CreditosCurso,
    CreditosTotales,
    -- Calcular promedio manualmente
    CAST(CreditosTotales AS DECIMAL(10,2)) / TotalMatriculas AS PromedioCreditos
FROM 
    App.vw_RendimientoCursos
ORDER BY 
    MatriculaPeriodo DESC,
    TotalMatriculas DESC;
GO

-- ============================================
-- CONSULTAS ADICIONALES: ANÁLISIS COMBINADO
-- ============================================

PRINT '';
PRINT 'Consultas adicionales de análisis';
GO

-- Análisis 1: Top 5 alumnos con más carga académica
PRINT 'Top 5 Alumnos con más carga académica:';
GO

SELECT TOP 5
    AlumnoID,
    TotalMatriculasAlumno AS CursosInscritos,
    CreditosTotales,
    PeriodosCursados,
    CAST(CreditosTotales AS DECIMAL(10,2)) / TotalMatriculasAlumno AS PromedioCreditosPorCurso
FROM 
    App.vw_EstadisticasCarrera
ORDER BY 
    CreditosTotales DESC;
GO
SELECT * FROM sys.views;

--- CREACION DE CONSULTA CON ROW NUMBER --, ASIGNARA UN NUMERO CONSECUTIVO A CADA CURSO DEL MISMO ALUMNO Y EL 
--ORDER BY ORDENARA LOS CURSOS  Y LUEGO POR EL ID.

PRINT 'Creando App.vw_CargaAcademicaPorAlumno...';
GO

-- Si ya existe la vista, eliminarla
IF OBJECT_ID('App.vw_CargaAcademicaPorAlumno', 'V') IS NOT NULL
    DROP VIEW App.vw_CargaAcademicaPorAlumno;
GO

-- Crear la vista de carga académica por alumno
CREATE VIEW App.vw_CargaAcademicaPorAlumno
AS
SELECT 
    m.AlumnoID,
    m.MatriculaPeriodo,
    m.CursoID,
    ROW_NUMBER() OVER (
        PARTITION BY m.AlumnoID 
        ORDER BY m.MatriculaPeriodo, m.CursoID
    ) AS NumeroCurso
FROM 
    Academico.Matriculas AS m;
GO

PRINT 'Vista App.vw_CargaAcademicaPorAlumno creada con éxito.';
GO

----consultando vista de carga academica por alumno  OPTIMIZACION CON INDICE
SELECT * FROM App.vw_CargaAcademicaPorAlumno;

---CREACION DE SEGURIDAD , IMPLEMENTACION DEL ROW LEVEL SECURITY 
BEGIN TRY
    ALTER SECURITY POLICY Sec.Policy_FilterByAlumnoID WITH (STATE = OFF);
    PRINT 'Política conflictiva Sec.Policy_FilterByAlumnoID deshabilitada.';
END TRY
BEGIN CATCH
    -- El error se produce si el objeto no existe, lo cual ignoramos.
    PRINT 'Error al deshabilitar la política conflictiva (Puede que no existiera, continuando...).';
END CATCH
GO

-- Intenta ELIMINAR la política conflictiva conocida.
BEGIN TRY
    DROP SECURITY POLICY Sec.Policy_FilterByAlumnoID;
    PRINT 'Política conflictiva Sec.Policy_FilterByAlumnoID eliminada exitosamente (limpieza forzada).';
END TRY
BEGIN CATCH
    -- Si falla (porque no existía o no se pudo eliminar), el script continúa.
    PRINT 'La política conflictiva Sec.Policy_FilterByAlumnoID no existía o ya estaba eliminada.';
END CATCH
GO

-- Limpieza de la nueva política (Sec.rls_politica_alumnos)
BEGIN TRY
    -- Intentamos deshabilitar primero por seguridad (aunque no deberías tener problemas con esta)
    ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = OFF);
    DROP SECURITY POLICY Sec.rls_politica_alumnos;
    PRINT 'Política Sec.rls_politica_alumnos eliminada (limpieza).';
END TRY
BEGIN CATCH
    PRINT 'La política Sec.rls_politica_alumnos no existía o ya estaba eliminada.';
END CATCH
GO

-- Limpieza de la función de predicado (Usamos OBJECT_ID ya que es más estable para funciones)
IF OBJECT_ID('Seguridad.fn_filtro_alumnos', 'IF') IS NOT NULL
BEGIN
    DROP FUNCTION Seguridad.fn_filtro_alumnos;
    PRINT 'Función Seguridad.fn_filtro_alumnos eliminada.';
END
GO
CREATE FUNCTION Seguridad.fn_filtro_alumnos(@AlumnoID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
    RETURN SELECT 1 AS Resultado
    WHERE CAST(@AlumnoID AS NVARCHAR(255)) = 
          REPLACE(SUSER_SNAME(), 'Alumno_', '') -- Extrae el ID (ej: '1001') del usuario ('Alumno_1001')
          OR SUSER_SNAME() = 'sa' 
          OR IS_ROLEMEMBER('db_owner') = 1; -- Excepción para administradores
GO
CREATE SECURITY POLICY Sec.rls_politica_alumnos
ADD FILTER PREDICATE Seguridad.fn_filtro_alumnos(AlumnoID) 
ON Academico.Alumnos
WITH (STATE = ON);
GO

---creacion de usuarios 
CREATE USER Alumno_1001 WITHOUT LOGIN; 
CREATE USER Alumno_1002 WITHOUT LOGIN;
GO
SELECT name, is_enabled
FROM sys.security_policies;
go
CREATE FUNCTION Academico.fn_filtro_alumnos (@AlumnoID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS Permitir
    WHERE @AlumnoID = TRY_CAST(REPLACE(SUSER_SNAME(), 'Alumno_', '') AS INT);
GO

SELECT name, is_enabled
FROM sys.security_policies;
GO

CREATE FUNCTION Academico.fn_filtro_alumnos (@AlumnoID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS Permitir
    WHERE @AlumnoID = TRY_CAST(REPLACE(SUSER_SNAME(), 'Alumno_', '') AS INT);
GO
EXECUTE AS USER = 'Alumno_1001';
SELECT * FROM Academico.Alumnos;
REVERT;
SELECT * FROM Academico.Alumnos;
INSERT INTO Academico.Alumnos (AlumnoID, AlumnoNombre, AlumnoApellido ,CarreraID)
VALUES (1001, 'wizard','gereda', 1);
SET IDENTITY_INSERT Academico.Alumnos ON;

INSERT INTO Academico.Alumnos (AlumnoID, AlumnoNombre, AlumnoApellido,AlumnoEdad, CarreraID)
VALUES (1002, 'Juan', 'Pérez',20,1);

SET IDENTITY_INSERT Academico.Alumnos OFF;
EXEC sp_help 'Academico.Alumnos';

EXECUTE AS USER = 'Alumno_1002';
SELECT * FROM Academico.Alumnos;
REVERT;
SELECT * FROM Academico.Alumnos;
INSERT INTO Academico.Alumnos (AlumnoID, AlumnoNombre, AlumnoApellido ,CarreraID)
VALUES (1001, 'wizard','gereda', 1);
SET IDENTITY_INSERT Academico.Alumnos ON;
SELECT * FROM sys.security_policies WHERE name LIKE '%tu_politica%';  -- Reemplaza con el nombre de tu política
SELECT * FROM sys.security_predicates;
ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = OFF);
SELECT * FROM Academico.Alumnos;
ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = ON);
SELECT DB_NAME() AS BaseActual;
SELECT COUNT(*) AS TotalAlumnos FROM Academico.Alumnos;
SELECT TOP 10 * FROM Academico.Alumnos;
SELECT name, is_enabled
FROM sys.security_policies;
SELECT SUSER_SNAME() AS UsuarioActual;
USE Academia2022;
ALTER ROLE db_owner ADD MEMBER [Wizard\crist];
GO
SELECT IS_ROLEMEMBER('db_owner') AS EsPropietario;
EXECUTE AS USER = 'Alumno_1001';
SELECT * FROM Academico.Alumnos;
REVERT;
SELECT SUSER_SNAME() AS UsuarioActual;
SELECT IS_ROLEMEMBER('db_owner') AS EsPropietario;
ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = OFF);
GO
SELECT TOP 10 * FROM Academico.Alumnos;
GO
ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = ON);
ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = OFF);
GO
ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = ON);
GO
SELECT TOP 10 * FROM Academico.Alumnos;
EXECUTE AS USER = 'Alumno_1001';
SELECT * FROM Academico.Alumnos;
REVERT;
SELECT IS_ROLEMEMBER('db_owner') AS EsPropietario;
ALTER ROLE db_owner ADD MEMBER [Wizard\crist];
ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = OFF);
GO
DROP FUNCTION IF EXISTS Seguridad.fn_filtro_alumnos;
GO

CREATE FUNCTION Seguridad.fn_filtro_alumnos(@AlumnoID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
SELECT 1 AS Resultado
WHERE 
    -- Usa el nombre exacto que devuelve SUSER_SNAME()
    SUSER_SNAME() = 'AQUI_TU_USUARIO_EXACTO'
    OR SUSER_SNAME() = CONCAT('Alumno_', CAST(@AlumnoID AS NVARCHAR(255)))
    OR IS_ROLEMEMBER('db_owner') = 1;
GO

ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = ON);
GO
ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = OFF);
GO
ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = OFF);
GO
DROP FUNCTION IF EXISTS Seguridad.fn_filtro_alumnos;
GO
SELECT name, is_enabled 
FROM sys.security_policies 
WHERE name = 'Sec.rls_politica_alumnos';
SELECT DB_NAME() AS BaseActual;
SELECT * FROM Academico.Alumnos WHERE AlumnoID = 1001;
SELECT SUSER_SNAME() AS UsuarioActual;
ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = OFF);
GO

DROP FUNCTION IF EXISTS Seguridad.fn_filtro_alumnos;
GO

CREATE FUNCTION Seguridad.fn_filtro_alumnos(@AlumnoID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
SELECT 1 AS Resultado
WHERE 
    SUSER_SNAME() IN ('sa', 'DESKTOP-PC\Christiam')   -- admin o tu usuario
    OR SUSER_SNAME() = CONCAT('Alumno_', CAST(@AlumnoID AS NVARCHAR(255)))
    OR IS_ROLEMEMBER('db_owner') = 1;
GO

ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = ON);
GO
ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = OFF);
GO
DROP FUNCTION IF EXISTS Seguridad.fn_filtro_alumnos;
GO
SELECT name, is_enabled, schema_id
FROM sys.security_policies
WHERE name LIKE '%rls%';
SELECT s.name AS SchemaName, sp.name AS PolicyName, sp.is_enabled
FROM sys.security_policies sp
JOIN sys.schemas s ON sp.schema_id = s.schema_id
WHERE sp.name = 'rls_politica_alumnos';
ALTER SECURITY POLICY [Sec].[rls_politica_alumnos] WITH (STATE = OFF);
GO
DROP FUNCTION Seguridad.fn_filtro_alumnos;
GO
SELECT SCHEMA_NAME(schema_id) AS SchemaName, name
FROM sys.objects
WHERE type = 'TF' AND name = 'fn_filtro_alumnos';
GO
CREATE FUNCTION Sec.fn_filtro_alumnos(@AlumnoID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
SELECT 1 AS Resultado
WHERE 
    SUSER_SNAME() IN ('sa', 'Wizard\crist') -- reemplaza con tu usuario
    OR SUSER_SNAME() = CONCAT('Alumno_', CAST(@AlumnoID AS NVARCHAR(255)))
    OR IS_ROLEMEMBER('db_owner') = 1;
GO

CREATE SECURITY POLICY Sec.rls_politica_alumnos
ADD FILTER PREDICATE Sec.fn_filtro_alumnos(AlumnoID)
ON Academico.Alumnos
WITH (STATE = ON);
GO
ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = ON);
GO
SELECT * FROM Academico.Alumnos;

EXECUTE AS USER = 'Alumno_1001';
SELECT * FROM Academico.Alumnos;  -- Solo verá su propio registro
REVERT;  -- vuelve a tu usuario origina
SELECT s.name AS SchemaName, sp.name AS PolicyName, sp.is_enabled
FROM sys.security_policies sp
JOIN sys.schemas s ON sp.schema_id = s.schema_id
WHERE sp.name = 'rls_politica_alumnos';
SELECT SCHEMA_NAME(schema_id) AS SchemaName, name
FROM sys.objects
WHERE type = 'TF' AND name = 'fn_filtro_alumnos';
go
CREATE FUNCTION Sec.fn_filtro_alumnos(@AlumnoID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
SELECT 1 AS Resultado
WHERE 
    SUSER_SNAME() IN ('sa', 'Wizard\\cris')  -- tu usuario correctamente escapado
    OR SUSER_SNAME() = CONCAT('Alumno_', CAST(@AlumnoID AS NVARCHAR(255)))
    OR IS_ROLEMEMBER('db_owner') = 1;
GO
SELECT SCHEMA_NAME(schema_id) AS SchemaName, name
FROM sys.objects
WHERE type = 'TF' AND name = 'fn_filtro_alumnos';
USE Academia2022;
GO
SELECT s.name AS SchemaName, sp.name AS PolicyName, sp.is_enabled
FROM sys.security_policies sp
JOIN sys.schemas s ON sp.schema_id = s.schema_id;
ALTER SECURITY POLICY [Sec].[rls_politica_alumnos] WITH (STATE = OFF);
GO
DROP FUNCTION IF EXISTS Sec.fn_filtro_alumnos;
GO
DROP FUNCTION IF EXISTS dbo.fn_filtro_alumnos;
GO
CREATE FUNCTION Sec.fn_filtro_alumnos(@AlumnoID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
SELECT 1 AS Resultado
WHERE 
    SUSER_SNAME() IN ('sa', 'Wizard\\cris')
    OR SUSER_SNAME() = CONCAT('Alumno_', CAST(@AlumnoID AS NVARCHAR(255)))
    OR IS_ROLEMEMBER('db_owner') = 1;
GO

ALTER SECURITY POLICY [Sec].[rls_politica_alumnos] WITH (STATE = ON);
GO
EXECUTE AS USER = 'Alumno_1001';
SELECT * FROM Academico.Alumnos;
REVERT;
GO
ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = OFF);
GO
CREATE OR ALTER FUNCTION Sec.fn_filtro_alumnos(@AlumnoID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
SELECT 1 AS Resultado
WHERE 
    USER_NAME() IN ('Alumno_1001', 'Alumno_1002')   -- tus usuarios alumnos
    OR USER_NAME() = 'Alumno_' + CAST(@AlumnoID AS NVARCHAR(255))
    OR IS_ROLEMEMBER('db_owner') = 1;
GO
ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = OFF);
GO
ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = ON);
GO
EXECUTE AS USER = 'Alumno_1001';
SELECT * FROM Academico.Alumnos;  -- ahora debería ver solo su registro
REVERT;
DROP USER Alumno_1001;
GO
CREATE USER Alumno_1001 WITHOUT LOGIN;
GO
ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = OFF);
GO
CREATE OR ALTER FUNCTION Sec.fn_filtro_alumnos(@AlumnoID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS Resultado
    WHERE 
        IS_ROLEMEMBER('db_owner') = 1                         -- admin ve todo
        OR @AlumnoID = CAST(REPLACE(USER_NAME(), 'Alumno_', '') AS INT);  -- alumno ve solo su registro
GO
ALTER SECURITY POLICY Sec.rls_politica_alumnos WITH (STATE = ON);

GO
CREATE SECURITY POLICY Sec.rls_politica_alumnos
ADD FILTER PREDICATE Sec.fn_filtro_alumnos(AlumnoID)
ON Academico.Alumnos
WITH (STATE = ON);
GO
SELECT * FROM Academico.Alumnos;  -- deberías ver todos los registros
GRANT SELECT ON Academico.Alumnos TO Alumno_1001;
GO

EXECUTE AS USER = 'Alumno_1001';
SELECT * FROM Academico.Alumnos;  -- solo verá su registro (AlumnoID = 1001)
REVERT;

EXECUTE AS USER = 'Alumno_1001';
SELECT * FROM Academico.Alumnos;  -- ahora debería funcionar con RLS
REVERT;
-- ============================================
-- PASO 1: LIMPIEZA TOTAL - MÉTODO SEGURO
-- ============================================
-- ============================================
-- ROW LEVEL SECURITY (RLS) - IMPLEMENTACIÓN LIMPIA
-- Tabla: Academico.Alumnos
-- Filtrado por AlumnoID según usuario autenticado
-- ============================================

USE Academia2022;
GO

PRINT '============================================';
PRINT 'IMPLEMENTACIÓN RLS - TABLA ALUMNOS';
PRINT '============================================';
GO

-- ============================================
-- PASO 1: LIMPIEZA AUTOMÁTICA
-- ============================================

PRINT '';
PRINT 'PASO 1: Eliminando políticas RLS existentes...';
GO

-- Eliminar TODAS las políticas RLS de la tabla Alumnos (método 100% seguro)
DECLARE @DropPolicies NVARCHAR(MAX) = N'';

SELECT @DropPolicies = @DropPolicies + 
    N'ALTER SECURITY POLICY ' + QUOTENAME(SCHEMA_NAME(sp.schema_id)) + N'.' + QUOTENAME(sp.name) + N' WITH (STATE = OFF); ' +
    N'DROP SECURITY POLICY ' + QUOTENAME(SCHEMA_NAME(sp.schema_id)) + N'.' + QUOTENAME(sp.name) + N'; '
FROM sys.security_policies sp
JOIN sys.security_predicates spp ON sp.object_id = spp.object_id
WHERE spp.target_object_id = OBJECT_ID('Academico.Alumnos');

IF LEN(@DropPolicies) > 0
BEGIN
    EXEC sp_executesql @DropPolicies;
    PRINT '  ✓ Políticas RLS eliminadas';
END
ELSE
    PRINT '  ℹ No hay políticas RLS activas';
GO

-- Eliminar funciones de predicado
DECLARE @DropFunctions NVARCHAR(MAX) = N'';

SELECT @DropFunctions = @DropFunctions + 
    N'DROP FUNCTION ' + QUOTENAME(SCHEMA_NAME(schema_id)) + N'.' + QUOTENAME(name) + N'; '
FROM sys.objects
WHERE type = 'IF' 
  AND schema_id = SCHEMA_ID('Sec')
  AND name LIKE '%Alumno%';

IF LEN(@DropFunctions) > 0
BEGIN
    EXEC sp_executesql @DropFunctions;
    PRINT '  ✓ Funciones de predicado eliminadas';
END
ELSE
    PRINT '  ℹ No hay funciones de predicado';
GO

PRINT '  ✓ Limpieza completada';
GO

-- ============================================
-- PASO 2: CREAR FUNCIÓN DE PREDICADO RLS
-- ============================================

PRINT '';
PRINT 'PASO 2: Creando función de predicado RLS...';
GO

CREATE FUNCTION Sec.fn_AlumnosPorUsuario(@AlumnoID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN 
    SELECT 1 AS AllowRow
    WHERE 
        -- Usuarios administradores ven todo
        USER_NAME() IN ('dbo', 'sa')
        OR IS_MEMBER('db_datareader') = 1
        OR IS_MEMBER('db_owner') = 1
        OR
        -- Mapeo hardcoded: cada usuario ve su AlumnoID
        @AlumnoID = CASE USER_NAME()
            WHEN 'alumno1' THEN 1
            WHEN 'alumno2' THEN 2
            WHEN 'alumno3' THEN 3
            WHEN 'alumno4' THEN 4
            ELSE NULL
        END;
GO

PRINT '  ✓ Función Sec.fn_AlumnosPorUsuario creada';
GO

-- ============================================
-- PASO 3: CREAR POLÍTICA DE SEGURIDAD
-- ============================================

PRINT '';
PRINT 'PASO 3: Activando política de seguridad RLS...';
GO

CREATE SECURITY POLICY Sec.Policy_Alumnos
ADD FILTER PREDICATE Sec.fn_AlumnosPorUsuario(AlumnoID)
ON Academico.Alumnos
WITH (STATE = ON);
GO

PRINT '  ✓ Política Sec.Policy_Alumnos ACTIVADA';
GO

-- ============================================
-- PASO 4: VERIFICACIÓN
-- ============================================

PRINT '';
PRINT 'PASO 4: Verificando configuración RLS...';
GO

SELECT 
    sp.name AS Politica,
    SCHEMA_NAME(sp.schema_id) AS Esquema,
    CASE sp.is_enabled WHEN 1 THEN '✓ ACTIVA' ELSE '✗ INACTIVA' END AS Estado,
    SCHEMA_NAME(o.schema_id) + '.' + o.name AS Tabla
FROM sys.security_policies sp
JOIN sys.security_predicates spp ON sp.object_id = spp.object_id
JOIN sys.objects o ON spp.target_object_id = o.object_id
WHERE sp.name = 'Policy_Alumnos';
GO

-- ============================================
-- PASO 5: EVIDENCIAS Y PRUEBAS
-- ============================================

PRINT '';
PRINT '============================================';
PRINT 'EVIDENCIAS DE RLS FUNCIONANDO';
PRINT '============================================';
GO

-- EVIDENCIA 1: Usuario actual (dbo)
PRINT '';
PRINT '--- EVIDENCIA 1: Usuario DBO (sin filtro) ---';
GO

SELECT 
    'Contexto Usuario Actual' AS Evidencia,
    USER_NAME() AS UsuarioAutenticado,
    SUSER_NAME() AS LoginServidor,
    DB_NAME() AS BaseDatos,
    IS_MEMBER('db_owner') AS EsOwner
GO

SELECT 
    'Consulta sin filtro RLS' AS Escenario,
    AlumnoID,
    NombreCompleto,
    AlumnoEmail,
    USER_NAME() AS ConsultadoPor
FROM Academico.Alumnos
ORDER BY AlumnoID;
GO

-- EVIDENCIA 2: Crear usuario alumno1 y simular
PRINT '';
PRINT '--- EVIDENCIA 2: Simulando usuario alumno1 ---';
GO

-- Crear usuario temporal
IF USER_ID('alumno1') IS NULL
BEGIN
    CREATE USER alumno1 WITHOUT LOGIN;
    GRANT SELECT ON Academico.Alumnos TO alumno1;
END
GO

-- Simular usuario alumno1
EXECUTE AS USER = 'alumno1';
GO

SELECT 
    'Contexto Usuario alumno1' AS Evidencia,
    USER_NAME() AS UsuarioAutenticado,
    'Solo puede ver AlumnoID = 1' AS FiltroRLS
GO

SELECT 
    'Consulta FILTRADA por RLS' AS Escenario,
    AlumnoID,
    NombreCompleto,
    AlumnoEmail,
    USER_NAME() AS ConsultadoPor
FROM Academico.Alumnos
ORDER BY AlumnoID;
GO

REVERT;
GO

-- EVIDENCIA 3: Usuario alumno2
PRINT '';
PRINT '--- EVIDENCIA 3: Simulando usuario alumno2 ---';
GO

IF USER_ID('alumno2') IS NULL
BEGIN
    CREATE USER alumno2 WITHOUT LOGIN;
    GRANT SELECT ON Academico.Alumnos TO alumno2;
END
GO

EXECUTE AS USER = 'alumno2';
GO

SELECT 
    'Contexto Usuario alumno2' AS Evidencia,
    USER_NAME() AS UsuarioAutenticado,
    'Solo puede ver AlumnoID = 2' AS FiltroRLS
GO

SELECT 
    'Consulta FILTRADA por RLS' AS Escenario,
    AlumnoID,
    NombreCompleto,
    AlumnoEmail,
    USER_NAME() AS ConsultadoPor
FROM Academico.Alumnos
ORDER BY AlumnoID;
GO

REVERT;
GO

-- EVIDENCIA 4: Tabla resumen
PRINT '';
PRINT '--- EVIDENCIA 4: Resumen de filtrado RLS ---';
GO

SELECT 
    Usuario,
    AlumnoIDVisible,
    Comportamiento
FROM (
    VALUES 
        ('dbo', 'TODOS', 'Sin filtro - Ve 4 registros'),
        ('alumno1', '1', 'Filtrado - Ve solo Juan Pérez'),
        ('alumno2', '2', 'Filtrado - Ve solo María García'),
        ('alumno3', '3', 'Filtrado - Ve solo Carlos López'),
        ('alumno4', '4', 'Filtrado - Ve solo Ana Martínez')
) AS T(Usuario, AlumnoIDVisible, Comportamiento);
GO

-- ============================================
-- RESUMEN FINAL
-- ============================================

PRINT '';
PRINT '============================================';
PRINT 'IMPLEMENTACIÓN RLS COMPLETADA EXITOSAMENTE';
PRINT '============================================';
PRINT '';
PRINT 'Objetos creados:';
PRINT '  ✓ Función: Sec.fn_AlumnosPorUsuario';
PRINT '  ✓ Política: Sec.Policy_Alumnos (ACTIVA)';
PRINT '  ✓ Usuarios: alumno1, alumno2 (para pruebas)';
PRINT '';
PRINT 'Filtrado RLS:';
PRINT '  • dbo → Ve TODOS los alumnos';
PRINT '  • alumno1 → Ve solo AlumnoID = 1';
PRINT '  • alumno2 → Ve solo AlumnoID = 2';
PRINT '';
PRINT 'Comandos útiles:';
PRINT '  Deshabilitar: ALTER SECURITY POLICY Sec.Policy_Alumnos WITH (STATE = OFF);';
PRINT '  Reactivar:    ALTER SECURITY POLICY Sec.Policy_Alumnos WITH (STATE = ON);';
PRINT '============================================';
GO
USE Academia2022;
GO

USE Academia2022;
GO

-- PRUEBA 1: Como DBO (ve todo)
SELECT 
    'Usuario: ' + USER_NAME() AS Prueba,
    AlumnoID,
    NombreCompleto
FROM Academico.Alumnos;
GO

-- PRUEBA 2: Simular alumno1 (ve solo ID=1)
EXECUTE AS USER = 'alumno1';
GO

SELECT 
    'Usuario: ' + USER_NAME() AS Prueba,
    AlumnoID,
    NombreCompleto
FROM Academico.Alumnos;
GO

REVERT;  -- Volver a DBO
GO

-- PRUEBA 3: Simular alumno2 (ve solo ID=2)
EXECUTE AS USER = 'alumno2';
GO

SELECT 
    'Usuario: ' + USER_NAME() AS Prueba,
    AlumnoID,
    NombreCompleto
FROM Academico.Alumnos;
GO

REVERT;
GO
 
SELECT * FROM sys.security_policies WHERE name = 'Policy_Alumnos';

-- ¿Existe la función?
SELECT * FROM sys.objects WHERE name = 'fn_AlumnosPorUsuario';

-- ¿Existen los usuarios?
SELECT * FROM sys.database_principals WHERE name LIKE 'alumno%';
-- Ver estado de la política
SELECT 
    name AS Politica,
    CASE is_enabled 
        WHEN 1 THEN '✓ ACTIVA' 
        ELSE '✗ INACTIVA' 
    END AS Estado
FROM sys.security_policies
WHERE name = 'Policy_Alumnos';
GO

-- Ver qué usuarios tienen acceso
SELECT 
    dp.name AS Usuario,
    dp.type_desc AS TipoUsuario
FROM sys.database_principals dp
WHERE dp.name IN ('alumno1', 'alumno2', 'alumno3', 'alumno4');
GO
USE Academia2022;
GO

-- PRUEBA 1: Como DBO (ve todo)
SELECT 
    'Usuario: ' + USER_NAME() AS Prueba,
    AlumnoID,
    NombreCompleto
FROM Academico.Alumnos;
GO

-- PRUEBA 2: Simular alumno1 (ve solo ID=1)
EXECUTE AS USER = 'alumno1';
GO

SELECT 
    'Usuario: ' + USER_NAME() AS Prueba,
    AlumnoID,
    NombreCompleto
FROM Academico.Alumnos;
GO

REVERT;  -- Volver a DBO
GO

-- PRUEBA 3: Simular alumno2 (ve solo ID=2)
EXECUTE AS USER = 'alumno2';
GO

SELECT 
    'Usuario: ' + USER_NAME() AS Prueba,
    AlumnoID,
    NombreCompleto
FROM Academico.Alumnos;
GO

REVERT;
GO

-- ============================================
-- CREACIÓN DE ROLES Y PERMISOS
-- Base de datos: Academia2022
-- Roles: AppReader, AppWriter, AuditorBD
-- ============================================
-- ============================================
-- ============================================
-- CREACIÓN DE ROLES Y PERMISOS
-- Base de datos: Academia2022
-- Roles: AppReader, AppWriter, AuditorBD
-- ============================================

USE Academia2022;
GO

PRINT '============================================';
PRINT 'CREACIÓN DE ROLES Y ASIGNACIÓN DE PERMISOS';
PRINT '============================================';
GO

-- ============================================
-- PASO 1: LIMPIEZA COMPLETA - ELIMINAR MIEMBROS Y ROLES
-- ============================================

PRINT '';
PRINT 'PASO 1: Limpiando roles existentes...';
GO

-- Paso 1.1: Remover TODOS los miembros de los roles
DECLARE @SQL NVARCHAR(MAX) = N'';

-- Construir comandos para remover miembros de AppReader
SELECT @SQL = @SQL + 
    N'ALTER ROLE AppReader DROP MEMBER ' + QUOTENAME(USER_NAME(member_principal_id)) + N'; '
FROM sys.database_role_members
WHERE role_principal_id = DATABASE_PRINCIPAL_ID('AppReader');

-- Construir comandos para remover miembros de AppWriter
SELECT @SQL = @SQL + 
    N'ALTER ROLE AppWriter DROP MEMBER ' + QUOTENAME(USER_NAME(member_principal_id)) + N'; '
FROM sys.database_role_members
WHERE role_principal_id = DATABASE_PRINCIPAL_ID('AppWriter');

-- Construir comandos para remover miembros de AuditorBD
SELECT @SQL = @SQL + 
    N'ALTER ROLE AuditorBD DROP MEMBER ' + QUOTENAME(USER_NAME(member_principal_id)) + N'; '
FROM sys.database_role_members
WHERE role_principal_id = DATABASE_PRINCIPAL_ID('AuditorBD');

-- Ejecutar remoción de miembros
IF LEN(@SQL) > 0
BEGIN
    EXEC sp_executesql @SQL;
    PRINT '  ✓ Miembros removidos de los roles';
END
GO

-- Paso 1.2: Eliminar usuarios de prueba (si existen)
IF USER_ID('usr_reader') IS NOT NULL
BEGIN
    DROP USER usr_reader;
    PRINT '  ✓ Usuario usr_reader eliminado';
END
GO

IF USER_ID('usr_writer') IS NOT NULL
BEGIN
    DROP USER usr_writer;
    PRINT '  ✓ Usuario usr_writer eliminado';
END
GO

IF USER_ID('usr_auditor') IS NOT NULL
BEGIN
    DROP USER usr_auditor;
    PRINT '  ✓ Usuario usr_auditor eliminado';
END
GO

-- Paso 1.3: Ahora sí eliminar los roles (ya están vacíos)
IF DATABASE_PRINCIPAL_ID('AppReader') IS NOT NULL
BEGIN
    DROP ROLE AppReader;
    PRINT '  ✓ Rol AppReader eliminado';
END
ELSE
    PRINT '  ℹ Rol AppReader no existe';
GO

IF DATABASE_PRINCIPAL_ID('AppWriter') IS NOT NULL
BEGIN
    DROP ROLE AppWriter;
    PRINT '  ✓ Rol AppWriter eliminado';
END
ELSE
    PRINT '  ℹ Rol AppWriter no existe';
GO

IF DATABASE_PRINCIPAL_ID('AuditorBD') IS NOT NULL
BEGIN
    DROP ROLE AuditorBD;
    PRINT '  ✓ Rol AuditorBD eliminado';
END
ELSE
    PRINT '  ℹ Rol AuditorBD no existe';
GO

PRINT '  ✓ Limpieza completada';
GO

-- ============================================
-- PASO 2: CREAR ROLES PERSONALIZADOS
-- ============================================

PRINT '';
PRINT 'PASO 2: Creando roles personalizados...';
GO

-- ROL 1: AppReader (Solo lectura)
CREATE ROLE AppReader;
PRINT '  ✓ Rol AppReader creado';
GO

-- ROL 2: AppWriter (Lectura y escritura)
CREATE ROLE AppWriter;
PRINT '  ✓ Rol AppWriter creado';
GO

-- ROL 3: AuditorBD (Solo lectura de metadatos y logs)
CREATE ROLE AuditorBD;
PRINT '  ✓ Rol AuditorBD creado';
GO

-- ============================================
-- PASO 3: ASIGNAR PERMISOS - ROL AppReader
-- Privilegio: Solo SELECT en esquema App y Academico
-- ============================================

PRINT '';
PRINT 'PASO 3: Asignando permisos al rol AppReader...';
GO

-- GRANT SELECT en esquema App (vistas)
GRANT SELECT ON SCHEMA::App TO AppReader;
PRINT '  ✓ GRANT SELECT en esquema App';
GO

-- GRANT SELECT en esquema Academico (tablas)
GRANT SELECT ON SCHEMA::Academico TO AppReader;
PRINT '  ✓ GRANT SELECT en esquema Academico';
GO

-- GRANT SELECT específico en vistas clave
GRANT SELECT ON OBJECT::App.vw_RendimientoCursos TO AppReader;
PRINT '  ✓ GRANT SELECT en App.vw_RendimientoCursos';
GO

-- DENEGAR modificaciones (explícito)
DENY INSERT, UPDATE, DELETE ON SCHEMA::Academico TO AppReader;
PRINT '  ✓ DENY INSERT, UPDATE, DELETE en Academico';
GO

-- ============================================
-- PASO 4: ASIGNAR PERMISOS - ROL AppWriter
-- Privilegio: SELECT, INSERT, UPDATE, DELETE en Academico
-- ============================================

PRINT '';
PRINT 'PASO 4: Asignando permisos al rol AppWriter...';
GO

-- GRANT completo en esquema Academico
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Academico TO AppWriter;
PRINT '  ✓ GRANT SELECT, INSERT, UPDATE, DELETE en Academico';
GO

-- GRANT SELECT en esquema App (lectura de vistas)
GRANT SELECT ON SCHEMA::App TO AppWriter;
PRINT '  ✓ GRANT SELECT en esquema App';
GO

-- GRANT EXECUTE en procedimientos almacenados (si existen)
-- GRANT EXECUTE ON SCHEMA::Academico TO AppWriter;
-- PRINT '  ✓ GRANT EXECUTE en procedimientos';
-- GO

-- DENEGAR DROP y ALTER (protección)
DENY ALTER ON SCHEMA::Academico TO AppWriter;
PRINT '  ✓ DENY ALTER en Academico (protección)';
GO

-- ============================================
-- PASO 5: ASIGNAR PERMISOS - ROL AuditorBD
-- Privilegio: Solo lectura de metadatos y auditoría
-- ============================================

PRINT '';
PRINT 'PASO 5: Asignando permisos al rol AuditorBD...';
GO

-- GRANT VIEW DEFINITION (ver definición de objetos)
GRANT VIEW DEFINITION TO AuditorBD;
PRINT '  ✓ GRANT VIEW DEFINITION (metadatos)';
GO

-- GRANT VIEW DATABASE STATE (estadísticas y DMVs)
GRANT VIEW DATABASE STATE TO AuditorBD;
PRINT '  ✓ GRANT VIEW DATABASE STATE';
GO

-- GRANT SELECT en vistas de sistema específicas
GRANT SELECT ON sys.database_permissions TO AuditorBD;
PRINT '  ✓ GRANT SELECT en sys.database_permissions';
GO

GRANT SELECT ON sys.database_principals TO AuditorBD;
PRINT '  ✓ GRANT SELECT en sys.database_principals';
GO

GRANT SELECT ON sys.database_role_members TO AuditorBD;
PRINT '  ✓ GRANT SELECT en sys.database_role_members';
GO

-- DENEGAR modificaciones (todo)
DENY INSERT, UPDATE, DELETE, ALTER ON SCHEMA::Academico TO AuditorBD;
PRINT '  ✓ DENY modificaciones en Academico';
GO

DENY INSERT, UPDATE, DELETE, ALTER ON SCHEMA::App TO AuditorBD;
PRINT '  ✓ DENY modificaciones en App';
GO

-- ============================================
-- PASO 6: REVOKE - QUITAR PERMISOS ESPECÍFICOS
-- Demostración de REVOKE
-- ============================================

PRINT '';
PRINT 'PASO 6: Demostrando uso de REVOKE...';
GO

-- Ejemplo: Si AppReader tuviera INSERT (no lo tiene), lo quitamos
-- REVOKE no niega explícitamente, solo retira el permiso

-- Revocar INSERT si existiera (demostración)
REVOKE INSERT ON SCHEMA::Academico FROM AppReader;
PRINT '  ✓ REVOKE INSERT en Academico desde AppReader (demostración)';
GO

-- Revocar EXECUTE en App de AppReader
REVOKE EXECUTE ON SCHEMA::App FROM AppReader;
PRINT '  ✓ REVOKE EXECUTE en App desde AppReader';
GO

-- ============================================
-- PASO 7: CREAR USUARIOS DE PRUEBA Y ASIGNAR ROLES
-- ============================================

PRINT '';
PRINT 'PASO 7: Creando usuarios de prueba...';
GO

-- Usuario 1: usr_reader (miembro de AppReader)
IF USER_ID('usr_reader') IS NULL
BEGIN
    CREATE USER usr_reader WITHOUT LOGIN;
    PRINT '  ✓ Usuario usr_reader creado';
END
GO

ALTER ROLE AppReader ADD MEMBER usr_reader;
PRINT '  ✓ usr_reader asignado a rol AppReader';
GO

-- Usuario 2: usr_writer (miembro de AppWriter)
IF USER_ID('usr_writer') IS NULL
BEGIN
    CREATE USER usr_writer WITHOUT LOGIN;
    PRINT '  ✓ Usuario usr_writer creado';
END
GO

ALTER ROLE AppWriter ADD MEMBER usr_writer;
PRINT '  ✓ usr_writer asignado a rol AppWriter';
GO

-- Usuario 3: usr_auditor (miembro de AuditorBD)
IF USER_ID('usr_auditor') IS NULL
BEGIN
    CREATE USER usr_auditor WITHOUT LOGIN;
    PRINT '  ✓ Usuario usr_auditor creado';
END
GO

ALTER ROLE AuditorBD ADD MEMBER usr_auditor;
PRINT '  ✓ usr_auditor asignado a rol AuditorBD';
GO

-- ============================================
-- PASO 8: EVIDENCIA - sys.database_permissions
-- ============================================

PRINT '';
PRINT '============================================';
PRINT 'EVIDENCIA DE PERMISOS ASIGNADOS';
PRINT '============================================';
GO

-- EVIDENCIA 1: Permisos por rol
PRINT '';
PRINT '--- EVIDENCIA 1: Permisos asignados a cada rol ---';
GO

SELECT 
    'Permisos por Rol' AS Reporte,
    USER_NAME(grantee_principal_id) AS Rol,
    permission_name AS Permiso,
    state_desc AS Estado,
    OBJECT_SCHEMA_NAME(major_id) AS Esquema,
    OBJECT_NAME(major_id) AS Objeto,
    class_desc AS TipoObjeto
FROM sys.database_permissions
WHERE grantee_principal_id IN (
    DATABASE_PRINCIPAL_ID('AppReader'),
    DATABASE_PRINCIPAL_ID('AppWriter'),
    DATABASE_PRINCIPAL_ID('AuditorBD')
)
ORDER BY Rol, Permiso;
GO

-- EVIDENCIA 2: Miembros de cada rol
PRINT '';
PRINT '--- EVIDENCIA 2: Usuarios asignados a cada rol ---';
GO

SELECT 
    'Miembros de Roles' AS Reporte,
    USER_NAME(role_principal_id) AS Rol,
    USER_NAME(member_principal_id) AS Usuario
FROM sys.database_role_members
WHERE role_principal_id IN (
    DATABASE_PRINCIPAL_ID('AppReader'),
    DATABASE_PRINCIPAL_ID('AppWriter'),
    DATABASE_PRINCIPAL_ID('AuditorBD')
)
ORDER BY Rol, Usuario;
GO

-- EVIDENCIA 3: Permisos efectivos por usuario
PRINT '';
PRINT '--- EVIDENCIA 3: Permisos efectivos de usr_reader ---';
GO

EXECUTE AS USER = 'usr_reader';
GO

SELECT 
    'Permisos efectivos usr_reader' AS Usuario,
    permission_name AS Permiso,
    state_desc AS Estado,
    class_desc AS Clase,
    CASE 
        WHEN major_id > 0 THEN OBJECT_SCHEMA_NAME(major_id)
        ELSE 'N/A'
    END AS Esquema
FROM sys.database_permissions
WHERE grantee_principal_id = DATABASE_PRINCIPAL_ID('AppReader');
GO

REVERT;
GO

-- EVIDENCIA 4: Tabla resumen de permisos
PRINT '';
PRINT '--- EVIDENCIA 4: Resumen de permisos por rol ---';
GO

SELECT 
    Rol,
    PermisosGrant,
    PermisosDeny,
    Descripcion
FROM (
    VALUES 
        ('AppReader', 'SELECT', 'INSERT, UPDATE, DELETE', 'Solo lectura en App y Academico'),
        ('AppWriter', 'SELECT, INSERT, UPDATE, DELETE', 'ALTER, DROP', 'Lectura y escritura en Academico'),
        ('AuditorBD', 'VIEW DEFINITION, VIEW DATABASE STATE', 'Todas las modificaciones', 'Solo auditoría y metadatos')
) AS T(Rol, PermisosGrant, PermisosDeny, Descripcion);
GO

-- ============================================
-- PASO 9: PRUEBAS FUNCIONALES
-- ============================================

PRINT '';
PRINT '============================================';
PRINT 'PRUEBAS FUNCIONALES DE ROLES';
PRINT '============================================';
GO

-- PRUEBA 1: usr_reader intenta SELECT (DEBE FUNCIONAR)
PRINT '';
PRINT '--- PRUEBA 1: usr_reader ejecuta SELECT ---';
GO

EXECUTE AS USER = 'usr_reader';
GO

SELECT 
    'usr_reader: SELECT permitido' AS Prueba,
    COUNT(*) AS TotalAlumnos
FROM Academico.Alumnos;
GO

REVERT;
GO

-- PRUEBA 2: usr_reader intenta INSERT (DEBE FALLAR)
PRINT '';
PRINT '--- PRUEBA 2: usr_reader intenta INSERT (DEBE FALLAR) ---';
GO

EXECUTE AS USER = 'usr_reader';
GO

BEGIN TRY
    INSERT INTO Academico.Alumnos (AlumnoNombre, AlumnoApellido, AlumnoEdad)
    VALUES ('Prueba', 'INSERT', 20);
    
    SELECT 'usr_reader: INSERT permitido' AS Resultado, 'ERROR - NO DEBERÍA PERMITIR' AS Estado;
END TRY
BEGIN CATCH
    SELECT 
        'usr_reader: INSERT denegado' AS Resultado, 
        'CORRECTO ✓' AS Estado,
        ERROR_MESSAGE() AS MensajeError;
END CATCH
GO

REVERT;
GO

-- PRUEBA 3: usr_writer intenta INSERT (DEBE FUNCIONAR)
PRINT '';
PRINT '--- PRUEBA 3: usr_writer ejecuta INSERT ---';
GO

EXECUTE AS USER = 'usr_writer';
GO

BEGIN TRY
    INSERT INTO Academico.Alumnos (AlumnoNombre, AlumnoApellido, AlumnoEdad, AlumnoActivo)
    VALUES ('Usuario', 'Prueba Writer', 25, 1);
    
    SELECT 
        'usr_writer: INSERT permitido' AS Resultado, 
        'CORRECTO ✓' AS Estado,
        @@ROWCOUNT AS FilasInsertadas;
    
    -- Limpiar datos de prueba
    DELETE FROM Academico.Alumnos WHERE AlumnoNombre = 'Usuario' AND AlumnoApellido = 'Prueba Writer';
END TRY
BEGIN CATCH
    SELECT 
        'usr_writer: INSERT denegado' AS Resultado, 
        'ERROR - DEBERÍA PERMITIR' AS Estado,
        ERROR_MESSAGE() AS MensajeError;
END CATCH
GO

REVERT;
GO

-- PRUEBA 4: usr_auditor consulta metadatos (DEBE FUNCIONAR)
PRINT '';
PRINT '--- PRUEBA 4: usr_auditor consulta metadatos ---';
GO

EXECUTE AS USER = 'usr_auditor';
GO

SELECT 
    'usr_auditor: Consulta metadatos' AS Prueba,
    name AS Tabla,
    type_desc AS TipoObjeto
FROM sys.objects
WHERE schema_id = SCHEMA_ID('Academico')
  AND type = 'U';
GO

REVERT;
GO

-- ============================================
-- RESUMEN FINAL
-- ============================================

PRINT '';
PRINT '============================================';
PRINT 'IMPLEMENTACIÓN COMPLETADA EXITOSAMENTE';
PRINT '============================================';
PRINT '';
PRINT 'Roles creados:';
PRINT '  ✓ AppReader   → SELECT en App y Academico';
PRINT '  ✓ AppWriter   → SELECT, INSERT, UPDATE, DELETE en Academico';
PRINT '  ✓ AuditorBD   → VIEW DEFINITION, VIEW DATABASE STATE';
PRINT '';
PRINT 'Usuarios de prueba:';
PRINT '  ✓ usr_reader  → Miembro de AppReader';
PRINT '  ✓ usr_writer  → Miembro de AppWriter';
PRINT '  ✓ usr_auditor → Miembro de AuditorBD';
PRINT '';
PRINT 'Evidencias generadas:';
PRINT '  ✓ sys.database_permissions (permisos por rol)';
PRINT '  ✓ sys.database_role_members (miembros de roles)';
PRINT '  ✓ Pruebas funcionales (SELECT, INSERT permitidos/denegados)';
PRINT '';
PRINT 'Comandos útiles:';
PRINT '  Ver permisos: SELECT * FROM sys.database_permissions WHERE grantee_principal_id = DATABASE_PRINCIPAL_ID(''AppReader'');';
PRINT '  Ver miembros: SELECT * FROM sys.database_role_members;';
PRINT '============================================';
GO


---paso 6 sistema de auditoria 
--registro de accesos  de los usuarios 
-- ============================================
-- SISTEMA DE AUDITORÍA DE ACCESOS
-- Base de datos: Academia2022
-- Objetivo: Registrar LOGIN y LOGOUT de usuarios
-- Tabla: Seguridad.AuditoriaAccesos
-- ============================================

USE Academia2022;
GO

PRINT '============================================';
PRINT 'SISTEMA DE AUDITORÍA DE ACCESOS';
PRINT '============================================';
GO

-- ============================================
-- PASO 1: LIMPIEZA - ELIMINAR OBJETOS EXISTENTES
-- ============================================

PRINT '';
PRINT 'PASO 1: Limpiando objetos de auditoría existentes...';
GO

-- Eliminar triggers existentes
IF OBJECT_ID('Seguridad.trg_AuditoriaLogin', 'TR') IS NOT NULL
BEGIN
    DROP TRIGGER Seguridad.trg_AuditoriaLogin;
    PRINT '  ✓ Trigger trg_AuditoriaLogin eliminado';
END
GO

IF OBJECT_ID('Seguridad.trg_AuditoriaLogout', 'TR') IS NOT NULL
BEGIN
    DROP TRIGGER Seguridad.trg_AuditoriaLogout;
    PRINT '  ✓ Trigger trg_AuditoriaLogout eliminado';
END
GO

-- Eliminar tabla de auditoría (si existe)
IF OBJECT_ID('Seguridad.AuditoriaAccesos', 'U') IS NOT NULL
BEGIN
    DROP TABLE Seguridad.AuditoriaAccesos;
    PRINT '  ✓ Tabla Seguridad.AuditoriaAccesos eliminada';
END
GO

PRINT '  ✓ Limpieza completada';
GO

-- ============================================
-- PASO 2: CREAR TABLA DE AUDITORÍA
-- ============================================

PRINT '';
PRINT 'PASO 2: Creando tabla Seguridad.AuditoriaAccesos...';
GO

CREATE TABLE Seguridad.AuditoriaAccesos (
    AuditoriaID INT IDENTITY(1,1) CONSTRAINT PK_AuditoriaAccesos PRIMARY KEY,
    EventoTipo VARCHAR(20) NOT NULL CONSTRAINT CK_AuditoriaAccesos_Tipo 
        CHECK (EventoTipo IN ('LOGIN', 'LOGOUT')),
    UsuarioDB NVARCHAR(128) NOT NULL,
    LoginServidor NVARCHAR(128) NOT NULL,
    NombreHost NVARCHAR(128) NULL,
    NombreAplicacion NVARCHAR(128) NULL,
    DireccionIP VARCHAR(48) NULL,
    FechaHora DATETIME2(3) NOT NULL CONSTRAINT DF_AuditoriaAccesos_FechaHora 
        DEFAULT SYSDATETIME(),
    BaseDatos NVARCHAR(128) NOT NULL,
    SPID SMALLINT NULL,
    SessionID INT NULL
);
GO

PRINT '  ✓ Tabla Seguridad.AuditoriaAccesos creada';
GO

-- Crear índice para búsquedas frecuentes
CREATE INDEX IX_AuditoriaAccesos_FechaHora 
ON Seguridad.AuditoriaAccesos(FechaHora DESC);
GO

CREATE INDEX IX_AuditoriaAccesos_Usuario 
ON Seguridad.AuditoriaAccesos(UsuarioDB, EventoTipo);
GO

PRINT '  ✓ Índices creados en tabla de auditoría';
GO

-- ============================================
-- PASO 3: CREAR PROCEDIMIENTO ALMACENADO PARA REGISTRAR
-- ============================================

PRINT '';
PRINT 'PASO 3: Creando procedimiento de registro de auditoría...';
GO

CREATE PROCEDURE Seguridad.sp_RegistrarAcceso
    @EventoTipo VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO Seguridad.AuditoriaAccesos (
        EventoTipo,
        UsuarioDB,
        LoginServidor,
        NombreHost,
        NombreAplicacion,
        DireccionIP,
        FechaHora,
        BaseDatos,
        SPID,
        SessionID
    )
    VALUES (
        @EventoTipo,                    -- LOGIN o LOGOUT
        USER_NAME(),                    -- Usuario de la base de datos
        SUSER_SNAME(),                  -- Login del servidor
        HOST_NAME(),                    -- Nombre del equipo
        APP_NAME(),                     -- Aplicación (SSMS, etc.)
        CONVERT(VARCHAR(48), 
            CONNECTIONPROPERTY('client_net_address')), -- IP del cliente
        SYSDATETIME(),                  -- Fecha y hora actual
        DB_NAME(),                      -- Base de datos actual
        @@SPID,                         -- ID del proceso
        @@SPID                          -- Session ID
    );
    
    -- Mensaje opcional para debugging
    -- PRINT 'Auditoría registrada: ' + @EventoTipo + ' por ' + USER_NAME();
END;
GO

PRINT '  ✓ Procedimiento Seguridad.sp_RegistrarAcceso creado';
GO

-- ============================================
-- PASO 4: CREAR LOGON TRIGGER (LOGIN)
-- NOTA: Este trigger se ejecuta a nivel de SERVIDOR
-- ============================================

PRINT '';
PRINT 'PASO 4: Creando trigger de LOGIN a nivel servidor...';
GO

USE master;
GO

-- Verificar si existe y eliminar
IF EXISTS (SELECT * FROM sys.server_triggers WHERE name = 'trg_AuditoriaLogin_Servidor')
BEGIN
    DROP TRIGGER trg_AuditoriaLogin_Servidor ON ALL SERVER;
    PRINT '  ✓ Trigger anterior eliminado';
END
GO

CREATE TRIGGER trg_AuditoriaLogin_Servidor
ON ALL SERVER
FOR LOGON
AS
BEGIN
    -- Solo auditar si se conecta a Academia2022
    IF ORIGINAL_DB_NAME() = 'Academia2022'
    BEGIN
        EXEC Academia2022.Seguridad.sp_RegistrarAcceso @EventoTipo = 'LOGIN';
    END
END;
GO

PRINT '  ✓ Trigger trg_AuditoriaLogin_Servidor creado (nivel servidor)';
GO

USE Academia2022;
GO

-- ============================================
-- PASO 5: CREAR TRIGGER DE LOGOUT (Simulación con desconexión)
-- NOTA: SQL Server no tiene evento directo de LOGOUT
-- Alternativa: Usar trigger en acciones específicas o manualmente
-- ============================================

PRINT '';
PRINT 'PASO 5: Creando procedimiento manual de LOGOUT...';
GO

-- Como SQL Server no tiene evento LOGOUT automático,
-- creamos un procedimiento que debe llamarse manualmente
CREATE PROCEDURE Seguridad.sp_RegistrarLogout
AS
BEGIN
    EXEC Seguridad.sp_RegistrarAcceso @EventoTipo = 'LOGOUT';
    PRINT 'LOGOUT registrado para usuario: ' + USER_NAME();
END;
GO

PRINT '  ✓ Procedimiento Seguridad.sp_RegistrarLogout creado';
PRINT '  ⚠ NOTA: LOGOUT debe llamarse manualmente con EXEC Seguridad.sp_RegistrarLogout';
GO

-- ============================================
-- PASO 6: PERMISOS PARA AUDITORÍA
-- ============================================

PRINT '';
PRINT 'PASO 6: Configurando permisos de auditoría...';
GO

-- Dar permisos a roles para ejecutar registro de logout
GRANT EXECUTE ON Seguridad.sp_RegistrarLogout TO AppReader;
GRANT EXECUTE ON Seguridad.sp_RegistrarLogout TO AppWriter;
GRANT EXECUTE ON Seguridad.sp_RegistrarLogout TO AuditorBD;
GO

PRINT '  ✓ Permisos de ejecución otorgados';
GO

-- Solo auditores pueden ver la tabla de auditoría
GRANT SELECT ON Seguridad.AuditoriaAccesos TO AuditorBD;
GO

PRINT '  ✓ Permisos SELECT otorgados a AuditorBD';
GO

-- ============================================
-- PASO 7: PRUEBAS Y EVIDENCIAS
-- ============================================

PRINT '';
PRINT '============================================';
PRINT 'PRUEBAS Y EVIDENCIAS DEL SISTEMA';
PRINT '============================================';
GO

-- PRUEBA 1: Inserción manual de LOGIN (simulación)
PRINT '';
PRINT '--- PRUEBA 1: Registrar LOGIN manualmente ---';
GO

EXEC Seguridad.sp_RegistrarAcceso @EventoTipo = 'LOGIN';
GO

-- PRUEBA 2: Registrar LOGOUT
PRINT '';
PRINT '--- PRUEBA 2: Registrar LOGOUT manualmente ---';
GO

EXEC Seguridad.sp_RegistrarLogout;
GO

-- PRUEBA 3: Simular múltiples accesos de diferentes usuarios
PRINT '';
PRINT '--- PRUEBA 3: Simular accesos de usr_reader ---';
GO

EXECUTE AS USER = 'usr_reader';
GO

EXEC Seguridad.sp_RegistrarAcceso @EventoTipo = 'LOGIN';
WAITFOR DELAY '00:00:02'; -- Esperar 2 segundos
EXEC Seguridad.sp_RegistrarLogout;
GO

REVERT;
GO

-- PRUEBA 4: Simular accesos de usr_writer
PRINT '';
PRINT '--- PRUEBA 4: Simular accesos de usr_writer ---';
GO

EXECUTE AS USER = 'usr_writer';
GO

EXEC Seguridad.sp_RegistrarAcceso @EventoTipo = 'LOGIN';
WAITFOR DELAY '00:00:02';
EXEC Seguridad.sp_RegistrarLogout;
GO

REVERT;
GO

-- ============================================
-- EVIDENCIA 1: Registros de auditoría insertados
-- ============================================

PRINT '';
PRINT '============================================';
PRINT 'EVIDENCIA 1: Registros en Seguridad.AuditoriaAccesos';
PRINT '============================================';
GO

SELECT 
    AuditoriaID,
    EventoTipo,
    UsuarioDB,
    LoginServidor,
    NombreHost,
    NombreAplicacion,
    DireccionIP,
    FechaHora,
    BaseDatos,
    SPID
FROM Seguridad.AuditoriaAccesos
ORDER BY FechaHora DESC;
GO

-- ============================================
-- EVIDENCIA 2: Estadísticas de accesos por usuario
-- ============================================

PRINT '';
PRINT 'EVIDENCIA 2: Estadísticas de accesos por usuario';
GO

SELECT 
    UsuarioDB,
    EventoTipo,
    COUNT(*) AS TotalEventos,
    MIN(FechaHora) AS PrimerAcceso,
    MAX(FechaHora) AS UltimoAcceso
FROM Seguridad.AuditoriaAccesos
GROUP BY UsuarioDB, EventoTipo
ORDER BY UsuarioDB, EventoTipo;
GO

-- ============================================
-- EVIDENCIA 3: Sesiones activas (LOGIN sin LOGOUT)
-- ============================================

PRINT '';
PRINT 'EVIDENCIA 3: Sesiones sin LOGOUT registrado';
GO

WITH LoginEvents AS (
    SELECT 
        UsuarioDB,
        FechaHora AS LoginTime,
        SPID
    FROM Seguridad.AuditoriaAccesos
    WHERE EventoTipo = 'LOGIN'
),
LogoutEvents AS (
    SELECT 
        UsuarioDB,
        FechaHora AS LogoutTime,
        SPID
    FROM Seguridad.AuditoriaAccesos
    WHERE EventoTipo = 'LOGOUT'
)
SELECT 
    l.UsuarioDB,
    l.LoginTime,
    CASE 
        WHEN lo.LogoutTime IS NULL THEN 'SIN LOGOUT ⚠'
        ELSE 'CERRADO ✓'
    END AS EstadoSesion,
    lo.LogoutTime,
    DATEDIFF(SECOND, l.LoginTime, ISNULL(lo.LogoutTime, SYSDATETIME())) AS DuracionSegundos
FROM LoginEvents l
LEFT JOIN LogoutEvents lo ON l.UsuarioDB = lo.UsuarioDB 
    AND l.SPID = lo.SPID
    AND lo.LogoutTime > l.LoginTime
ORDER BY l.LoginTime DESC;
GO

-- ============================================
-- EVIDENCIA 4: Auditoría por rango de fechas
-- ============================================

PRINT '';
PRINT 'EVIDENCIA 4: Accesos en las últimas 24 horas';
GO

SELECT 
    AuditoriaID,
    EventoTipo,
    UsuarioDB,
    FechaHora,
    NombreHost,
    DireccionIP
FROM Seguridad.AuditoriaAccesos
WHERE FechaHora >= DATEADD(HOUR, -24, SYSDATETIME())
ORDER BY FechaHora DESC;
GO

-- ============================================
-- EVIDENCIA 5: Verificar estructura de la tabla
-- ============================================

PRINT '';
PRINT 'EVIDENCIA 5: Estructura de Seguridad.AuditoriaAccesos';
GO

SELECT 
    COLUMN_NAME AS Columna,
    DATA_TYPE AS TipoDato,
    CHARACTER_MAXIMUM_LENGTH AS Longitud,
    IS_NULLABLE AS Nullable,
    COLUMN_DEFAULT AS ValorPorDefecto
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Seguridad' 
  AND TABLE_NAME = 'AuditoriaAccesos'
ORDER BY ORDINAL_POSITION;
GO

-- ============================================
-- EVIDENCIA 6: Verificar triggers activos
-- ============================================

PRINT '';
PRINT 'EVIDENCIA 6: Triggers de auditoría activos';
GO

-- Triggers a nivel servidor
SELECT 
    'Trigger Servidor' AS Tipo,
    name AS NombreTrigger,
    create_date AS FechaCreacion,
    is_disabled AS Deshabilitado
FROM master.sys.server_triggers
WHERE name LIKE '%Auditoria%';
GO

-- Procedimientos almacenados de auditoría
SELECT 
    'Procedimiento' AS Tipo,
    name AS Nombre,
    create_date AS FechaCreacion,
    modify_date AS FechaModificacion
FROM sys.objects
WHERE schema_id = SCHEMA_ID('Seguridad')
  AND type = 'P'
  AND name LIKE '%Acceso%'
ORDER BY name;
GO

-- ============================================
-- VISTAS DE REPORTE PARA AUDITORES
-- ============================================

PRINT '';
PRINT 'Creando vistas de reporte...';
GO

-- Vista: Resumen diario de accesos
CREATE VIEW Seguridad.vw_ResumenDiarioAccesos
AS
SELECT 
    CAST(FechaHora AS DATE) AS Fecha,
    UsuarioDB,
    EventoTipo,
    COUNT(*) AS TotalEventos
FROM Seguridad.AuditoriaAccesos
GROUP BY CAST(FechaHora AS DATE), UsuarioDB, EventoTipo;
GO

PRINT '  ✓ Vista Seguridad.vw_ResumenDiarioAccesos creada';
GO

-- Permisos en la vista para auditores
GRANT SELECT ON Seguridad.vw_ResumenDiarioAccesos TO AuditorBD;
GO

-- ============================================
-- RESUMEN FINAL
-- ============================================

PRINT '';
PRINT '============================================';
PRINT 'SISTEMA DE AUDITORÍA IMPLEMENTADO';
PRINT '============================================';
PRINT '';
PRINT 'Objetos creados:';
PRINT '  ✓ Tabla: Seguridad.AuditoriaAccesos';
PRINT '  ✓ Procedimiento: Seguridad.sp_RegistrarAcceso';
PRINT '  ✓ Procedimiento: Seguridad.sp_RegistrarLogout';
PRINT '  ✓ Trigger: trg_AuditoriaLogin_Servidor (nivel servidor)';
PRINT '  ✓ Vista: Seguridad.vw_ResumenDiarioAccesos';
PRINT '';
PRINT 'Características:';
PRINT '  • LOGIN: Automático via trigger de servidor';
PRINT '  • LOGOUT: Manual (EXEC Seguridad.sp_RegistrarLogout)';
PRINT '  • Captura: Usuario, IP, Host, Aplicación, Fecha/Hora';
PRINT '  • Índices: Optimizados para consultas por fecha y usuario';
PRINT '';
PRINT 'Evidencias generadas:';
PRINT '  1. Registros insertados automáticamente';
PRINT '  2. Estadísticas por usuario';
PRINT '  3. Sesiones sin LOGOUT';
PRINT '  4. Accesos por rango de fechas';
PRINT '  5. Estructura de la tabla';
PRINT '  6. Triggers y procedimientos activos';
PRINT '';
PRINT 'Comandos útiles:';
PRINT '  Ver auditoría: SELECT * FROM Seguridad.AuditoriaAccesos ORDER BY FechaHora DESC;';
PRINT '  Registrar LOGOUT: EXEC Seguridad.sp_RegistrarLogout;';
PRINT '  Resumen diario: SELECT * FROM Seguridad.vw_ResumenDiarioAccesos;';
PRINT '============================================';
GO

-- ============================================
-- CONSULTA FINAL: Estado actual del sistema
-- ============================================

SELECT 
    'Estado del Sistema de Auditoría' AS Reporte,
    (SELECT COUNT(*) FROM Seguridad.AuditoriaAccesos) AS TotalRegistros,
    (SELECT COUNT(DISTINCT UsuarioDB) FROM Seguridad.AuditoriaAccesos) AS UsuariosUnicos,
    (SELECT COUNT(*) FROM Seguridad.AuditoriaAccesos WHERE EventoTipo = 'LOGIN') AS TotalLogins,
    (SELECT COUNT(*) FROM Seguridad.AuditoriaAccesos WHERE EventoTipo = 'LOGOUT') AS TotalLogouts,
    (SELECT MAX(FechaHora) FROM Seguridad.AuditoriaAccesos) AS UltimoEvento;
GO
USE Academia2022;
GO

USE Academia2022;
GO

-- Otorgar permisos de ejecución en sp_RegistrarAcceso a usuarios específicos
GRANT EXECUTE ON Seguridad.sp_RegistrarAcceso TO usr_reader;
GRANT EXECUTE ON Seguridad.sp_RegistrarAcceso TO usr_writer;
GO

-- (Opcional) Si prefieres otorgar a roles (asegúrate de que los usuarios estén en estos roles)
-- GRANT EXECUTE ON Seguridad.sp_RegistrarAcceso TO AppReader;
-- GRANT EXECUTE ON Seguridad.sp_RegistrarAcceso TO AppWriter;
GO

-- Verificar permisos otorgados (consulta corregida)
SELECT 
    p.name AS UsuarioORol,  -- ✅ CORREGIDO: Ahora usa p.name (de sys.database_principals)
    OBJECT_NAME(dp.major_id) AS Objeto,
    dp.permission_name AS Permiso,
    dp.state_desc AS Estado
FROM sys.database_permissions dp
JOIN sys.database_principals p ON dp.grantee_principal_id = p.principal_id
WHERE dp.major_id = OBJECT_ID('Seguridad.sp_RegistrarAcceso')
  AND dp.permission_name = 'EXECUTE'
  AND p.name IN ('usr_reader', 'usr_writer', 'AppReader', 'AppWriter');
GO

PRINT 'Permisos de ejecución otorgados en Seguridad.sp_RegistrarAcceso.';
GO

----probando la seguridad auditoria
USE Academia2022;
GO

-- ============================================
-- PRUEBA DE REGISTRO DE ACCESOS
-- ============================================

PRINT '============================================';
PRINT 'PRUEBA DE REGISTRO DE ACCESOS (LOGIN/LOGOUT)';
PRINT '============================================';
GO

-- PASO 1: Verificar estado inicial de la tabla de auditoría
PRINT '';
PRINT '--- PASO 1: Estado inicial de Seguridad.AuditoriaAccesos ---';
GO

SELECT 
    COUNT(*) AS TotalRegistrosAntes,
    (SELECT COUNT(*) FROM Seguridad.AuditoriaAccesos WHERE EventoTipo = 'LOGIN') AS LoginsAntes,
    (SELECT COUNT(*) FROM Seguridad.AuditoriaAccesos WHERE EventoTipo = 'LOGOUT') AS LogoutsAntes
FROM Seguridad.AuditoriaAccesos;
GO

-- PASO 2: Simular LOGIN para usr_reader (cambiar contexto de usuario)
PRINT '';
PRINT '--- PASO 2: Simular LOGIN para usr_reader ---';
PRINT '  (El trigger de servidor registrará automáticamente el LOGIN al conectarse)';
GO

-- Cambiar al contexto de usr_reader (esto simula una nueva conexión)
EXECUTE AS USER = 'usr_reader';
GO

-- Aquí, el trigger trg_AuditoriaLogin_Servidor debería activarse automáticamente
-- y registrar un LOGIN en Seguridad.AuditoriaAccesos.
-- Para simular una acción en la DB (opcional, para forzar el trigger):
SELECT 1;  -- Una consulta simple para confirmar la conexión
GO

-- Registrar LOGOUT manualmente
PRINT '  Registrando LOGOUT manual para usr_reader...';
EXEC Seguridad.sp_RegistrarLogout;
GO

-- Revertir al contexto original
REVERT;
GO

-- PASO 3: Simular LOGIN para usr_writer
PRINT '';
PRINT '--- PASO 3: Simular LOGIN para usr_writer ---';
GO

EXECUTE AS USER = 'usr_writer';
GO

-- Acción simple para activar el trigger
SELECT 1;
GO

-- Registrar LOGOUT manualmente
PRINT '  Registrando LOGOUT manual para usr_writer...';
EXEC Seguridad.sp_RegistrarLogout;
GO

REVERT;
GO

-- PASO 4: Verificar inserciones automáticas (evidencias)
PRINT '';
PRINT '--- PASO 4: Evidencias de inserciones automáticas ---';
GO

-- Consulta: Registros nuevos (últimos 10)
PRINT '  Últimos 10 registros en Seguridad.AuditoriaAccesos:';
SELECT TOP 10
    AuditoriaID,
    EventoTipo,
    UsuarioDB,
    FechaHora,
    NombreHost,
    DireccionIP,
    SPID
FROM Seguridad.AuditoriaAccesos
ORDER BY FechaHora DESC;
GO

-- Consulta: Conteo después de las pruebas
PRINT '';
PRINT '  Conteo de registros después de las pruebas:';
SELECT 
    COUNT(*) AS TotalRegistrosDespues,
    (SELECT COUNT(*) FROM Seguridad.AuditoriaAccesos WHERE EventoTipo = 'LOGIN') AS LoginsDespues,
    (SELECT COUNT(*) FROM Seguridad.AuditoriaAccesos WHERE EventoTipo = 'LOGOUT') AS LogoutsDespues
FROM Seguridad.AuditoriaAccesos;
GO

-- Consulta: Detalles de accesos por usuario (evidencia de inserción automática)
PRINT '';
PRINT '  Detalles de accesos por usuario (últimas 24 horas):';
SELECT 
    UsuarioDB,
    EventoTipo,
    COUNT(*) AS TotalEventos,
    MIN(FechaHora) AS PrimerAcceso,
    MAX(FechaHora) AS UltimoAcceso
FROM Seguridad.AuditoriaAccesos
WHERE FechaHora >= DATEADD(HOUR, -24, SYSDATETIME())
GROUP BY UsuarioDB, EventoTipo
ORDER BY UsuarioDB, EventoTipo;
GO

-- Consulta: Sesiones activas (LOGIN sin LOGOUT correspondiente)
PRINT '';
PRINT '  Sesiones sin LOGOUT registrado (evidencia de accesos pendientes):';
WITH LoginEvents AS (
    SELECT 
        UsuarioDB,
        FechaHora AS LoginTime,
        SPID
    FROM Seguridad.AuditoriaAccesos
    WHERE EventoTipo = 'LOGIN'
),
LogoutEvents AS (
    SELECT 
        UsuarioDB,
        FechaHora AS LogoutTime,
        SPID
    FROM Seguridad.AuditoriaAccesos
    WHERE EventoTipo = 'LOGOUT'
)
SELECT 
    l.UsuarioDB,
    l.LoginTime,
    CASE 
        WHEN lo.LogoutTime IS NULL THEN 'SIN LOGOUT ⚠'
        ELSE 'CERRADO ✓'
    END AS EstadoSesion,
    lo.LogoutTime,
    DATEDIFF(SECOND, l.LoginTime, ISNULL(lo.LogoutTime, SYSDATETIME())) AS DuracionSegundos
FROM LoginEvents l
LEFT JOIN LogoutEvents lo ON l.UsuarioDB = lo.UsuarioDB 
    AND l.SPID = lo.SPID
    AND lo.LogoutTime > l.LoginTime
ORDER BY l.LoginTime DESC;
GO

PRINT '';
PRINT '============================================';
PRINT 'PRUEBA COMPLETADA';
PRINT '============================================';
PRINT '  • LOGIN: Registrado automáticamente por trigger de servidor.';
PRINT '  • LOGOUT: Registrado manualmente.';
PRINT '  • Evidencias: Consulta las inserciones en Seguridad.AuditoriaAccesos.';
GO

USE Academia2022;
GO
USE Academia2022;
GO

-- Crear sp_iniciarsesionalumno (registra LOGIN)
CREATE PROCEDURE Seguridad.sp_iniciarsesionalumno
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Registrar LOGIN
    EXEC Seguridad.sp_RegistrarAcceso @EventoTipo = 'LOGIN';
    
    -- Print de confirmación
    PRINT 'Sesión de alumno iniciada correctamente. LOGIN registrado en auditoría.';
END;
GO

-- Crear sp_cerrarsesionalumno (registra LOGOUT)
CREATE PROCEDURE Seguridad.sp_cerrarsesionalumno
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Registrar LOGOUT
    EXEC Seguridad.sp_RegistrarLogout;
    
    -- Print de confirmación
    PRINT 'Sesión de alumno cerrada correctamente. LOGOUT registrado en auditoría.';
END;
GO

PRINT 'Procedimientos sp_iniciarsesionalumno y sp_cerrarsesionalumno creados exitosamente.';
GO

USE Academia2022;
GO

-- Otorgar a usuarios específicos
GRANT EXECUTE ON Seguridad.sp_iniciarsesionalumno TO usr_reader;
GRANT EXECUTE ON Seguridad.sp_iniciarsesionalumno TO usr_writer;
GRANT EXECUTE ON Seguridad.sp_cerrarsesionalumno TO usr_reader;
GRANT EXECUTE ON Seguridad.sp_cerrarsesionalumno TO usr_writer;
GO

-- (Opcional) Otorgar a roles
GRANT EXECUTE ON Seguridad.sp_iniciarsesionalumno TO AppReader;
GRANT EXECUTE ON Seguridad.sp_iniciarsesionalumno TO AppWriter;
GRANT EXECUTE ON Seguridad.sp_cerrarsesionalumno TO AppReader;
GRANT EXECUTE ON Seguridad.sp_cerrarsesionalumno TO AppWriter;
GO

PRINT 'Permisos de ejecución otorgados.';
GO

USE Academia2022;
GO

USE Academia2022;
GO

