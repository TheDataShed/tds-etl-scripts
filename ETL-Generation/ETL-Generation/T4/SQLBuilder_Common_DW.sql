DECLARE @SourceSchema sysname = '<SourceSchema>'	-- 'dw'
	, @SourceTable sysname = '<SourceTable>'		-- 'dimCase'
	, @TargetSchema sysname = '<TargetSchema>'
	, @SV NCHAR(1) 			= '<SystemVersioning>'
	, @IXType CHAR(12) = '<IXType>'
	, @MaxColLen INT
	, @SQL VARCHAR(MAX)
	, @iCount INT
	, @CR CHAR(2) = CHAR(13) + CHAR(10) 
	, @TB INT = 4
DECLARE @ProcPrefix VARCHAR(10) = ''

DECLARE @Cols TABLE (Id INT IDENTITY(1,1), ColName VARCHAR(100), OrigDataType VARCHAR(20), DataType VARCHAR(20), Nullable VARCHAR(3), TableOrdinal INT, PKOrdinal INT, DefaultConstraint VARCHAR(100), TextImageFGRequired BIT, LkupTable VARCHAR(200), FKColumn VARCHAR(200))

INSERT INTO @Cols (ColName,OrigDataType,DataType,Nullable,TableOrdinal,PKOrdinal,DefaultConstraint,TextImageFGRequired,LkupTable,FKColumn)
	SELECT * 
		FROM (
				SELECT COALESCE(fk.DestColumn, c.name)		AS Name
					, UPPER(c.system_type_name)				AS OrigDataType 
					, IIF(fk.SourceColumn IS NOT NULL, 'INT', UPPER(c.system_type_name))			
															AS DataType 
					, CASE WHEN c.name IN ('CTId','IsDeleted') THEN 'NO'
						WHEN pk.name IS NOT NULL THEN 'NO'
						WHEN nn.name IS NOT NULL THEN 'YES'
						ELSE 'NO'
					  END									AS Nullable
					, c.column_ordinal 						AS TableOrdinal
					, CASE WHEN c.name = 'CTId' THEN -10
						WHEN c.name = 'IsDeleted' THEN -8
						ELSE RIGHT(pk.name,1) END 			AS PKOrdinal
					, CASE WHEN c.name = 'CTId' THEN '-1'
					    WHEN c.name = 'IsDeleted' THEN '0'
					    ELSE NULL
					  END									AS DefaultConstraint
					, IIF(c.system_type_name = 'text' OR c.max_length = -1 OR c.max_length > 8060, 1, 0) 
															AS TextImageFGRequired
					, fk.LkupTable							AS LkupTable
					, fk.FkColumn							AS FKColumn
							
				FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID(@SourceSchema + '.' + @ProcPrefix + @SourceTable), NULL) AS c 
					LEFT JOIN sys.extended_properties AS pk ON pk.value = c.name
						AND pk.major_id = OBJECT_ID(@SourceSchema + '.' + @ProcPrefix + @SourceTable)
						AND pk.name LIKE 'BK%'
					LEFT JOIN (SELECT r.major_id
									, RIGHT(name, LEN(name) - IIF(LEFT(name, 6) = 'FKLkup', 6, 2)) 
																						AS SourceColumn
									, CASE WHEN LEFT(name, 6) = 'FKLkup' AND RIGHT(name, 2) = 'Id'  THEN LEFT(RIGHT(name, LEN(name) - 6),  LEN(name) - 8) + 'Key'
										   WHEN LEFT(name, 6) = 'FKLkup' AND RIGHT(name, 3) <> 'Key' THEN RIGHT(name, LEN(name) - 6) + 'Key'
										   ELSE RIGHT(name, LEN(name) - IIF(LEFT(name, 6) = 'FKLkup', 6, 2))
									  END												AS DestColumn
									, LEFT(value, CHARINDEX(',', value) - 1)			AS FkColumn
									, SUBSTRING(value, CHARINDEX(',', value)+1, 200)	AS LkupTable
									FROM (
										SELECT e.major_id
											, CONVERT(VARCHAR(200), e.name) AS name
											, CONVERT(VARCHAR(200), e.value) AS value
											FROM sys.extended_properties AS e
											WHERE e.name LIKE 'FK%'
										) r
								) AS fk ON fk.SourceColumn = c.name
						AND fk.major_id = OBJECT_ID(@SourceSchema + '.' + @ProcPrefix + @SourceTable)
					LEFT JOIN sys.extended_properties AS nn ON nn.value = c.name
						AND nn.major_id = OBJECT_ID(@SourceSchema + '.' + @ProcPrefix + @SourceTable)
						AND nn.name LIKE 'NULL%'

				UNION ALL SELECT 'BIDateCreated', 'DATETIME', 'DATETIME', 'NO', -1, -7, 'GETUTCDATE()', 0, NULL, NULL
				UNION ALL SELECT 'BIDateModified', 'DATETIME', 'DATETIME', 'NO', -1, -6, 'GETUTCDATE()', 0, NULL, NULL
			) a
		ORDER BY COALESCE(PKOrdinal, 1000), TableOrdinal

SELECT @MaxColLen = MAX(LEN(c.ColName)) FROM (SELECT ColName FROM @Cols UNION SELECT @SourceTable + 'Key') c
