---LENGUAJE DQL
USE Academia2022;

GO
SET STATISTICS PROFILE OFF;
GO
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO


---CONSULTA PARA  PRUEBA Y EVIDENCIA DE SECURITY

-- A. PRUEBA COMO ALUMNO 1001
PRINT '--- 1. EVIDENCIA DE RLS: Consulta filtrada por Alumno_1001 (Solo debe ver ID 1001) ---';
GO
EXECUTE AS USER = 'Alumno_1001'; -- Simula la autenticación del usuario
GO

-- Resultado: La consulta está filtrada, mostrando solo el registro 1001.
SELECT 
    'Usuario Autenticado: ' + SUSER_SNAME() AS UsuarioActual,
    a.AlumnoID,
    a.NombreCompleto,
    'EVIDENCIA: Alumno_1001 solo ve su propio ID.' AS Estado
FROM 
    Academico.Alumnos AS a;
GO

 SELECT * FROM sys.fn_my_permissions(NULL, 'DATABASE'); 
 SELECT SYSTEM_USER AS login_name, USER_NAME() AS db_user;
EXEC sp_helprolemember 'db_owner';

-- Simula autenticación como Alumno_1001
EXECUTE AS USER = 'Alumno_1001';
SELECT SUSER_SNAME() AS UsuarioActual, AlumnoID, NombreCompleto
FROM Academico.Alumnos;
REVERT;

SELECT * FROM Academico.Alumnos WHERE AlumnoID = 1001
SET IDENTITY_INSERT Academico.Alumnos ON;

INSERT INTO Academico.Alumnos (
    AlumnoID, AlumnoNombre, AlumnoApellido, AlumnoEmail, AlumnoEdad, AlumnoActivo, CarreraID, ContactoID
)
VALUES (
    1001, 'Juan', 'Pérez', 'juan.perez@email.com', 20, 1, 3, 10
);

SET IDENTITY_INSERT Academico.Alumnos OFF;
EXECUTE AS USER = 'Alumno_1001';

SELECT 
    'Usuario Autenticado: ' + SUSER_SNAME() AS UsuarioActual,
    AlumnoID,
    NombreCompleto,
    'EVIDENCIA: Alumno_1001 solo ve su propio ID.' AS Estado
FROM Academico.Alumnos;

REVERT;

SELECT * FROM Academico.Alumnos WHERE AlumnoID = 1001;
use Academia2022;
go
SET IDENTITY_INSERT Academico.Alumnos ON;

INSERT INTO Academico.Alumnos (
    AlumnoID, AlumnoNombre, AlumnoApellido, AlumnoEmail, AlumnoEdad, AlumnoActivo, CarreraID, ContactoID
)
VALUES (
    1001, 'Juan', 'Pérez', 'juan.perez@email.com', 20, 1, 1, NULL
);

SET IDENTITY_INSERT Academico.Alumnos OFF;

EXECUTE AS USER = 'Alumno_1001';

SELECT 
    'Usuario Autenticado: ' + SUSER_SNAME() AS UsuarioActual,
    AlumnoID,
    NombreCompleto,
    'EVIDENCIA: Alumno_1001 solo ve su propio ID.' AS Estado
FROM Academico.Alumnos;

REVERT;
