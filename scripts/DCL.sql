---LENGUAJE DCL
USE Academia2022
GRANT SELECT ON Academico.Alumnos TO Alumno_1001;
GRANT INSERT ON Academico.Alumnos TO Alumno_1001
GRANT SELECT ON Academico.Alumnos TO Alumno_1002;
GO
SET IDENTITY_INSERT Academico.Alumnos ON;

INSERT INTO Academico.Alumnos (
    AlumnoID, AlumnoNombre, AlumnoApellido, AlumnoEmail, AlumnoEdad, AlumnoActivo, CarreraID
)
VALUES (
    1001, 'Juan', 'Pérez', 'juan.perez@email.com', 20, 1, 3
);

SET IDENTITY_INSERT Academico.Alumnos OFF;
GRANT SHOWPLAN TO Alumno_1001;
GO
GRANT SHOWPLAN TO Alumno_1002;
GO
SELECT * FROM Academico.Alumnos;
