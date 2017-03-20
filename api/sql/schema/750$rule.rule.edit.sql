﻿ALTER PROCEDURE [rule].[rule.edit]
    @condition [rule].conditionTT READONLY,
    @limit [rule].limitTT READONLY,
    @split XML
AS
SET NOCOUNT ON

DECLARE @splitName table (splitNameId int, rowPosition int)
DECLARE @splitAssignment [rule].splitAssignmentTT
declare @conditionId INT = (SELECT conditionId FROM @condition)

BEGIN TRY
    BEGIN TRANSACTION
    SET @conditionId = (SELECT conditionId FROM @condition)

    UPDATE c
    SET [priority] = c1.[priority],
        channelCountryId = c1.channelCountryId,
        channelRegionId = c1.channelRegionId,
        channelCityId = c1.channelCityId,
        channelOrganizationId = c1.channelOrganizationId,
        channelSupervisorId = c1.channelSupervisorId,
        channelTag = c1.channelTag,
        channelRoleId = c1.channelRoleId,
        channelId = c1.channelId,
        operationId = c1.operationId,
        operationTag = c1.operationTag,
        operationStartDate = c1.operationStartDate,
        operationEndDate = c1.operationEndDate,
        sourceCountryId = c1.sourceCountryId,
        sourceRegionId = c1.sourceRegionId,
        sourceCityId = c1.sourceCityId,
        sourceOrganizationId = c1.sourceOrganizationId,
        sourceSupervisorId = c1.sourceSupervisorId,
        sourceTag = c1.sourceTag,
        sourceId = c1.sourceId,
        sourceCardProductId = c1.sourceCardProductId,
        sourceAccountProductId = c1.sourceAccountProductId,
        sourceAccountId = c1.sourceAccountId,
        destinationCountryId = c1.destinationCountryId,
        destinationRegionId = c1.destinationRegionId,
        destinationCityId = c1.destinationCityId,
        destinationOrganizationId = c1.destinationOrganizationId,
        destinationSupervisorId = c1.destinationSupervisorId,
        destinationTag = c1.destinationTag,
        destinationId = c1.destinationId,
        destinationAccountProductId = c1.destinationAccountProductId,
        destinationAccountId = c1.destinationAccountId
    FROM [rule].condition c
    JOIN @condition c1 ON c.conditionId = c1.conditionId

    merge into [rule].limit l
    using @limit l1 on l.[limitId] = l1.limitId
    when matched then
        update
        set currency = l1.currency,
            minAmount = l1.minAmount,
            maxAmount = l1.maxAmount,
            maxAmountDaily = l1.maxAmountDaily,
            maxCountDaily = l1.maxCountDaily,
            maxAmountWeekly = l1.maxAmountWeekly,
            maxCountWeekly = l1.maxCountWeekly,
            maxAmountMonthly = l1.maxAmountMonthly,
            maxCountMonthly = l1.maxCountMonthly
    when not matched by target then
        insert (conditionId, currency, minAmount, maxAmount, maxAmountDaily, maxCountDaily, maxAmountWeekly, maxCountWeekly, maxAmountMonthly, maxCountMonthly)
        values (@conditionId, l1.currency, l1.minAmount, l1.maxAmount, l1.maxAmountDaily, l1.maxCountDaily, l1.maxAmountWeekly, l1.maxCountWeekly, l1.maxAmountMonthly, l1.maxCountMonthly)
    when not matched by source and l.conditionId = @conditionId then
        delete;

    DELETE x
    FROM [rule].splitRange x
    JOIN [rule].splitName sn ON x.splitNameId = sn.splitNameId
    LEFT JOIN @split.nodes('/data/rows/splitRange/splitRangeId') AS records(x) ON x.splitRangeId = records.x.value('(./text())[1]', 'int')
    WHERE sn.conditionId = @conditionId AND records.x.value('(./text())[1]', 'int') IS NULL

    DELETE x
    FROM [rule].splitAnalytic x
    JOIN [rule].splitAssignment sa ON x.splitAssignmentId = sa.splitAssignmentId
    JOIN [rule].splitName sn ON sa.splitNameId = sn.splitNameId
    LEFT JOIN @split.nodes('/data/rows/splitAssignment/splitAnalytic/splitAnalyticId') AS records(x) ON x.splitAnalyticId = records.x.value('(./text())[1]', 'int')
    WHERE sn.conditionId = @conditionId AND records.x.value('(./text())[1]', 'int') IS NULL

    DELETE x
    FROM [rule].splitAssignment x
    JOIN [rule].splitName sn ON x.splitNameId = sn.splitNameId
    LEFT JOIN @split.nodes('/data/rows/splitAssignment/splitAssignmentId') AS records(x) ON x.splitAssignmentId = records.x.value('(./text())[1]', 'int')
    WHERE sn.conditionId = @conditionId AND records.x.value('(./text())[1]', 'int') IS NULL

    MERGE INTO [rule].splitName x
    USING
    (
        select records.r.value('(./splitNameId)[1]', 'int') as splitNameId,
            records.r.value('(./name/text())[1]', 'varchar(50)') as name,
            records.r.value('(./tag/text())[1]', 'nvarchar(max)') as tag,
            records.r.value('for $a in .. return 1 + count($a/../*[.[(local-name()="rows")] << $a])', 'int') as rowPos
        from @split.nodes('/data/rows/splitName') AS records(r)
    ) as sn ON x.splitNameId = sn.splitNameId
    WHEN MATCHED THEN
      UPDATE
      SET name = sn.name,
            tag = sn.tag
    WHEN NOT MATCHED BY TARGET THEN
      INSERT (conditionId, name, tag)
      VALUES (@conditionId, sn.name, sn.tag)
    WHEN NOT MATCHED BY SOURCE and x.conditionId = @conditionId THEN
        delete
    OUTPUT INSERTED.splitNameId, sn.rowPos INTO @splitName;

    MERGE INTO [rule].splitRange x
    USING
    (
      SELECT records.x.value('(./splitRangeId)[1]', 'int') as splitRangeId,
          sn.splitNameId as splitNameId,
          records.x.value('(./startAmount/text())[1]', 'money') AS startAmount,
          records.x.value('(./startAmountCurrency/text())[1]', 'varchar(3)') AS startAmountCurrency,
          ISNULL(records.x.value('(./startAmountDaily/text())[1]', 'money'), 0) AS startAmountDaily,
          ISNULL(records.x.value('(./startCountDaily/text())[1]', 'bigint'), 0) AS startCountDaily,
          ISNULL(records.x.value('(./startAmountWeekly/text())[1]', 'money'), 0) AS startAmountWeekly,
          ISNULL(records.x.value('(./startCountWeekly/text())[1]', 'bigint'), 0) AS startCountWeekly,
          ISNULL(records.x.value('(./startAmountMonthly/text())[1]', 'money'), 0) AS startAmountMonthly,
          ISNULL(records.x.value('(./startCountMonthly/text())[1]', 'bigint'), 0) AS startCountMonthly,
          ISNULL(records.x.value('(./isSourceAmount/text())[1]', 'bit'), 1) AS isSourceAmount,
          records.x.value('(./minValue/text())[1]', 'money') AS minValue,
          records.x.value('(./maxValue/text())[1]', 'money') AS maxValue,
          records.x.value('(./percent/text())[1]', 'money') AS [percent],
          records.x.value('(./percentBase/text())[1]', 'money') AS percentBase
      FROM @split.nodes('/data/rows/splitRange') AS records(x)
      JOIN @splitName sn on sn.rowPosition = records.x.value('for $a in .. return 1 + count($a/../*[.[(local-name()="rows")] << $a])', 'int')
    ) AS r ON x.splitRangeId = r.splitRangeId
    WHEN MATCHED THEN
        UPDATE
        SET startAmount = r.startAmount,
            startAmountCurrency = r.startAmountCurrency,
            startAmountDaily = r.startAmountDaily,
            startCountDaily = r.startCountDaily,
            startAmountWeekly = r.startAmountWeekly,
            startCountWeekly = r.startCountWeekly,
            startAmountMonthly = r.startAmountMonthly,
            startCountMonthly = r.startCountMonthly,
            isSourceAmount = r.isSourceAmount,
            minValue = r.minValue,
            maxValue = r.maxValue,
            [percent] = r.[percent],
            percentBase = r.percentBase
    WHEN NOT MATCHED by target THEN
      INSERT (
          splitNameId,
          startAmount,
          startAmountCurrency,
          startAmountDaily,
          startCountDaily,
          startAmountWeekly,
          startCountWeekly,
          startAmountMonthly,
          startCountMonthly,
          isSourceAmount,
          minValue,
          maxValue,
          [percent],
          percentBase)
      VALUES (
          r.splitNameId,
          r.startAmount,
          r.startAmountCurrency,
          r.startAmountDaily,
          r.startCountDaily,
          r.startAmountWeekly,
          r.startCountWeekly,
          r.startAmountMonthly,
          r.startCountMonthly,
          r.isSourceAmount,
          r.minValue,
          r.maxValue,
          r.[percent],
          r.percentBase);

    MERGE INTO [rule].splitAssignment x
    USING
    (
        SELECT records.x.value('(./splitAssignmentId)[1]', 'int') as splitAssignmentId,
            sn.splitNameId AS splitNameId,
            records.x.value('(./debit/text())[1]', 'varchar(50)') AS debit,
            records.x.value('(./credit/text())[1]', 'varchar(50)') AS credit,
            records.x.value('(./minValue/text())[1]', 'money') AS minValue,
            records.x.value('(./maxValue/text())[1]', 'money') AS maxValue,
            records.x.value('(./percent/text())[1]', 'decimal') AS [percent],
            records.x.value('(./description/text())[1]', 'varchar(50)') AS description
        FROM @split.nodes('/data/rows/splitAssignment') AS records(x)
        JOIN @splitName sn on sn.rowPosition = records.x.value('for $a in .. return 1 + count($a/../*[.[(local-name()="rows")] << $a])', 'int')
    ) AS r ON x.splitAssignmentId = r.splitAssignmentId
    WHEN MATCHED THEN
      UPDATE
      SET debit = r.debit,
          credit = r.credit,
          minValue = r.minValue,
          maxValue = r.maxValue,
          [percent] = r.[percent],
          description = r.description
    WHEN NOT MATCHED BY TARGET THEN
      INSERT (splitNameId, debit, credit, minValue, maxValue, [percent], description)
      VALUES (r.splitNameId, r.debit, r.credit, r.minValue, r.maxValue, r.[percent], r.description)
	OUTPUT INSERTED.* INTO @splitAssignment;

    MERGE INTO [rule].splitAnalytic x
    USING (
	 SELECT	DISTINCT -- new splitAnalytic & new splitAssignment
		NULL														AS [splitAnalyticId],
		sn.splitAssignmentId										AS [splitAssignmentId],
		splitAssignment.x.query('*').value('(name)[1]', 'nvarchar(50)')		AS [name],
          splitAssignment.x.query('*').value('(value)[1]', 'nvarchar(150)')	AS [value]
      FROM
          @split.nodes('/data/rows/splitAssignment') AS records(x)
      CROSS APPLY
          records.x.nodes('splitAnalytic') AS splitAssignment(x)
      LEFT JOIN @splitAssignment sn ON	 records.x.value('(debit)[1]', 'nvarchar(50)')				= sn.debit
							 AND records.x.value('(credit)[1]', 'nvarchar(50)')				= sn.credit
							 AND records.x.value('(description)[1]', 'nvarchar(50)')			= sn.description
	 WHERE ISNULL(splitAssignment.x.query('*').value('(splitAnalyticId)[1]', 'bigint'), 0) = 0
	 AND   ISNULL(records.x.value('(splitAssignmentId)[1]', 'bigint'), 0)				  = 0
	 UNION ALL
	 SELECT	DISTINCT -- new splitAnalytic & exist splitAssignment
		NULL														AS [splitAnalyticId],
		records.x.value('(splitAssignmentId)[1]', 'bigint')				AS [splitAssignmentId],
		splitAssignment.x.query('*').value('(name)[1]', 'nvarchar(50)')		AS [name],
          splitAssignment.x.query('*').value('(value)[1]', 'nvarchar(150)')	AS [value]
      FROM
          @split.nodes('/data/rows/splitAssignment') AS records(x)
      CROSS APPLY
          records.x.nodes('splitAnalytic') AS splitAssignment(x)
	 WHERE ISNULL(splitAssignment.x.query('*').value('(splitAnalyticId)[1]', 'bigint'), 0) = 0
	 AND   ISNULL(records.x.value('(splitAssignmentId)[1]', 'bigint'), 0)				 <> 0
	 UNION ALL
	 SELECT	 DISTINCT -- exist splitAnalytic & exist splitAssignment
		splitAssignment.x.query('*').value('(splitAnalyticId)[1]', 'bigint')	AS [splitAnalyticId],
		records.x.value('(splitAssignmentId)[1]', 'bigint')				AS [splitAssignmentId],
		splitAssignment.x.query('*').value('(name)[1]', 'nvarchar(50)')		AS [name],
          splitAssignment.x.query('*').value('(value)[1]', 'nvarchar(150)')	AS [value]
      FROM
          @split.nodes('/data/rows/splitAssignment') AS records(x)
      CROSS APPLY
          records.x.nodes('splitAnalytic') AS splitAssignment(x)
	 WHERE ISNULL(splitAssignment.x.query('*').value('(splitAnalyticId)[1]', 'bigint'), 0) <> 0
	 AND   ISNULL(records.x.value('(splitAssignmentId)[1]', 'bigint'), 0)				  <> 0
    ) AS r ([splitAnalyticId], splitAssignmentId, [name], [value])
    ON x.splitAnalyticId = r.splitAnalyticId -- AND ISNULL(r.splitAnalyticId, 0) > 0
    WHEN MATCHED THEN
      UPDATE
      SET [splitAssignmentId]	  = r.[splitAssignmentId],
          [name]			  = r.[name],
          [value]			  = r.[value]
    WHEN NOT MATCHED THEN
      INSERT (splitAssignmentId, [name], [value])
      VALUES (r.splitAssignmentId, r.[name], r.[value])
    OUTPUT $action, DELETED.*, INSERTED.* 
    ;


    COMMIT TRANSACTION

    EXEC [rule].[rule.fetch] @conditionId = @conditionId
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION

    EXEC core.error
    RETURN 55555
END CATCH