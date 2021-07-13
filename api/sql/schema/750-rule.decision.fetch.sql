ALTER PROCEDURE [rule].[decision.fetch]
    @operationProperties [rule].properties READONLY, -- properties collected based on the input information that will be checked against rule conditions (roles, products etc.)
    @operationDate DATETIME, -- the date when operation is triggered
    @sourceAccountId NVARCHAR(255), -- source account id
    @destinationAccountId NVARCHAR(255), -- destination account id
    @amount MONEY, -- operation amount
    @totals [rule].totals READONLY, -- totals by transfer type (amountDaily, countDaily, amountWeekly ... etc.)
    @currency VARCHAR(3), -- operation currenc
    @isSourceAmount BIT,
    @sourceAccount VARCHAR(100), -- source account number
    @destinationAccount VARCHAR(100), -- destination account number
    @maxAmountParam MONEY, -- max amount from account or account product, after which credential validation is required
    @credentialsCheck INT, -- credentials from account or account product
    @credentials INT = NULL, -- the passed credentials to validate operation success
    @isTransactionValidate BIT = 0 -- flag showing if operation is only validated (1) or executed (0)
AS
BEGIN
    DECLARE @transferTypeId BIGINT
    SELECT
        @transferTypeId = CAST(value AS BIGINT)
    FROM
        @operationProperties
    WHERE
        name = 'operation.id'

    DECLARE @matches TABLE (
        [priority] INT,
        conditionId BIGINT,
        amountDaily money,
        countDaily BIGINT,
        amountWeekly money,
        countWeekly BIGINT,
        amountMonthly money,
        countMonthly BIGINT
    )

    SET @operationDate = ISNULL(@operationDate, GETUTCDATE())

    DECLARE
        @calcCommission MONEY,
        @minCommission MONEY,
        @maxCommission MONEY,
        @idCommission BIGINT,
        @minAmount MONEY,
        @maxAmount MONEY,
        @amountDaily MONEY,
        @countDaily BIGINT,
        @amountWeekly MONEY,
        @countWeekly BIGINT,
        @amountMonthly MONEY,
        @countMonthly BIGINT,
        @maxAmountDaily MONEY,
        @maxCountDaily BIGINT,
        @maxAmountWeekly MONEY,
        @maxCountWeekly BIGINT,
        @maxAmountMonthly MONEY,
        @maxCountMonthly BIGINT,
        @checkSuccess BIT,
        @limitCredentials INT,
        @limitMaxAmount MONEY,
        @limitId INT

    --find all conditions(rules) that match based on the input information
    INSERT INTO
        @matches(
            [priority],
            conditionId,
            amountDaily,
            countDaily,
            amountWeekly,
            countWeekly,
            amountMonthly,
            countMonthly)
    SELECT
        c.[priority],
        c.conditionId,
        ISNULL(SUM(t.amountDaily), 0),
        ISNULL(SUM(t.countDaily), 0),
        ISNULL(SUM(t.amountWeekly), 0),
        ISNULL(SUM(t.countWeekly), 0),
        ISNULL(SUM(t.amountMonthly), 0),
        ISNULL(SUM(t.countMonthly), 0)
    FROM
        [rule].condition c
    LEFT JOIN
        [rule].vConditionOperation co ON co.conditionId = c.conditionId
    LEFT JOIN
        @totals t ON t.transferTypeId = ISNULL(co.transferTypeId, @transferTypeId)
    WHERE
        c.isDeleted = 0 AND
        (@operationDate IS NULL OR c.operationStartDate IS NULL OR (@operationDate >= c.operationStartDate)) AND
        (@operationDate IS NULL OR c.operationEndDate IS NULL OR (@operationDate <= c.operationEndDate)) AND
        [rule].falseActorFactorCount(c.conditionId, @operationProperties) = 0 AND
        [rule].falseItemFactorCount(c.conditionId, @operationProperties) = 0 AND
        [rule].falsePropertyFactorCount(c.conditionId, @operationProperties) = 0 AND
        (@sourceAccountId IS NULL OR c.sourceAccountId IS NULL OR @sourceAccountId = c.sourceAccountId) AND
        (@destinationAccountId IS NULL OR c.destinationAccountId IS NULL OR @destinationAccountId = c.destinationAccountId)
    GROUP BY
        c.[priority], c.conditionId

    SELECT
        @minAmount = NULL,
        @maxAmount = NULL,
        @maxAmountDaily = NULL,
        @maxCountDaily = NULL,
        @maxAmountWeekly = NULL,
        @maxCountWeekly = NULL,
        @maxAmountMonthly = NULL,
        @maxCountMonthly = NULL

    -- check if exists a condition limit that is violated
    SELECT TOP 1
        @limitId = l.limitId,
        @minAmount = l.minAmount,
        @maxAmount = l.maxAmount,
        @maxAmountDaily = l.maxAmountDaily,
        @maxCountDaily = l.maxCountDaily,
        @maxAmountWeekly = l.maxAmountWeekly,
        @maxCountWeekly = l.maxCountWeekly,
        @maxAmountMonthly = l.maxAmountMonthly,
        @maxCountMonthly = l.maxCountMonthly,
        @amountDaily = ISNULL(c.amountDaily, 0),
        @countDaily = ISNULL(c.countDaily, 0),
        @amountWeekly = ISNULL(c.amountWeekly, 0),
        @countWeekly = ISNULL(c.countWeekly, 0),
        @amountMonthly = ISNULL(c.amountMonthly, 0),
        @countMonthly = ISNULL(c.countMonthly, 0),
        @limitCredentials = l.[credentials]
    FROM
        @matches AS c
    JOIN
        [rule].limit AS l ON l.conditionId = c.conditionId
    WHERE
        l.currency = @currency AND (--violation of condition limits
            @amount < l.minAmount OR
            @amount > l.maxAmount OR
            @amount + ISNULL(c.amountDaily, 0) > l.maxAmountDaily OR
            @amount + ISNULL(c.amountWeekly, 0) > l.maxAmountWeekly OR
            @amount + ISNULL(c.amountMonthly, 0) > l.maxAmountMonthly OR
            ISNULL(c.countDaily, 0) >= l.maxCountDaily OR
            ISNULL(c.countWeekly, 0) >= l.maxCountWeekly OR
            ISNULL(c.countMonthly, 0) >= l.maxCountMonthly
        ) AND (--violation of limit credentials
            @credentials IS NULL OR -- no checked credentials passed by the backend
            ISNULL(l.[credentials], 0) = 0 OR -- limit credentials equal to NULL or 0 means that condition limits cannot be exceeded
            @credentials & ISNULL (@credentialsCheck, l.[credentials]) <> ISNULL (@credentialsCheck, l.[credentials])
        )
    ORDER BY
        c.[priority],
        l.[priority]

    IF @limitId IS NOT NULL -- if exists a condition limit which is violated, identify the exact violation and return error with result
    BEGIN
        DECLARE @type VARCHAR (20) = CASE WHEN ISNULL(@limitCredentials, 0) = 0 THEN 'rule.exceed' ELSE 'rule.unauthorized' END
        DECLARE @error VARCHAR (50) = CASE
            WHEN @amount > @maxAmount THEN @type + 'MaxLimitAmount'
            WHEN @amount < @minAmount THEN @type + 'MinLimitAmount'
            WHEN @amountDaily >= @maxAmountDaily THEN 'rule.reachedDailyLimitAmount'
            WHEN @amountWeekly >= @maxAmountWeekly THEN 'rule.reachedWeeklyLimitAmount'
            WHEN @amountMonthly >= @maxAmountMonthly THEN 'rule.reachedMonthlyLimitAmount'
            WHEN @amount + @amountDaily > @maxAmountDaily THEN @type + 'DailyLimitAmount'
            WHEN @amount + @amountWeekly > @maxAmountWeekly THEN @type + 'WeeklyLimitAmount'
            WHEN @amount + @amountMonthly > @maxAmountMonthly THEN @type + 'MonthlyLimitAmount'
            WHEN @countDaily >= @maxCountDaily THEN @type + 'DailyLimitCount'
            WHEN @countWeekly >= @maxCountWeekly THEN @type + 'WeeklyLimitCount'
            WHEN @countMonthly >= @maxCountMonthly THEN @type + 'MonthlyLimitCount'
        END

        SELECT
            'ut-error' resultSetName,
            @error type,
            @minAmount AS minAmount,
            ISNULL (@maxAmountParam, @maxAmount) AS maxAmount,
            @maxAmountDaily AS maxAmountDaily,
            @maxCountDaily AS maxCountDaily,
            @maxAmountWeekly AS maxAmountWeekly,
            @maxCountWeekly AS maxCountWeekly,
            @maxAmountMonthly AS maxAmountMonthly,
            @maxCountMonthly AS maxCountMonthly,
            @amountDaily AS amountDaily,
            @countDaily AS countDaily,
            @amountWeekly AS amountWeekly,
            @countWeekly AS countWeekly,
            @amountMonthly AS amountMonthly,
            @countMonthly AS countMonthly,
            @amount AS amount,
            @amount + @amountDaily AS accumulatedAmountDaily,
            @amount + @amountWeekly AS accumulatedAmountWeekly,
            @amount + @amountMonthly AS accumulatedAmountMonthly,
            ISNULL (@credentialsCheck, @limitCredentials) AS [credentials]

        IF ISNULL (@isTransactionValidate, 0) = 0 RETURN -- if only validation - proceed, else stop execution
    END
    ELSE -- if not exists a condition limit which is violated, check if credentials are correct. If not return error and result
    IF @amount > @maxAmountParam AND ISNULL(@credentials, 0) & @credentialsCheck <> @credentialsCheck
    BEGIN
        SELECT
            'ut-error' resultSetName,
            CASE WHEN ISNULL(@credentialsCheck, 0) = 0 THEN 'rule.exceed' ELSE 'rule.unauthorized' END + 'MaxLimitAmount' type,
            @maxAmountParam AS maxAmount,
            @minAmount AS minAmount,
            @maxAmountDaily AS maxAmountDaily,
            @maxCountDaily AS maxCountDaily,
            @maxAmountWeekly AS maxAmountWeekly,
            @maxCountWeekly AS maxCountWeekly,
            @maxAmountMonthly AS maxAmountMonthly,
            @maxCountMonthly AS maxCountMonthly,
            @amountDaily AS amountDaily,
            @countDaily AS countDaily,
            @amountWeekly AS amountWeekly,
            @countWeekly AS countWeekly,
            @amountMonthly AS amountMonthly,
            @countMonthly AS countMonthly,
            @amount AS amount,
            @amount + @amountDaily AS accumulatedAmountDaily,
            @amount + @amountWeekly AS accumulatedAmountWeekly,
            @amount + @amountMonthly AS accumulatedAmountMonthly,
            @credentialsCheck AS [credentials]

        IF ISNULL (@isTransactionValidate, 0) = 0 RETURN -- if only validation - proceed, else stop execution
    END

    DECLARE @fee TABLE(
        conditionId INT,
        splitNameId INT,
        fee MONEY,
        tag VARCHAR(MAX)
    );

    -- calculate the operation fees based on the matched conditions (rules), and select these with highest priority
    WITH split(conditionId, splitNameId, tag, minFee, maxFee, calcFee, rnk1, rnk2) AS (
        SELECT
            c.conditionId,
            r.splitNameId,
            n.tag,
            r.minValue,
            r.maxValue,
            ISNULL(r.[percent], 0) * CASE
                WHEN @amount > ISNULL(r.percentBase, 0) THEN @amount - ISNULL(r.percentBase, 0)
                ELSE 0
            END / 100,
            RANK() OVER (PARTITION BY n.splitNameId ORDER BY
                c.priority,
                r.startCountMonthly DESC,
                r.startAmountMonthly DESC,
                r.startCountWeekly DESC,
                r.startAmountWeekly DESC,
                r.startCountDaily DESC,
                r.startAmountDaily DESC,
                r.startAmount DESC,
                r.splitRangeId),
            RANK() OVER (ORDER BY c.priority, c.conditionId)
        FROM
            @matches AS c
        JOIN
            [rule].splitName AS n ON n.conditionId = c.conditionId
        JOIN
            [rule].splitRange AS r ON r.splitNameId = n.splitNameId
        WHERE
            @currency = r.startAmountCurrency AND
            COALESCE(@isSourceAmount, 0) = r.isSourceAmount AND
            @amount >= r.startAmount AND
            c.amountDaily >= r.startAmountDaily AND
            c.countDaily >= r.startCountDaily AND
            c.amountWeekly >= r.startAmountWeekly AND
            c.countWeekly >= r.startCountWeekly AND
            c.amountMonthly >= r.startAmountMonthly AND
            c.countMonthly >= r.startCountMonthly
    )
    INSERT INTO
        @fee(conditionId, splitNameId, fee, tag)
    SELECT
        s.conditionId,
        s.splitNameId,
        CASE
            WHEN s.calcFee > s.maxFee THEN s.maxFee
            WHEN s.calcFee < s.minFee THEN s.minFee
            ELSE s.calcFee
        END fee,
        s.tag
    FROM
        split s
    WHERE
        s.rnk1 = 1 AND
        s.rnk2 = 1

    SELECT 'amount' AS resultSetName, 1 single
    SELECT
        (SELECT SUM(ISNULL(fee, 0)) FROM @fee WHERE tag LIKE '%|acquirer|%' AND tag LIKE '%|fee|%') acquirerFee,
        (SELECT SUM(ISNULL(fee, 0)) FROM @fee WHERE tag LIKE '%|issuer|%' AND tag LIKE '%|fee|%') issuerFee,
        NULL processorFee, -- @TODO calc processor fee
        (SELECT SUM(ISNULL(fee, 0)) FROM @fee WHERE tag LIKE '%|commission|%') commission,
        @operationDate transferDateTime,
        @transferTypeId transferTypeId

    DECLARE @map [core].map

    -- calculate the splits based on the selected condition
    INSERT INTO
        @map([key], [value])
    SELECT
        '$' + '{' + name + '}', CASE WHEN factor IN ('so', 'do', 'co') THEN 'actor:' ELSE 'item:' END + CAST(value AS VARCHAR(100))
    FROM
        @operationProperties

    INSERT INTO
        @map([key], [value])
    VALUES -- note that ${} is replaced by SQL port
        ('$' + '{operation.currency}', CAST(@currency AS VARCHAR(100))),
        ('$' + '{source.account.id}', 'account:' + CAST(@sourceAccountId AS VARCHAR(100))),
        ('$' + '{source.account.number}', CAST(@sourceAccount AS VARCHAR(100))),
        ('$' + '{destination.account.id}', 'account:' + CAST(@destinationAccountId AS VARCHAR(100))),
        ('$' + '{destination.account.number}', CAST(@destinationAccount AS VARCHAR(100)))

    DELETE FROM @map WHERE [value] IS NULL

    SELECT 'split' AS resultSetName
    SELECT
        a.conditionId,
        a.splitNameId,
        a.tag,
        CONVERT(VARCHAR, CAST(CASE
            WHEN assignment.[percent] * a.fee / 100 > assignment.maxValue THEN maxValue
            WHEN assignment.[percent] * a.fee / 100 < assignment.minValue THEN minValue
            ELSE assignment.[percent] * a.fee / 100
        END AS MONEY), 2) amount,
        ISNULL(d.accountNumber, assignment.debit) debit,
        ISNULL(c.accountNumber, assignment.credit) credit,
        assignment.description,
        assignment.analytics
    FROM
        @fee a
    CROSS APPLY
        [rule].assignment(a.splitNameId, @map) assignment
    LEFT JOIN
        integration.vAssignment d ON d.accountId = assignment.debit
    LEFT JOIN
        integration.vAssignment c ON c.accountId = assignment.credit
END
