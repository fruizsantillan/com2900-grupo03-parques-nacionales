USE master;
GO

-- Si la base de datos existe, la pone en modo usuario único (echa a todos) y la borra
IF EXISTS (SELECT name FROM sys.databases WHERE name = N'ParquesNacionales')
BEGIN
    ALTER DATABASE ParquesNacionales SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE ParquesNacionales;
    PRINT 'Base de datos eliminada con éxito.';
END
ELSE
BEGIN
    PRINT 'La base de datos no existe. No es necesario eliminarla.';
END
GO