IF EXISTS (
    SELECT 1 
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'splitAssignment' AND TABLE_SCHEMA = 'rule' 
    AND COLUMN_NAME = 'percent' AND DATA_TYPE = 'decimal'
    AND NUMERIC_PRECISION = 18 AND NUMERIC_SCALE = 0)
BEGIN
    ALTER TABLE [rule].splitAssignment ALTER COLUMN [percent] DECIMAL(5,2)
END
IF EXISTS (
    SELECT 1 
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'splitRange' AND TABLE_SCHEMA = 'rule' 
    AND COLUMN_NAME = 'percent' AND DATA_TYPE = 'decimal'
    AND NUMERIC_PRECISION = 18 AND NUMERIC_SCALE = 0)
BEGIN
    ALTER TABLE [rule].splitRange ALTER COLUMN [percent] DECIMAL(5,2)
END