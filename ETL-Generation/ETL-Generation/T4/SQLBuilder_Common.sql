DECLARE @SourceSchema sysname = '<SourceSchema>'	-- 'dw'
	, @SourceTable sysname = '<SourceTable>'		-- 'Case'
	, @MaxColLen INT
	, @SQL VARCHAR(MAX)
	, @iCount INT
	, @CR CHAR(2) = CHAR(13) + CHAR(10) 
	, @TB INT = 4

DECLARE @Cols TABLE (Id INT IDENTITY(1,1), ColName VARCHAR(100), OrigDataType VARCHAR(20), DataType VARCHAR(20), Nullable VARCHAR(3), TableOrdinal INT, PKOrdinal INT, DefaultConstraint VARCHAR(100), TextImageFGRequired BIT)

INSERT INTO @Cols (ColName,OrigDataType,DataType,Nullable,TableOrdinal,PKOrdinal,DefaultConstraint,TextImageFGRequired)
	SELECT * 
		FROM (
			SELECT   
				 c.COLUMN_NAME							AS ColName
				, UPPER(c.DATA_TYPE) + IIF(c.CHARACTER_MAXIMUM_LENGTH IS NULL, '', '(' + CONVERT(VARCHAR(5),c.CHARACTER_MAXIMUM_LENGTH) + ')')			
														AS OrigDataType 
				, UPPER(c.DATA_TYPE) + IIF(c.CHARACTER_MAXIMUM_LENGTH IS NULL, '', '(' + CONVERT(VARCHAR(5),c.CHARACTER_MAXIMUM_LENGTH) + ')')
														AS DataType				
				, c.IS_NULLABLE							AS Nullable
				, c.ORDINAL_POSITION					AS TableOrdinal
				, CASE WHEN c.COLUMN_NAME = 'CTId' THEN -10
						WHEN c.COLUMN_NAME = 'IsDeleted' THEN -8
						WHEN c.COLUMN_NAME = 'BIDateCreated' THEN -7
						WHEN c.COLUMN_NAME = 'BIDateModified' THEN -6
						ELSE COALESCE(uk.Ordinal, pk.Ordinal)		
				   END									AS PKOrdinal
				, CASE WHEN c.COLUMN_NAME IN ('BIDateCreated', 'BIDateModified') THEN  'GETUTCDATE()'
					   WHEN c.COLUMN_NAME = 'CTId' THEN '-1'
					   WHEN c.COLUMN_NAME = 'IsDeleted' THEN '0'
					   ELSE NULL
				  END									AS DefaultConstraint
				, IIF(c.DATA_TYPE = 'text' OR c.CHARACTER_MAXIMUM_LENGTH = -1 OR c.CHARACTER_MAXIMUM_LENGTH > 8060, 1, 0) 
															AS TextImageFGRequired
			FROM INFORMATION_SCHEMA.COLUMNS AS c 
				LEFT JOIN (
					SELECT ku.TABLE_SCHEMA,ku.TABLE_NAME,ku.COLUMN_NAME, ku.ORDINAL_POSITION AS Ordinal
					FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS tc
						INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS ku
						ON tc.TABLE_SCHEMA = ku.TABLE_SCHEMA AND tc.TABLE_NAME = ku.TABLE_NAME AND tc.CONSTRAINT_NAME = ku.CONSTRAINT_NAME
					WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
					  AND NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc1 
								      WHERE tc1.TABLE_SCHEMA = tc.TABLE_SCHEMA
								        AND tc1.TABLE_NAME = tc.TABLE_NAME
									    AND tc1.CONSTRAINT_TYPE = 'UNIQUE')
				) pk ON c.TABLE_SCHEMA = pk.TABLE_SCHEMA
					AND c.TABLE_NAME = pk.TABLE_NAME
					AND c.COLUMN_NAME = pk.COLUMN_NAME
				LEFT JOIN (
					SELECT ku.TABLE_SCHEMA,ku.TABLE_NAME,ku.COLUMN_NAME, ku.ORDINAL_POSITION AS Ordinal
					FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS tc
						INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS ku
						ON tc.TABLE_SCHEMA = ku.TABLE_SCHEMA AND tc.TABLE_NAME = ku.TABLE_NAME AND tc.CONSTRAINT_NAME = ku.CONSTRAINT_NAME
					WHERE tc.CONSTRAINT_TYPE = 'UNIQUE'
				) uk ON c.TABLE_SCHEMA = uk.TABLE_SCHEMA
					AND c.TABLE_NAME = uk.TABLE_NAME
					AND c.COLUMN_NAME = uk.COLUMN_NAME
			WHERE c.TABLE_SCHEMA = @SourceSchema AND c.TABLE_NAME = @SourceTable
			  AND (COLUMNPROPERTY(object_id(c.TABLE_SCHEMA + '.' + c.TABLE_NAME), c.COLUMN_NAME, 'IsIdentity') = 0)
			) a
		ORDER BY COALESCE(PKOrdinal, 1000), TableOrdinal

SELECT @MaxColLen = MAX(LEN(c.ColName)) FROM @Cols AS c		
