﻿<SQLBuilder_Common>

SET @SQL = 'CREATE PROCEDURE work.usp_Merge_' + @TargetSchema + '_' + @SourceTable + ' @globalCTId BIGINT, @MaxCTId BIGINT AS'
SET @SQL = @SQL + @CR + 'BEGIN'
SET @SQL = @SQL + @CR + SPACE(@TB) + '-- Generated by CreateDWScripts.tt - SQLBuilder_Merge.sql'	-- No datetime because it will only overwrite if different and date guarantees this
SET @SQL = @SQL + @CR + SPACE(@TB) + 'SET NOCOUNT ON;'
SET @SQL = @SQL + @CR + SPACE(@TB) + 'SET XACT_ABORT ON;'
SET @SQL = @SQL + @CR + SPACE(@TB) + 'BEGIN TRY'
SET @SQL = @SQL + @CR + SPACE(@TB*2) + 'IF NOT EXISTS(SELECT * FROM ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@SourceTable) + ')'
SET @SQL = @SQL + @CR + SPACE(@TB*3) + 'BEGIN'
SET @SQL = @SQL + @CR + SPACE(@TB*4) + 'INSERT INTO ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@SourceTable)
SET @SQL = @SQL + @CR + SPACE(@TB*4) + '('

SELECT @iCount = 1
WHILE (SELECT MAX(Id) FROM @Cols) >= @iCount	
BEGIN
	SELECT @SQL = @SQL + IIF(@iCount > 1, ', ', '') + QUOTENAME(c.ColName)
	FROM @Cols AS c
	WHERE c.Id = @iCount

	SET @iCount = @iCount + 1
END	

SET @SQL = @SQL + ')'
SET @SQL = @SQL + @CR + SPACE(@TB*4) + 'SELECT'
SELECT @iCount = 1
WHILE (SELECT MAX(Id) FROM @Cols) >= @iCount	
BEGIN
	SELECT @SQL = @SQL + @CR + SPACE(@TB*5) + IIF(@iCount > 1, ', ', '') + QUOTENAME(c.ColName)
	FROM @Cols AS c
	WHERE c.Id = @iCount

	SET @iCount = @iCount + 1
END

SET @SQL = @SQL + @CR + SPACE(@TB*4) + 'FROM [work].' + QUOTENAME(@TargetSchema + '_' + @SourceTable)
SET @SQL = @SQL + @CR + SPACE(@TB*4) + 'WHERE isDeleted = 0'

SET @SQL = @SQL + @CR + SPACE(@TB*3) + 'END'
SET @SQL = @SQL + @CR + SPACE(@TB*2) + 'ELSE BEGIN'
SET @SQL = @SQL + @CR + SPACE(@TB*3) + 'MERGE ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@SourceTable) + ' AS t'
SET @SQL = @SQL + @CR + SPACE(@TB*4) + 'USING [work].' + QUOTENAME(@TargetSchema + '_' + @SourceTable) + ' AS s'

-- Primary Key join
SELECT @iCount = MIN(Id) FROM @Cols AS c WHERE COALESCE(c.PKOrdinal, -1) > 0
WHILE (SELECT MAX(Id) FROM @Cols AS c WHERE COALESCE(c.PKOrdinal, -1) > 0) >= @iCount	
BEGIN
	SELECT @SQL = @SQL + @CR + SPACE(@TB*4) + IIF((SELECT MIN(Id) FROM @Cols AS c WHERE c.PKOrdinal > 0) < @iCount, SPACE(@TB) + 'AND t.', 'ON t.') + QUOTENAME(c.ColName) + ' = s.' + QUOTENAME(c.ColName)
	FROM @Cols AS c
	WHERE c.Id = @iCount

	SET @iCount = @iCount + 1
END	

SET @SQL = @SQL + @CR + SPACE(@TB*4) + 'WHEN MATCHED AND (t.[CTid] <> s.[CTid] OR @MaxCTId = -1)'
SET @SQL = @SQL + @CR + SPACE(@TB*4) + 'THEN UPDATE SET'

-- None Primary Key columns
SELECT @iCount = 1
WHILE (SELECT MAX(Id) FROM @Cols) >= @iCount	
BEGIN
	-- will not return anything for PK columns
	SELECT @SQL = @SQL + @CR + SPACE(@TB*5) + IIF(@iCount > (SELECT MIN(Id) FROM @Cols WHERE PKOrdinal <> -7 AND COALESCE(PKOrdinal, -1) < 0), ', t.', 't.') + QUOTENAME(c.ColName) + ' = s.' + QUOTENAME(c.ColName)
	FROM @Cols AS c
	WHERE c.Id = @iCount
		AND COALESCE(c.PKOrdinal, -1) < 0
		AND c.ColName NOT IN ('BIDateCreated')

	SET @iCount = @iCount + 1
END	

SET @SQL = @SQL + @CR + SPACE(@TB*4) + 'WHEN NOT MATCHED BY TARGET AND s.isDeleted = 0'
SET @SQL = @SQL + @CR + SPACE(@TB*4) + 'THEN INSERT ('

-- All columns
SELECT @iCount = 1
WHILE (SELECT MAX(Id) FROM @Cols) >= @iCount	
BEGIN
	SELECT @SQL = @SQL + @CR + SPACE(@TB*5) + IIF(@iCount > 1, ', ', '') + QUOTENAME(c.ColName)
	FROM @Cols AS c
	WHERE c.Id = @iCount

	SET @iCount = @iCount + 1
END	
    
SET @SQL = @SQL + @CR + SPACE(@TB*5) + ') VALUES ('

-- All columns
SELECT @iCount = 1
WHILE (SELECT MAX(Id) FROM @Cols) >= @iCount	
BEGIN
	SELECT @SQL = @SQL + @CR + SPACE(@TB*5) + IIF(@iCount > 1, ', s.', 's.') + QUOTENAME(c.ColName)
	FROM @Cols AS c
	WHERE c.Id = @iCount

	SET @iCount = @iCount + 1
END	
SET @SQL = @SQL + @CR + SPACE(@TB*5) + ')'

SET @SQL = @SQL + @CR + SPACE(@TB*4) + 'WHEN NOT MATCHED BY SOURCE AND @MaxCTId = -1 AND t.isDeleted = 0'
SET @SQL = @SQL + @CR + SPACE(@TB*4) + 'THEN UPDATE SET isDeleted = 1'
SET @SQL = @SQL + @CR + SPACE(@TB*5) + ',[CTId] = @GlobalCTId'
SET @SQL = @SQL + @CR + SPACE(@TB*5) + ',[BIDateModified] = GetDate();'

SET @SQL = @SQL + @CR + SPACE(@TB*3) + 'END'
SET @SQL = @SQL + @CR + SPACE(@TB) + 'END TRY'
SET @SQL = @SQL + @CR + SPACE(@TB) + 'BEGIN CATCH'
SET @SQL = @SQL + @CR + SPACE(@TB*2) + 'THROW;'
SET @SQL = @SQL + @CR + SPACE(@TB) + 'END CATCH'
SET @SQL = @SQL + @CR + 'END'
SET @SQL = @SQL + @CR + 'GO' + @CR

SELECT 'usp_Merge_' + @TargetSchema + '_' + @SourceTable + '.sql', 'work\Stored Procedures', @SQL