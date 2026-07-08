USE AdventureWorks2022;
GO

-- Create schema if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Training')
BEGIN
    EXEC('CREATE SCHEMA Training');
END;
GO

-- Drop tables if they already exist
DROP TABLE IF EXISTS Training.ProductPriceAudit;
DROP TABLE IF EXISTS Training.SchemaChangeLog;
GO

-- Product Price Audit Table
CREATE TABLE Training.ProductPriceAudit
(
    AuditID INT IDENTITY(1,1) NOT NULL,
    ProductID INT NOT NULL,
    OldPrice MONEY NOT NULL,
    NewPrice MONEY NOT NULL,
    ChangedBy NVARCHAR(100) NOT NULL
        CONSTRAINT DF_ProductPriceAudit_ChangedBy
        DEFAULT SUSER_SNAME(),
    ChangeDate DATETIME2 NOT NULL
        CONSTRAINT DF_ProductPriceAudit_ChangeDate
        DEFAULT SYSDATETIME(),

    CONSTRAINT PK_ProductPriceAudit
        PRIMARY KEY (AuditID)
);
GO

-- Schema Change Log Table
CREATE TABLE Training.SchemaChangeLog
(
    LogID INT IDENTITY(1,1) NOT NULL,
    EventType NVARCHAR(100) NOT NULL,
    ObjectName NVARCHAR(100) NOT NULL,
    PerformedBy NVARCHAR(100) NOT NULL
        CONSTRAINT DF_SchemaChangeLog_PerformedBy
        DEFAULT SUSER_SNAME(),
    EventDate DATETIME2 NOT NULL
        CONSTRAINT DF_SchemaChangeLog_EventDate
        DEFAULT SYSDATETIME(),

    CONSTRAINT PK_SchemaChangeLog
        PRIMARY KEY (LogID)
);
GO

--task2
USE AdventureWorks2022;
GO

CREATE TRIGGER trg_Product_PriceAudit
ON Production.Product
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
 
    INSERT INTO Training.ProductPriceAudit (ProductID, OldPrice, NewPrice, ChangedBy)
    SELECT d.ProductID, d.ListPrice, i.ListPrice, SUSER_SNAME()
    FROM deleted d
    JOIN inserted i ON d.ProductID = i.ProductID
    WHERE d.ListPrice <> i.ListPrice;
END;
GO
--test--
UPDATE Production.Product SET ListPrice = ListPrice * 1.05 WHERE ProductID = 707;
SELECT * FROM Training.ProductPriceAudit;

--task3--
CREATE TRIGGER trg_Product_PreventDelete
ON Production.Product
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
 
    IF EXISTS (
        SELECT 1 FROM deleted d
        JOIN Sales.SalesOrderDetail s ON s.ProductID = d.ProductID
    )
    BEGIN
        PRINT 'Cannot delete products linked to existing sales orders.';
        RETURN;
    END
 
    DELETE p
    FROM Production.Product p
    JOIN deleted d ON p.ProductID = d.ProductID;
END;
GO

--task4--
CREATE TRIGGER trg_Database_SchemaLog
ON DATABASE
FOR CREATE_TABLE, ALTER_TABLE, DROP_TABLE
AS
BEGIN
    SET NOCOUNT ON;
 
    INSERT INTO Training.SchemaChangeLog (EventType, ObjectName, PerformedBy)
    SELECT EVENTDATA().value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(100)'),
           EVENTDATA().value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(100)'),
           SUSER_SNAME();
END;
GO

--test
CREATE TABLE Training.TempTest (ID INT);
DROP TABLE Training.TempTest;
SELECT * FROM Training.SchemaChangeLog;

