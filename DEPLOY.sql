

USE master;
GO

PRINT '============================================';
PRINT 'INICIANDO  Academia2022';
PRINT '============================================';
GO



PRINT '';
PRINT 'FASE 1: Limpieza y creacion de base de datos';
GO

IF DB_ID('Academia2022') IS NOT NULL
BEGIN
    ALTER DATABASE Academia2022 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Academia2022;
    PRINT '  Base de datos existente eliminada';
END
GO

CREATE DATABASE Academia2022;
PRINT '  Base de datos Academia2022 creada';
GO

USE Academia2022;
GO

-- Configurar READ_COMMITTED_SNAPSHOT
ALTER DATABASE Academia2022 SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
PRINT '  READ_COMMITTED_SNAPSHOT habilitado';
GO



PRINT '';
PRINT 'FASE 2: Creacion de esquemas';
GO

CREATE SCHEMA Academico;
GO
PRINT '  Esquema Academico creado';
GO

CREATE SCHEMA Seguridad;
GO
PRINT '  Esquema Seguridad creado';
GO

CREATE SCHEMA App;
GO
PRINT '  Esquema App creado';
GO

CREATE SCHEMA Lab;
GO
PRINT '  Esquema Lab creado';
GO

CREATE SCHEMA Sec;
GO
PRINT '  Esquema Sec creado';
GO



PRINT '';
PRINT 'FASE 3: Creacion de tablas base';
GO

-- Tabla Carreras
CREATE TABLE Academico.Carreras(
    CarreraID INT IDENTITY(1,1) CONSTRAINT PK_Carreras PRIMARY KEY,
    CarreraNombre NVARCHAR(80) NOT NULL CONSTRAINT UQ_Carreras_Nombre UNIQUE
);
PRINT '  Tabla Academico.Carreras creada';
GO

-- Tabla Contactos
CREATE TABLE Academico.Contactos(
    ContactoID INT IDENTITY(1,1) CONSTRAINT PK_Contactos PRIMARY KEY,
    Email NVARCHAR(120) NULL CONSTRAINT UQ_Contactos_Email UNIQUE,
    Telefono VARCHAR(20) NULL
);
PRINT '  Tabla Academico.Contactos creada';
GO

-- Tabla Alumnos
CREATE TABLE Academico.Alumnos(
    AlumnoID INT IDENTITY(1,1) CONSTRAINT PK_Alumnos PRIMARY KEY,
    AlumnoNombre NVARCHAR(60) NOT NULL,
    AlumnoApellido NVARCHAR(60) NOT NULL,
    AlumnoEmail NVARCHAR(120) NULL CONSTRAINT UQ_Alumnos_Email UNIQUE,
    AlumnoEdad TINYINT NOT NULL CONSTRAINT CK_Alumno_Edad CHECK (AlumnoEdad >= 16),
    AlumnoActivo BIT NOT NULL CONSTRAINT DF_Alumno_Activo DEFAULT (1),
    CarreraID INT NULL,
    ContactoID INT NULL
);
PRINT '  Tabla Academico.Alumnos creada';
GO

-- Agregar FKs a Alumnos
ALTER TABLE Academico.Alumnos
ADD CONSTRAINT FK_Alumnos_Carreras
FOREIGN KEY (CarreraID) REFERENCES Academico.Carreras(CarreraID)
ON DELETE SET NULL ON UPDATE NO ACTION;
GO

ALTER TABLE Academico.Alumnos
ADD CONSTRAINT FK_Alumnos_Contactos
FOREIGN KEY (ContactoID) REFERENCES Academico.Contactos(ContactoID);
PRINT '  Constraints FK en Alumnos creadas';
GO

-- Agregar columna calculada
ALTER TABLE Academico.Alumnos
ADD NombreCompleto AS (AlumnoNombre + N' ' + AlumnoApellido) PERSISTED;
PRINT '  Columna calculada NombreCompleto agregada';
GO

-- Indice sobre columna calculada
CREATE INDEX IX_Alumnos_NombreCompleto ON Academico.Alumnos(NombreCompleto);
PRINT '  Indice IX_Alumnos_NombreCompleto creado';
GO

-- Tabla Cursos
CREATE SEQUENCE Academico.SeqCodigoCurso
AS INT START WITH 1000 INCREMENT BY 1;
PRINT '  Sequence Academico.SeqCodigoCurso creada';
GO

CREATE TABLE Academico.Cursos(
    CursoID INT IDENTITY(1,1) CONSTRAINT PK_Cursos PRIMARY KEY,
    CursoNombre NVARCHAR(100) NOT NULL CONSTRAINT UQ_Cursos_Nombre UNIQUE,
    CursoCreditosECTS TINYINT NOT NULL CONSTRAINT CK_Cursos_Creditos CHECK (CursoCreditosECTS BETWEEN 1 AND 10),
    CursoCodigo INT NOT NULL CONSTRAINT DF_Cursos_CursoCodigo DEFAULT (NEXT VALUE FOR Academico.SeqCodigoCurso)
);
PRINT '  Tabla Academico.Cursos creada';
GO

-- Tabla Matriculas
CREATE TABLE Academico.Matriculas(
    AlumnoID INT NOT NULL,
    CursoID INT NOT NULL,
    MatriculaPeriodo CHAR(6) NOT NULL CONSTRAINT CK_Matriculas_Periodo 
    CHECK (MatriculaPeriodo LIKE '[12][0-9][0-9][0-9][S][12]'),
    CONSTRAINT PK_Matriculas PRIMARY KEY (AlumnoID, CursoID, MatriculaPeriodo), 
    CONSTRAINT FK_Matriculas_Alumnos FOREIGN KEY (AlumnoID) 
    REFERENCES Academico.Alumnos(AlumnoID) ON DELETE CASCADE,
    CONSTRAINT FK_Matriculas_Cursos FOREIGN KEY (CursoID)
    REFERENCES Academico.Cursos(CursoID) ON DELETE CASCADE
);
PRINT '  Tabla Academico.Matriculas creada';
GO

-- Indices en Matriculas
CREATE INDEX IX_Matriculas_Cursos_Periodo
ON Academico.Matriculas(CursoID, MatriculaPeriodo)
INCLUDE (AlumnoID);
PRINT '  Indice IX_Matriculas_Cursos_Periodo creado';
GO

CREATE UNIQUE INDEX UQ_Matriculas_Alumno_Curso_Periodo
ON Academico.Matriculas(AlumnoID, CursoID, MatriculaPeriodo);
PRINT '  Indice UQ_Matriculas_Alumno_Curso_Periodo creado';
GO

-- Tabla AlumnoIdiomas
CREATE TABLE Academico.AlumnoIdiomas(
    AlumnoID INT NOT NULL,
    Idioma NVARCHAR(40) NOT NULL,
    Nivel NVARCHAR(20) NOT NULL,
    CONSTRAINT PK_AlumnoIdiomas PRIMARY KEY (AlumnoID, Idioma),
    CONSTRAINT FK_AI_Alumno FOREIGN KEY (AlumnoID)
    REFERENCES Academico.Alumnos(AlumnoID) ON DELETE CASCADE
);
PRINT '  Tabla Academico.AlumnoIdiomas creada';
GO

-- Tabla Eventos (Lab)
CREATE TABLE Lab.Eventos(
    Id INT IDENTITY(1,1) CONSTRAINT PK_Eventos PRIMARY KEY,
    Payload NVARCHAR(MAX) NOT NULL,
    CONSTRAINT CK_Eventos_Payload CHECK (ISJSON(Payload) = 1)
);
PRINT '  Tabla Lab.Eventos creada';
GO

-- Tabla AlumnoRedes (Lab)
CREATE TABLE Lab.AlumnoRedes(
    AlumnoID INT NOT NULL,
    Twitter NVARCHAR(50) SPARSE NULL,
    Instagram NVARCHAR(50) SPARSE NULL,
    CONSTRAINT FK_Redes_Alumno FOREIGN KEY (AlumnoID)
    REFERENCES Academico.Alumnos(AlumnoID) ON DELETE CASCADE
);
PRINT '  Tabla Lab.AlumnoRedes creada';
GO



PRINT '';
PRINT 'FASE 4: Tablas de seguridad y auditoria';
GO

-- Tabla AuditoriaAccesos
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
PRINT '  Tabla Seguridad.AuditoriaAccesos creada';
GO

CREATE INDEX IX_AuditoriaAccesos_FechaHora 
ON Seguridad.AuditoriaAccesos(FechaHora DESC);
GO

CREATE INDEX IX_AuditoriaAccesos_Usuario 
ON Seguridad.AuditoriaAccesos(UsuarioDB, EventoTipo);
PRINT '  Indices de auditoria creados';
GO

-- Tabla AuditoriaBackups
CREATE TABLE Seguridad.AuditoriaBackups (
    BackupID INT IDENTITY(1,1) PRIMARY KEY,
    TipoBackup VARCHAR(20) NOT NULL CHECK (TipoBackup IN ('FULL', 'DIFFERENTIAL', 'LOG')),
    NombreBaseDatos NVARCHAR(128) NOT NULL,
    RutaArchivo NVARCHAR(500) NOT NULL,
    TamanoMB DECIMAL(10,2) NULL,
    FechaInicio DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    FechaFin DATETIME2 NULL,
    DuracionSegundos INT NULL,
    UsuarioEjecuto NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
    Estado VARCHAR(20) NOT NULL DEFAULT 'EN_PROCESO' CHECK (Estado IN ('EN_PROCESO', 'EXITOSO', 'FALLIDO')),
    MensajeError NVARCHAR(MAX) NULL
);
PRINT '  Tabla Seguridad.AuditoriaBackups creada';
GO

CREATE INDEX IX_AuditoriaBackups_Fecha ON Seguridad.AuditoriaBackups(FechaInicio DESC);
CREATE INDEX IX_AuditoriaBackups_Tipo ON Seguridad.AuditoriaBackups(TipoBackup, Estado);
PRINT '  Indices de backup creados';
GO




PRINT '';
PRINT 'FASE 5: Insercion de datos de prueba';
GO

-- Carreras
INSERT INTO Academico.Carreras (CarreraNombre)
VALUES 
    ('Ingenieria en Sistemas'),
    ('Medicina'),
    ('Derecho');
PRINT '  3 carreras insertadas';
GO

-- Cursos
INSERT INTO Academico.Cursos (CursoNombre, CursoCreditosECTS)
VALUES
    ('Calculo Avanzado', 6),
    ('Fisica General', 8),
    ('Programacion', 7),
    ('Base de Datos', 6);
PRINT '  4 cursos insertados';
GO

-- Alumnos
INSERT INTO Academico.Alumnos (AlumnoNombre, AlumnoApellido, AlumnoEmail, AlumnoEdad, AlumnoActivo, CarreraID)
VALUES 
    ('Juan', 'Perez', 'juan.perez@example.com', 20, 1, 1),
    ('Maria', 'Garcia', 'maria.garcia@example.com', 22, 1, 2),
    ('Carlos', 'Lopez', 'carlos.lopez@example.com', 19, 1, 1),
    ('Ana', 'Martinez', 'ana.martinez@example.com', 21, 1, 3);
PRINT '  4 alumnos insertados';
GO

-- Matriculas
INSERT INTO Academico.Matriculas(AlumnoID, CursoID, MatriculaPeriodo)
VALUES 
    (1, 1, '2024S1'),
    (1, 2, '2024S1'),
    (2, 3, '2024S1'),
    (3, 1, '2024S1');
PRINT '  4 matriculas insertadas';
GO



PRINT '';
PRINT 'FASE 6: Creacion de vistas';
GO

-- Vista vw_ResumenAlumno
USE Academia2022;
GO
CREATE VIEW App.vw_ResumenAlumno
AS
SELECT a.AlumnoID, a.NombreCompleto, a.AlumnoEdad, a.CarreraID
FROM Academico.Alumnos a
WHERE a.AlumnoActivo = 1;
GO
PRINT '  Vista App.vw_ResumenAlumno creada';
GO

-- Vista vw_EstadisticasCarrera (SIN TABLA ALUMNOS - EVITA RLS)
USE Academia2022;
GO
CREATE VIEW App.vw_EstadisticasCarrera
WITH SCHEMABINDING
AS
SELECT 
    m.AlumnoID,
    COUNT_BIG(*) AS TotalMatriculasAlumno,
    SUM(cu.CursoCreditosECTS) AS CreditosTotales,
    COUNT_BIG(DISTINCT m.MatriculaPeriodo) AS PeriodosCursados
FROM 
    Academico.Matriculas AS m
INNER JOIN
    Academico.Cursos AS cu ON m.CursoID = cu.CursoID
GROUP BY 
    m.AlumnoID;
    GO
PRINT '  Vista App.vw_EstadisticasCarrera creada';
GO

CREATE UNIQUE CLUSTERED INDEX UCI_EstadisticasCarrera
ON App.vw_EstadisticasCarrera(AlumnoID);
PRINT '  Indice UCI_EstadisticasCarrera creado';
GO

-- Vista vw_RendimientoCursos
USE Academia2022;
GO
CREATE VIEW App.vw_RendimientoCursos
WITH SCHEMABINDING
AS
SELECT 
    c.CursoID,
    c.CursoNombre,
    m.MatriculaPeriodo,
    COUNT_BIG(*) AS TotalMatriculas,
    SUM(c.CursoCreditosECTS) AS CreditosTotales,
    c.CursoCreditosECTS AS CreditosCurso
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
PRINT '  Vista App.vw_RendimientoCursos creada';
GO

CREATE UNIQUE CLUSTERED INDEX UCI_RendimientoCursos
ON App.vw_RendimientoCursos(CursoID, MatriculaPeriodo);
PRINT '  Indice UCI_RendimientoCursos creado';
GO

-- Vista vw_CargaAcademicaPorAlumno
USE Academia2022;
GO
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
PRINT '  Vista App.vw_CargaAcademicaPorAlumno creada';
GO

-- Vista vw_MatriculasPorCurso
USE Academia2022
GO
CREATE VIEW App.vw_MatriculasPorCurso
WITH SCHEMABINDING
AS
SELECT m.CursoID, COUNT_BIG(*) AS Total
FROM Academico.Matriculas AS m
GROUP BY m.CursoID;
GO
PRINT '  Vista App.vw_MatriculasPorCurso creada';
GO

CREATE UNIQUE CLUSTERED INDEX IX_vw_MatriculasPorCurso
ON App.vw_MatriculasPorCurso(CursoID);
PRINT '  Indice IX_vw_MatriculasPorCurso creado';
GO

-- Vista vw_CargaPorAlumno
USE Academia2022
GO
CREATE VIEW App.vw_CargaPorAlumno
WITH SCHEMABINDING
AS
SELECT
    m.AlumnoID,
    m.MatriculaPeriodo,
    COUNT_BIG(*) AS TotalCursos
FROM
    Academico.Matriculas AS m
GROUP BY
    m.AlumnoID, m.MatriculaPeriodo;
    GO
PRINT '  Vista App.vw_CargaPorAlumno creada';
GO

CREATE UNIQUE CLUSTERED INDEX UCI_vw_CargaPorAlumno
ON App.vw_CargaPorAlumno(AlumnoID, MatriculaPeriodo);
PRINT '  Indice UCI_vw_CargaPorAlumno creado';
GO

-- Vista vw_OcupacionPorPeriodo
USE Academia2022;
GO
CREATE VIEW App.vw_OcupacionPorPeriodo
WITH SCHEMABINDING
AS
SELECT
    m.MatriculaPeriodo,
    COUNT_BIG(*) AS TotalMatriculas
FROM
    Academico.Matriculas AS m
GROUP BY
    m.MatriculaPeriodo;
    GO
PRINT '  Vista App.vw_OcupacionPorPeriodo creada';
GO

CREATE UNIQUE CLUSTERED INDEX UCI_vw_OcupacionPorPeriodo
ON App.vw_OcupacionPorPeriodo(MatriculaPeriodo);
PRINT '  Indice UCI_vw_OcupacionPorPeriodo creado';
GO

-- Vista vw_ResumenDiarioAccesos
USE Academia2022;
GO
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
PRINT '  Vista Seguridad.vw_ResumenDiarioAccesos creada';
GO



PRINT '';
PRINT 'FASE 7: Procedimientos almacenados';
GO

-- sp_RegistrarAcceso
CREATE PROCEDURE Seguridad.sp_RegistrarAcceso
    @EventoTipo VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO Seguridad.AuditoriaAccesos (
        EventoTipo, UsuarioDB, LoginServidor, NombreHost,
        NombreAplicacion, DireccionIP, FechaHora, BaseDatos, SPID, SessionID
    )
    VALUES (
        @EventoTipo, USER_NAME(), SUSER_SNAME(), HOST_NAME(),
        APP_NAME(), CONVERT(VARCHAR(48), CONNECTIONPROPERTY('client_net_address')),
        SYSDATETIME(), DB_NAME(), @@SPID, @@SPID
    );
END;
PRINT '  Procedimiento Seguridad.sp_RegistrarAcceso creado';
GO

-- sp_RegistrarLogout
CREATE PROCEDURE Seguridad.sp_RegistrarLogout
AS
BEGIN
    EXEC Seguridad.sp_RegistrarAcceso @EventoTipo = 'LOGOUT';
    PRINT 'LOGOUT registrado para usuario: ' + USER_NAME();
END;
PRINT '  Procedimiento Seguridad.sp_RegistrarLogout creado';
GO

-- sp_iniciarsesionalumno
CREATE PROCEDURE Seguridad.sp_iniciarsesionalumno
AS
BEGIN
    SET NOCOUNT ON;
    EXEC Seguridad.sp_RegistrarAcceso @EventoTipo = 'LOGIN';
    PRINT 'Sesion iniciada: ' + USER_NAME() + ' a las ' + CONVERT(VARCHAR(30), SYSDATETIME(), 120);
END;
PRINT '  Procedimiento Seguridad.sp_iniciarsesionalumno creado';
GO

-- sp_cerrarsesionalumno
CREATE PROCEDURE Seguridad.sp_cerrarsesionalumno
AS
BEGIN
    SET NOCOUNT ON;
    EXEC Seguridad.sp_RegistrarLogout;
    PRINT 'Sesion cerrada: ' + USER_NAME() + ' a las ' + CONVERT(VARCHAR(30), SYSDATETIME(), 120);
END;
PRINT '  Procedimiento Seguridad.sp_cerrarsesionalumno creado';
GO

-- sp_BackupFull
CREATE PROCEDURE Seguridad.sp_BackupFull
    @RutaCarpeta NVARCHAR(500) = 'C:\SQLBackups\'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @BackupID INT;
    DECLARE @NombreArchivo NVARCHAR(500);
    DECLARE @RutaCompleta NVARCHAR(500);
    DECLARE @FechaInicio DATETIME2 = SYSDATETIME();
    
    SET @NombreArchivo = 'Academia2022_FULL_' + FORMAT(SYSDATETIME(), 'yyyyMMdd_HHmmss') + '.bak';
    SET @RutaCompleta = @RutaCarpeta + @NombreArchivo;
    
    BEGIN TRY
        INSERT INTO Seguridad.AuditoriaBackups (TipoBackup, NombreBaseDatos, RutaArchivo, Estado)
        VALUES ('FULL', 'Academia2022', @RutaCompleta, 'EN_PROCESO');
        
        SET @BackupID = SCOPE_IDENTITY();
        
        BACKUP DATABASE Academia2022
        TO DISK = @RutaCompleta
        WITH FORMAT, COMPRESSION, STATS = 10,
            NAME = 'Academia2022-Full',
            DESCRIPTION = 'Backup completo de Academia2022';
        
        DECLARE @TamanoBytes BIGINT;
        EXEC sp_executesql N'
            SELECT @Size = backup_size 
            FROM msdb.dbo.backupset 
            WHERE database_name = ''Academia2022'' 
            AND type = ''D'' 
            ORDER BY backup_finish_date DESC',
            N'@Size BIGINT OUTPUT',
            @Size = @TamanoBytes OUTPUT;
        
        UPDATE Seguridad.AuditoriaBackups
        SET FechaFin = SYSDATETIME(),
            DuracionSegundos = DATEDIFF(SECOND, @FechaInicio, SYSDATETIME()),
            TamanoMB = @TamanoBytes / 1048576.0,
            Estado = 'EXITOSO'
        WHERE BackupID = @BackupID;
        
        PRINT 'BACKUP FULL completado: ' + @NombreArchivo;
    END TRY
    BEGIN CATCH
        UPDATE Seguridad.AuditoriaBackups
        SET FechaFin = SYSDATETIME(), Estado = 'FALLIDO', MensajeError = ERROR_MESSAGE()
        WHERE BackupID = @BackupID;
        
        PRINT 'ERROR en BACKUP FULL: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
PRINT '  Procedimiento Seguridad.sp_BackupFull creado';
GO

-- sp_BackupDifferential
CREATE PROCEDURE Seguridad.sp_BackupDifferential
    @RutaCarpeta NVARCHAR(500) = 'C:\SQLBackups\'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @BackupID INT;
    DECLARE @NombreArchivo NVARCHAR(500);
    DECLARE @RutaCompleta NVARCHAR(500);
    DECLARE @FechaInicio DATETIME2 = SYSDATETIME();
    
    SET @NombreArchivo = 'Academia2022_DIFF_' + FORMAT(SYSDATETIME(), 'yyyyMMdd_HHmmss') + '.bak';
    SET @RutaCompleta = @RutaCarpeta + @NombreArchivo;
    
    BEGIN TRY
        INSERT INTO Seguridad.AuditoriaBackups (TipoBackup, NombreBaseDatos, RutaArchivo, Estado)
        VALUES ('DIFFERENTIAL', 'Academia2022', @RutaCompleta, 'EN_PROCESO');
        
        SET @BackupID = SCOPE_IDENTITY();
        
        BACKUP DATABASE Academia2022
        TO DISK = @RutaCompleta
        WITH DIFFERENTIAL, COMPRESSION, STATS = 10,
            NAME = 'Academia2022-Differential',
            DESCRIPTION = 'Backup diferencial desde ultimo FULL';
        
        DECLARE @TamanoBytes BIGINT;
        EXEC sp_executesql N'
            SELECT @Size = backup_size 
            FROM msdb.dbo.backupset 
            WHERE database_name = ''Academia2022'' 
            AND type = ''I'' 
            ORDER BY backup_finish_date DESC',
            N'@Size BIGINT OUTPUT',
            @Size = @TamanoBytes OUTPUT;
        
        UPDATE Seguridad.AuditoriaBackups
        SET FechaFin = SYSDATETIME(),
            DuracionSegundos = DATEDIFF(SECOND, @FechaInicio, SYSDATETIME()),
            TamanoMB = @TamanoBytes / 1048576.0,
            Estado = 'EXITOSO'
        WHERE BackupID = @BackupID;
        
        PRINT 'BACKUP DIFFERENTIAL completado: ' + @NombreArchivo;
    END TRY
    BEGIN CATCH
        UPDATE Seguridad.AuditoriaBackups
        SET FechaFin = SYSDATETIME(), Estado = 'FALLIDO', MensajeError = ERROR_MESSAGE()
        WHERE BackupID = @BackupID;
        
        PRINT 'ERROR en BACKUP DIFFERENTIAL: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
PRINT '  Procedimiento Seguridad.sp_BackupDifferential creado';
GO

-- sp_HistorialBackups
CREATE PROCEDURE Seguridad.sp_HistorialBackups
    @Dias INT = 7
AS
BEGIN
    SELECT 
        BackupID AS ID, TipoBackup AS Tipo,
        FORMAT(FechaInicio, 'dd/MM/yyyy HH:mm:ss') AS Fecha,
        TamanoMB AS [Tamano MB], DuracionSegundos AS [Duracion seg],
        Estado, UsuarioEjecuto AS Usuario
    FROM Seguridad.AuditoriaBackups
    WHERE FechaInicio >= DATEADD(DAY, -@Dias, SYSDATETIME())
    ORDER BY FechaInicio DESC;
END;
PRINT '  Procedimiento Seguridad.sp_HistorialBackups creado';
GO




PRINT '';
PRINT 'FASE 8: Implementacion de Row Level Security';
GO

-- Funcion de predicado RLS
USE Academia2022;
GO
CREATE FUNCTION Sec.fn_AlumnosPorUsuario(@AlumnoID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN (
    SELECT 1 AS AllowRow
    WHERE 
        USER_NAME() IN ('dbo', 'sa')
        OR IS_MEMBER('db_datareader') = 1
        OR IS_MEMBER('db_owner') = 1
        OR
        @AlumnoID = CASE USER_NAME()
            WHEN 'alumno1' THEN 1
            WHEN 'alumno2' THEN 2
            WHEN 'alumno3' THEN 3
            WHEN 'alumno4' THEN 4
            ELSE NULL
        END);
        GO
PRINT '  Funcion Sec.fn_AlumnosPorUsuario creada';

GO

-- Politica de seguridad
CREATE SECURITY POLICY Sec.Policy_Alumnos
ADD FILTER PREDICATE Sec.fn_AlumnosPorUsuario(AlumnoID)
ON Academico.Alumnos
WITH (STATE = ON);
PRINT '  Politica Sec.Policy_Alumnos creada y activada';
GO


PRINT '';
PRINT 'FASE 9: Creacion de roles y permisos';
GO

-- Crear roles
CREATE ROLE AppReader;
PRINT '  Rol AppReader creado';
GO

CREATE ROLE AppWriter;
PRINT '  Rol AppWriter creado';
GO

CREATE ROLE AuditorBD;
PRINT '  Rol AuditorBD creado';
GO

-- Permisos AppReader
GRANT SELECT ON SCHEMA::App TO AppReader;
GRANT SELECT ON SCHEMA::Academico TO AppReader;
DENY INSERT, UPDATE, DELETE ON SCHEMA::Academico TO AppReader;
PRINT '  Permisos AppReader asignados';
GO

-- Permisos AppWriter
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Academico TO AppWriter;
GRANT SELECT ON SCHEMA::App TO AppWriter;
DENY ALTER ON SCHEMA::Academico TO AppWriter;
PRINT '  Permisos AppWriter asignados';
GO

-- Permisos AuditorBD
GRANT VIEW DEFINITION TO AuditorBD;
GRANT VIEW DATABASE STATE TO AuditorBD;
GRANT SELECT ON sys.database_permissions TO AuditorBD;
GRANT SELECT ON sys.database_principals TO AuditorBD;
GRANT SELECT ON sys.database_role_members TO AuditorBD;
GRANT SELECT ON Seguridad.AuditoriaAccesos TO AuditorBD;
GRANT SELECT ON Seguridad.vw_ResumenDiarioAccesos TO AuditorBD;
DENY INSERT, UPDATE, DELETE, ALTER ON SCHEMA::Academico TO AuditorBD;
DENY INSERT, UPDATE, DELETE, ALTER ON SCHEMA::App TO AuditorBD;
PRINT '  Permisos AuditorBD asignados';
GO



PRINT '';
PRINT 'FASE 10: Creacion de usuarios de prueba';
GO

-- Usuario alumno1
IF USER_ID('alumno1') IS NULL
BEGIN
    CREATE USER alumno1 WITHOUT LOGIN;
    GRANT SELECT ON Academico.Alumnos TO alumno1;
    PRINT '  Usuario alumno1 creado';
END
GO

-- Usuario alumno2
IF USER_ID('alumno2') IS NULL
BEGIN
    CREATE USER alumno2 WITHOUT LOGIN;
    GRANT SELECT ON Academico.Alumnos TO alumno2;
    PRINT '  Usuario alumno2 creado';
END
GO

-- Usuario alumno3
IF USER_ID('alumno3') IS NULL
BEGIN
    CREATE USER alumno3 WITHOUT LOGIN;
    GRANT SELECT ON Academico.Alumnos TO alumno3;
    PRINT '  Usuario alumno3 creado';
END
GO

-- Usuario alumno4
IF USER_ID('alumno4') IS NULL
BEGIN
    CREATE USER alumno4 WITHOUT LOGIN;
    GRANT SELECT ON Academico.Alumnos TO alumno4;
    PRINT '  Usuario alumno4 creado';
END
GO

-- Usuario usr_reader
IF USER_ID('usr_reader') IS NULL
BEGIN
    CREATE USER usr_reader WITHOUT LOGIN;
    ALTER ROLE AppReader ADD MEMBER usr_reader;
    PRINT '  Usuario usr_reader creado y asignado a AppReader';
END
GO

-- Usuario usr_writer
IF USER_ID('usr_writer') IS NULL
BEGIN
    CREATE USER usr_writer WITHOUT LOGIN;
    ALTER ROLE AppWriter ADD MEMBER usr_writer;
    PRINT '  Usuario usr_writer creado y asignado a AppWriter';
END
GO

-- Usuario usr_auditor
IF USER_ID('usr_auditor') IS NULL
BEGIN
    CREATE USER usr_auditor WITHOUT LOGIN;
    ALTER ROLE AuditorBD ADD MEMBER usr_auditor;
    PRINT '  Usuario usr_auditor creado y asignado a AuditorBD';
END
GO

-- Permisos de ejecucion en procedimientos de auditoria
GRANT EXECUTE ON Seguridad.sp_RegistrarAcceso TO usr_reader;
GRANT EXECUTE ON Seguridad.sp_RegistrarAcceso TO usr_writer;
GRANT EXECUTE ON Seguridad.sp_RegistrarLogout TO usr_reader;
GRANT EXECUTE ON Seguridad.sp_RegistrarLogout TO usr_writer;
GRANT EXECUTE ON Seguridad.sp_iniciarsesionalumno TO usr_reader;
GRANT EXECUTE ON Seguridad.sp_iniciarsesionalumno TO usr_writer;
GRANT EXECUTE ON Seguridad.sp_cerrarsesionalumno TO usr_reader;
GRANT EXECUTE ON Seguridad.sp_cerrarsesionalumno TO usr_writer;
GRANT EXECUTE ON Seguridad.sp_RegistrarAcceso TO AppReader;
GRANT EXECUTE ON Seguridad.sp_RegistrarAcceso TO AppWriter;
GRANT EXECUTE ON Seguridad.sp_RegistrarLogout TO AppReader;
GRANT EXECUTE ON Seguridad.sp_RegistrarLogout TO AppWriter;
GRANT EXECUTE ON Seguridad.sp_iniciarsesionalumno TO AppReader;
GRANT EXECUTE ON Seguridad.sp_iniciarsesionalumno TO AppWriter;
GRANT EXECUTE ON Seguridad.sp_cerrarsesionalumno TO AppReader;
GRANT EXECUTE ON Seguridad.sp_cerrarsesionalumno TO AppWriter;
PRINT '  Permisos de ejecucion en procedimientos asignados';
GO


PRINT '';
PRINT 'FASE 11: Creacion de sinonimos';
GO

IF OBJECT_ID('dbo.Matriculas', 'SN') IS NULL
BEGIN
    CREATE SYNONYM dbo.Matriculas FOR Academico.Matriculas;
    PRINT '  Sinonimo dbo.Matriculas creado';
END
GO



PRINT '';
PRINT 'FASE 12: Trigger de login a nivel servidor';
GO

USE master;
GO

IF EXISTS (SELECT * FROM sys.server_triggers WHERE name = 'trg_AuditoriaLogin_Servidor')
BEGIN
    DROP TRIGGER trg_AuditoriaLogin_Servidor ON ALL SERVER;
    PRINT '  Trigger anterior eliminado';
END
GO

CREATE TRIGGER trg_AuditoriaLogin_Servidor
ON ALL SERVER
FOR LOGON
AS
BEGIN
    IF ORIGINAL_DB_NAME() = 'Academia2022'
    BEGIN
        EXEC Academia2022.Seguridad.sp_RegistrarAcceso @EventoTipo = 'LOGIN';
    END
END;
PRINT '  Trigger trg_AuditoriaLogin_Servidor creado';
GO

USE Academia2022;
GO



PRINT '';
PRINT 'FASE 13: Verificacion de carpeta de backups';
GO

BEGIN TRY
    EXEC sp_configure 'show advanced options', 1;
    RECONFIGURE;
    EXEC sp_configure 'xp_cmdshell', 1;
    RECONFIGURE;
    
    EXEC xp_cmdshell 'mkdir C:\SQLBackups', NO_OUTPUT;
    PRINT '  Carpeta C:\SQLBackups verificada/creada';
    
    EXEC sp_configure 'xp_cmdshell', 0;
    RECONFIGURE;
    EXEC sp_configure 'show advanced options', 0;
    RECONFIGURE;
END TRY
BEGIN CATCH
    PRINT '  Advertencia: No se pudo crear carpeta de backups (xp_cmdshell deshabilitado)';
END CATCH
GO



PRINT '';
PRINT 'FASE 14: Configuracion de auditoria de servidor';
GO

USE master;
GO

BEGIN TRY
    IF EXISTS (SELECT * FROM sys.server_audits WHERE name = 'Audit_Academia')
    BEGIN
        ALTER SERVER AUDIT Audit_Academia WITH (STATE = OFF);
        DROP SERVER AUDIT Audit_Academia;
    END
    
    CREATE SERVER AUDIT Audit_Academia
    TO FILE (FILEPATH = 'C:\SQLAudit\');
    
    ALTER SERVER AUDIT Audit_Academia WITH (STATE = ON);
    PRINT '  Server Audit Audit_Academia creado y activado';
END TRY
BEGIN CATCH
    PRINT '  Advertencia: No se pudo crear Server Audit (carpeta C:\SQLAudit\ no existe)';
END CATCH
GO

USE Academia2022;
GO

BEGIN TRY
    IF EXISTS (SELECT * FROM sys.database_audit_specifications WHERE name = 'Audit_AcademiaDB')
    BEGIN
        ALTER DATABASE AUDIT SPECIFICATION Audit_AcademiaDB WITH (STATE = OFF);
        DROP DATABASE AUDIT SPECIFICATION Audit_AcademiaDB;
    END
    
    CREATE DATABASE AUDIT SPECIFICATION Audit_AcademiaDB
    FOR SERVER AUDIT Audit_Academia
    ADD (DATABASE_OBJECT_PERMISSION_CHANGE_GROUP),
    ADD (FAILED_DATABASE_AUTHENTICATION_GROUP);
    
    ALTER DATABASE AUDIT SPECIFICATION Audit_AcademiaDB WITH (STATE = ON);
    PRINT '  Database Audit Specification Audit_AcademiaDB creado y activado';
END TRY
BEGIN CATCH
    PRINT '  Advertencia: No se pudo crear Database Audit Specification';
END CATCH
GO


PRINT '';
PRINT '============================================';
PRINT 'VERIFICACION FINAL DEL DEPLOY';
PRINT '============================================';
GO

-- Verificar esquemas
PRINT '';
PRINT 'ESQUEMAS CREADOS:';
SELECT name AS Esquema
FROM sys.schemas 
WHERE name IN ('Academico','Seguridad','App','Lab','Sec')
ORDER BY name;
GO

-- Verificar tablas
PRINT '';
PRINT 'TABLAS CREADAS:';
SELECT 
    SCHEMA_NAME(schema_id) AS Esquema,
    name AS Tabla
FROM sys.tables
ORDER BY SCHEMA_NAME(schema_id), name;
GO

-- Verificar vistas
PRINT '';
PRINT 'VISTAS CREADAS:';
SELECT 
    SCHEMA_NAME(schema_id) AS Esquema,
    name AS Vista
FROM sys.views
ORDER BY SCHEMA_NAME(schema_id), name;
GO

-- Verificar indices en vistas
PRINT '';
PRINT 'VISTAS INDEXADAS (MATERIALIZADAS):';
SELECT 
    OBJECT_SCHEMA_NAME(v.object_id) AS Esquema,
    v.name AS Vista,
    i.name AS Indice,
    i.type_desc AS TipoIndice
FROM sys.views v
JOIN sys.indexes i ON v.object_id = i.object_id
WHERE i.index_id > 0
ORDER BY OBJECT_SCHEMA_NAME(v.object_id), v.name;
GO

-- Verificar procedimientos
PRINT '';
PRINT 'PROCEDIMIENTOS ALMACENADOS:';
SELECT 
    SCHEMA_NAME(schema_id) AS Esquema,
    name AS Procedimiento
FROM sys.procedures
ORDER BY SCHEMA_NAME(schema_id), name;
GO

-- Verificar roles
PRINT '';
PRINT 'ROLES PERSONALIZADOS:';
SELECT name AS Rol
FROM sys.database_principals
WHERE type = 'R' 
AND name IN ('AppReader', 'AppWriter', 'AuditorBD')
ORDER BY name;
GO

-- Verificar usuarios
PRINT '';
PRINT 'USUARIOS CREADOS:';
SELECT name AS Usuario, type_desc AS Tipo
FROM sys.database_principals
WHERE type = 'S' 
AND name IN ('alumno1', 'alumno2', 'alumno3', 'alumno4', 'usr_reader', 'usr_writer', 'usr_auditor')
ORDER BY name;
GO

-- Verificar politicas RLS
PRINT '';
PRINT 'POLITICAS DE SEGURIDAD (RLS):';
SELECT 
    name AS Politica,
    CASE is_enabled WHEN 1 THEN 'ACTIVA' ELSE 'INACTIVA' END AS Estado
FROM sys.security_policies
WHERE name = 'Policy_Alumnos';
GO

-- Verificar datos insertados
PRINT '';
PRINT 'DATOS DE PRUEBA:';
SELECT 'Carreras' AS Tabla, COUNT(*) AS Total FROM Academico.Carreras
UNION ALL
SELECT 'Alumnos', COUNT(*) FROM Academico.Alumnos
UNION ALL
SELECT 'Cursos', COUNT(*) FROM Academico.Cursos
UNION ALL
SELECT 'Matriculas', COUNT(*) FROM Academico.Matriculas;
GO



PRINT '';
PRINT '============================================';
PRINT 'CONSULTAS DE PRUEBA Y VALIDACION';
PRINT '============================================';
GO

-- Consulta 1: Alumnos con carreras
PRINT '';
PRINT 'Consulta 1: Alumnos con sus carreras';
SELECT 
    a.AlumnoID,
    a.NombreCompleto,
    a.AlumnoEmail,
    c.CarreraNombre
FROM Academico.Alumnos a
LEFT JOIN Academico.Carreras c ON a.CarreraID = c.CarreraID;
GO

-- Consulta 2: Vista indexada de matriculas por curso
PRINT '';
PRINT 'Consulta 2: Matriculas por curso (vista indexada)';
SELECT * FROM App.vw_MatriculasPorCurso;
GO


PRINT '';
PRINT 'Consulta 3: Estadisticas de carga por alumno';
SELECT 
    AlumnoID,
    TotalMatriculasAlumno AS CursosInscritos,
    CreditosTotales,
    PeriodosCursados
FROM App.vw_EstadisticasCarrera
ORDER BY CreditosTotales DESC;
GO

PRINT '';
PRINT 'Consulta 4: Rendimiento por curso/periodo';
SELECT 
    CursoNombre,
    MatriculaPeriodo,
    TotalMatriculas,
    CreditosCurso
FROM App.vw_RendimientoCursos
ORDER BY MatriculaPeriodo DESC, TotalMatriculas DESC;
GO


PRINT '';
PRINT '============================================';
PRINT 'PRUEBAS DE ROW LEVEL SECURITY';
PRINT '============================================';
GO

-- Prueba como DBO (ve todos los registros)
PRINT '';
PRINT 'Prueba 1: Usuario DBO (sin filtro RLS)';
SELECT 
    'Usuario: ' + USER_NAME() AS Contexto,
    AlumnoID,
    NombreCompleto
FROM Academico.Alumnos;
GO

-- Prueba como alumno1 (solo ve su registro)
PRINT '';
PRINT 'Prueba 2: Usuario alumno1 (con filtro RLS)';
EXECUTE AS USER = 'alumno1';
GO

SELECT 
    'Usuario: ' + USER_NAME() AS Contexto,
    AlumnoID,
    NombreCompleto
FROM Academico.Alumnos;
GO

REVERT;
GO

-- Prueba como alumno2
PRINT '';
PRINT 'Prueba 3: Usuario alumno2 (con filtro RLS)';
EXECUTE AS USER = 'alumno2';
GO

SELECT 
    'Usuario: ' + USER_NAME() AS Contexto,
    AlumnoID,
    NombreCompleto
FROM Academico.Alumnos;
GO

REVERT;
GO



PRINT '';
PRINT '============================================';
PRINT 'PRUEBAS DE SISTEMA DE AUDITORIA';
PRINT '============================================';
GO

-- Registrar eventos de prueba
PRINT '';
PRINT 'Registrando eventos de auditoria de prueba...';
EXEC Seguridad.sp_iniciarsesionalumno;
WAITFOR DELAY '00:00:02';
EXEC Seguridad.sp_cerrarsesionalumno;
GO

-- Ver registros de auditoria
PRINT '';
PRINT 'Registros de auditoria:';
SELECT TOP 10
    AuditoriaID,
    EventoTipo,
    UsuarioDB,
    FORMAT(FechaHora, 'dd/MM/yyyy HH:mm:ss') AS Fecha,
    NombreHost
FROM Seguridad.AuditoriaAccesos
ORDER BY FechaHora DESC;
GO



PRINT '';
PRINT '============================================';
PRINT 'PRUEBAS ADICIONALES DE LOGIN/LOGOUT';
PRINT '============================================';
GO

-- Prueba completa de sesion para usr_reader
PRINT '';
PRINT 'Prueba sesion completa usr_reader:';
EXECUTE AS USER = 'usr_reader';
GO

EXEC Seguridad.sp_iniciarsesionalumno;
GO

SELECT 
    'Sesion activa de: ' + USER_NAME() AS Estado,
    COUNT(*) AS CursosVisibles
FROM Academico.Cursos;
GO

WAITFOR DELAY '00:00:02';
GO

EXEC Seguridad.sp_cerrarsesionalumno;
GO

REVERT;
GO

-- Prueba completa de sesion para usr_writer
PRINT '';
PRINT 'Prueba sesion completa usr_writer:';
EXECUTE AS USER = 'usr_writer';
GO

EXEC Seguridad.sp_iniciarsesionalumno;
GO

SELECT 
    'Sesion activa de: ' + USER_NAME() AS Estado,
    COUNT(*) AS AlumnosVisibles
FROM Academico.Alumnos;
GO

WAITFOR DELAY '00:00:02';
GO

EXEC Seguridad.sp_cerrarsesionalumno;
GO

REVERT;
GO

-- Verificar registros de LOGIN/LOGOUT generados
PRINT '';
PRINT 'Verificacion de registros LOGIN/LOGOUT en auditoria:';
SELECT 
    AuditoriaID,
    EventoTipo,
    UsuarioDB,
    FORMAT(FechaHora, 'HH:mm:ss') AS Hora,
    CASE EventoTipo
        WHEN 'LOGIN' THEN 'Inicio de sesion'
        WHEN 'LOGOUT' THEN 'Cierre de sesion'
    END AS Descripcion
FROM Seguridad.AuditoriaAccesos
ORDER BY AuditoriaID DESC;
GO

-- Estadisticas de sesiones por usuario
PRINT '';
PRINT 'Estadisticas de sesiones por usuario:';
SELECT 
    UsuarioDB AS Usuario,
    EventoTipo AS Evento,
    COUNT(*) AS Total,
    MIN(FechaHora) AS PrimerEvento,
    MAX(FechaHora) AS UltimoEvento
FROM Seguridad.AuditoriaAccesos
GROUP BY UsuarioDB, EventoTipo
ORDER BY UsuarioDB, EventoTipo;
GO

-- Sesiones sin cierre (LOGIN sin LOGOUT)
PRINT '';
PRINT 'Sesiones sin cierre (LOGIN sin LOGOUT correspondiente):';
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
    l.UsuarioDB AS Usuario,
    FORMAT(l.LoginTime, 'dd/MM/yyyy HH:mm:ss') AS InicioSesion,
    CASE 
        WHEN lo.LogoutTime IS NULL THEN 'SIN LOGOUT'
        ELSE 'CERRADO'
    END AS EstadoSesion,
    FORMAT(lo.LogoutTime, 'dd/MM/yyyy HH:mm:ss') AS CierreSesion,
    DATEDIFF(SECOND, l.LoginTime, ISNULL(lo.LogoutTime, SYSDATETIME())) AS DuracionSegundos
FROM LoginEvents l
LEFT JOIN LogoutEvents lo ON l.UsuarioDB = lo.UsuarioDB 
    AND l.SPID = lo.SPID
    AND lo.LogoutTime > l.LoginTime
ORDER BY l.LoginTime DESC;
GO



PRINT '';
PRINT '============================================';
PRINT 'RESUMEN EJECUTIVO DEL DEPLOY';
PRINT '============================================';
PRINT '';
PRINT 'BASE DE DATOS: Academia2022';
PRINT 'ESTADO: DEPLOY COMPLETADO EXITOSAMENTE';
PRINT '';
PRINT 'COMPONENTES DESPLEGADOS:';
PRINT '  - 5 Esquemas (Academico, Seguridad, App, Lab, Sec)';
PRINT '  - 9 Tablas principales con constraints';
PRINT '  - 8 Vistas (5 indexadas/materializadas)';
PRINT '  - 7 Procedimientos almacenados';
PRINT '  - 3 Roles personalizados (AppReader, AppWriter, AuditorBD)';
PRINT '  - 7 Usuarios de prueba';
PRINT '  - 1 Politica RLS activa';
PRINT '  - 1 Trigger de servidor (Login)';
PRINT '  - 2 Tablas de auditoria';
PRINT '';
PRINT 'CARACTERISTICAS DE SEGURIDAD:';
PRINT '  - Row Level Security (RLS) habilitado';
PRINT '  - Auditoria de accesos configurada';
PRINT '  - Auditoria de backups configurada';
PRINT '  - Permisos granulares por rol';
PRINT '  - Principio de menor privilegio aplicado';
PRINT '';
PRINT 'DATOS DE PRUEBA:';
PRINT '  - 3 Carreras';
PRINT '  - 4 Alumnos';
PRINT '  - 4 Cursos';
PRINT '  - 4 Matriculas';
PRINT '';
PRINT 'SISTEMA DE AUDITORIA LOGIN/LOGOUT:';
PRINT '  - Trigger automatico de LOGIN a nivel servidor';
PRINT '  - Procedimiento sp_iniciarsesionalumno (registra LOGIN)';
PRINT '  - Procedimiento sp_cerrarsesionalumno (registra LOGOUT)';
PRINT '  - Tabla Seguridad.AuditoriaAccesos (almacena eventos)';
PRINT '  - Vista Seguridad.vw_ResumenDiarioAccesos';
PRINT '  - Captura: Usuario, IP, Host, Aplicacion, Fecha/Hora, SPID';
PRINT '';
PRINT 'PROCEDIMIENTOS CLAVE:';
PRINT '  - Seguridad.sp_iniciarsesionalumno (LOGIN manual)';
PRINT '  - Seguridad.sp_cerrarsesionalumno (LOGOUT manual)';
PRINT '  - Seguridad.sp_RegistrarAcceso (base para LOGIN/LOGOUT)';
PRINT '  - Seguridad.sp_RegistrarLogout (wrapper para LOGOUT)';
PRINT '  - Seguridad.sp_BackupFull';
PRINT '  - Seguridad.sp_BackupDifferential';
PRINT '  - Seguridad.sp_HistorialBackups';
PRINT '';
PRINT 'VISTAS PRINCIPALES:';
PRINT '  - App.vw_ResumenAlumno';
PRINT '  - App.vw_EstadisticasCarrera (indexada)';
PRINT '  - App.vw_RendimientoCursos (indexada)';
PRINT '  - App.vw_MatriculasPorCurso (indexada)';
PRINT '  - App.vw_CargaPorAlumno (indexada)';
PRINT '  - App.vw_OcupacionPorPeriodo (indexada)';
PRINT '';
PRINT 'COMANDOS UTILES:';
PRINT '  - Iniciar sesion: EXEC Seguridad.sp_iniciarsesionalumno;';
PRINT '  - Cerrar sesion: EXEC Seguridad.sp_cerrarsesionalumno;';
PRINT '  - Backup FULL: EXEC Seguridad.sp_BackupFull;';
PRINT '  - Ver auditoria: SELECT * FROM Seguridad.AuditoriaAccesos;';
PRINT '  - Ver backups: EXEC Seguridad.sp_HistorialBackups;';
PRINT '';
PRINT '============================================';
PRINT 'DEPLOY FINALIZADO CORRECTAMENTE';
PRINT 'Fecha: ' + CONVERT(VARCHAR(30), SYSDATETIME(), 120);
PRINT '============================================';
GO