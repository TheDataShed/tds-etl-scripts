﻿<SQLBuilder_Common>

DECLARE @SQL_Work VARCHAR(MAX)
DECLARE @FileGroup VARCHAR(50) = '' --QUOTENAME(@SourceSchema + 'FG')
DECLARE @CreateTable VARCHAR(200) = 'CREATE TABLE ' + QUOTENAME(@TargetSchema) + '.' + QUOTENAME(@SourceTable) + ' ('
DECLARE @CreateTable_Work VARCHAR(200) = 'CREATE TABLE [work].' + QUOTENAME(@TargetSchema + '_' + @SourceTable) + ' ('
DECLARE @PK VARCHAR(200), @EP VARCHAR(MAX), @IX VARCHAR(200), @EPFK VARCHAR(MAX), @FK VARCHAR(MAX)
DECLARE @IX_CTId VARCHAR(200) = 'CREATE NONCLUSTERED INDEX [IX_' + @SourceTable + 'CTId] ON [' + @TargetSchema + '].[' + @SourceTable + ']([CTId] ASC)' + IIF(@FileGroup <> '', ' ON ' + @FileGroup, '')
DECLARE @PKColumnName VARCHAR(50) = @SourceTable + 'HashKey'


-- Main Table

SET @Ixtype = CASE WHEN @IxType = 'NC' THEN 'NONCLUSTERED' ELSE 'CLUSTERED' END

SET @SQL = '-- Generated by CreateDWScripts.tt - SQLBuilder_Tables_Stg.sql'	-- No datetime because it will only overwrite if different and date guarantees this
SET @SQL = @SQL + @CR + @CreateTable

--SELECT @SQL = @SQL + @CR + SPACE(5) + QUOTENAME(@PKColumnName) + SPACE(@MaxColLen + 5 - LEN(QUOTENAME(@PKColumnName))) + 'BINARY(32)               NOT NULL,'		-- Pk
--SET @PK = 'CONSTRAINT [PK_' + @SourceTable + '] PRIMARY KEY CLUSTERED (' + QUOTENAME(@PKColumnName) + ' ASC)' + IIF(@FileGroup <> '', ' ON ' + @FileGroup, '') + ','

SET @PK = 'CONSTRAINT [PK_' + @SourceSchema + '_' + @SourceTable + '] PRIMARY KEY ' + @IXType + '('
SELECT @iCount = MAX(Id) FROM @Cols AS c WHERE c.PKOrdinal = 1
WHILE (SELECT MAX(Id) FROM @Cols AS c WHERE c.PKOrdinal > 0) >= @iCount	
BEGIN
	SELECT @PK = @PK + IIF((SELECT MAX(Id) FROM @Cols AS c WHERE c.PKOrdinal = 1) < @iCount, ', ', '') + QUOTENAME(c.ColName) + ' ASC'
	FROM @Cols AS c
	WHERE c.Id = @iCount
	SET @iCount = @iCount + 1
END	

IF @SV = '1'
BEGIN
	SET @SQL = @SQL + @CR + SPACE(5) + '[StartTime]' + SPACE(@MaxColLen - 7) +' DATETIME2' + SPACE(9) + 'GENERATED ALWAYS AS ROW START NOT NULL,'
	SET @SQL = @SQL + @CR + SPACE(5) + '[EndTime]' + SPACE(@MaxColLen - 5) +' DATETIME2' + SPACE(9) + 'GENERATED ALWAYS AS ROW END NOT NULL,'
	SET @SQL = @SQL + @CR + SPACE(5) + 'PERIOD FOR SYSTEM_TIME (StartTime,EndTime),'
END

SET @iCount = 1
WHILE (SELECT COUNT(1) FROM @Cols AS c) >= @iCount	
BEGIN
	SELECT @Sql = @SQL + @CR + SPACE(5) + QUOTENAME(c.ColName) + SPACE(@MaxColLen + 5 - LEN(QUOTENAME(c.ColName))) + c.DataType + SPACE(18 - LEN(c.DataType)) + IIF(c.Nullable = 'NO', 'NOT NULL', 'NULL') + ','
	FROM @Cols AS c
	WHERE c.Id = @iCount
	
	SET @iCount = @iCount + 1
END	

SET @IX = 'CREATE NONCLUSTERED INDEX [IX_' + @SourceTable + '] ON ' + @TargetSchema + '.' + @SourceTable +' ('
SELECT @EP = '', @EPFK = '', @FK = ''
SELECT @iCount = MAX(Id) FROM @Cols AS c WHERE c.IXOrdinal = 1
WHILE (SELECT MAX(Id) FROM @Cols AS c WHERE c.IXOrdinal > 0) >= @iCount	
BEGIN
	SELECT @IX = @IX + IIF((SELECT MAX(Id) FROM @Cols AS c WHERE c.IXOrdinal = 1) < @iCount, ', ', '') + QUOTENAME(c.ColName) + ' ASC'
	FROM @Cols AS c
	WHERE c.Id = @iCount
	SET @iCount = @iCount + 1
END	

SELECT @iCount = 1
WHILE (SELECT MAX(Id) FROM @Cols AS c WHERE c.LkupTable IS NOT NULL) >= @iCount	
BEGIN
	SELECT @FK = @FK + SPACE(5) + 'CONSTRAINT [FK_' + @SourceSchema + '_' + @SourceTable + '_' + c.ColName + '] FOREIGN KEY ([' + c.ColName + ']) REFERENCES [' + @SourceSchema + '].[' + c.LkupTable + '] ([' + c.FKColumn + ']),' + @CR
	FROM @Cols AS c
	WHERE c.Id = @iCount
		AND c.LkupTable IS NOT NULL
	
	SET @iCount = @iCount + 1
END

SET @SQL = @SQL + @CR + SPACE(5) + @PK + ')'
--SET @SQL = @SQL + @CR + SPACE(5) + @IX + ')' + IIF(@FileGroup <> '', ' ON ' + @FileGroup, '') + ','
SET @SQL = @SQL + @CR + @FK
SET @SQL = @SQL + @CR + ')'
IF ((SELECT COUNT(1) FROM @Cols WHERE TextImageFGRequired = 1) > 0) AND @FileGroup <> ''
	SET @SQL = @SQL + 'TEXTIMAGE_ON ' + @FileGroup
IF @SV = '1'
	SET @SQL = @SQL + @CR +  'WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = ' + @TargetSchema + '.' + @SourceTable +'History))' + @CR + @CR
SET @SQL = @SQL + ';'
SET @SQL = @SQL + @CR + 'GO' + @CR
IF (SELECT MAX(IXordinal) FROM @cols) IS NOT NULL
BEGIN
	SET @SQL = @SQL + @CR + @IX + ')' 
	SET @SQL = @SQL + @CR + 'GO' + @CR
END
SET @SQL = @SQL + @CR + @IX_CTId
SET @SQL = @SQL + @CR + 'GO' + @CR
SET @SQL = @SQL + @CR + @EP
--IF @SV = '1'
--	BEGIN
--		SET @SQL = @SQL + @CR +  'ALTER TABLE ' + @TargetSchema + '.' + @SourceTable
--		SET @SQL = @SQL + @CR +  'SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = ' + @TargetSchema + '.' + @SourceTable +'History))' + @CR + @CR
--	END


-- Work Table

SET @SQL_Work = '-- Generated by CreateDWScripts.tt - SQLBuilder_Tables_Stg.sql'	-- No datetime because it will only overwrite if different and date guarantees this
SET @SQL_Work = @SQL_Work + @CR + @CreateTable_Work

SET @iCount = 1
WHILE (SELECT MAX(Id) FROM @Cols AS c) >= @iCount	
BEGIN
	SELECT @SQL_Work = @SQL_Work + @CR + SPACE(5) + QUOTENAME(c.ColName) + SPACE(@MaxColLen + 5 - LEN(QUOTENAME(c.ColName))) + c.DataType + SPACE(18 - LEN(c.DataType)) + IIF(c.Nullable = 'NO', 'NOT NULL', 'NULL') 
		+ CASE WHEN c.DefaultConstraint IS NOT NULL THEN ' CONSTRAINT [DF_' + @TargetSchema + '_' + @SourceTable + '_' + c.ColName + '] DEFAULT (' + c.DefaultConstraint + ')' ELSE '' END	
		+ IIF((SELECT MAX(Id) FROM @Cols AS c) > @iCount, ',', '')
	FROM @Cols AS c
	WHERE c.Id = @iCount
	
	SET @iCount = @iCount + 1
END	

SET @SQL_Work = @SQL_Work + @CR + ') ' --ON [workFG]'

SET @SQL_Work = @SQL_Work + @CR + 'GO' + @CR
 
SELECT @SourceTable + '.sql', @TargetSchema + '\Tables', @SQL
UNION ALL
SELECT @TargetSchema + '_' + @SourceTable + '.sql', 'work\Tables', @SQL_Work