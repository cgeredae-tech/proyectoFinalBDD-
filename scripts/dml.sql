----lenguaje dml
use Academia2022;
go
SET IDENTITY_INSERT Academico.Alumnos ON;

INSERT INTO Academico.Alumnos (AlumnoID, AlumnoNombre,AlumnoApellido,AlumnoEdad)
VALUES (1001, 'Juan', 'Pérez''20');



SELECT 
    name AS Columna,
    is_computed AS EsCalculada
FROM sys.columns
WHERE object_id = OBJECT_ID('Academico.Alumnos');
