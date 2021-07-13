ALTER PROCEDURE [rule].[decision.lookup]
    @channelId BIGINT, -- the id of the channel triggering transaction
    @operation VARCHAR(100), -- the operation name
    @operationDate datetime, -- the date when operation is triggered
    @sourceAccount VARCHAR(100), -- source account number
    @sourceCardProductId BIGINT = NULL, -- product id of the card
    @destinationAccount VARCHAR(100), -- destination account number
    @amount money, -- operation amount
    @currency VARCHAR(3), -- operation currency
    @isSourceAmount BIT = 0,
    @sourceAccountOwnerId BIGINT = NULL, -- the source account owner id
    @destinationAccountOwnerId BIGINT = NULL, -- the destination account owner id
    @credentials INT = NULL, -- the passed credentials to validate operation success
    @isTransactionValidate BIT = 0 -- flag showing if operation is only validated (1) or executed (0)
AS
BEGIN
    DECLARE
        @channelCountryId BIGINT,
        @channelRegionId BIGINT,
        @channelCityId BIGINT,

        @operationId BIGINT,

        @sourceCountryId BIGINT,
        @sourceRegionId BIGINT,
        @sourceCityId BIGINT,
        @sourceOwnerId BIGINT,
        @sourceAccountProductId BIGINT,
        @sourceAccountId NVARCHAR(255),
        @sourceAccountCheckAmount MONEY,
        @sourceAccountCheckMask INT,
        @sourceProductCheckAmount MONEY,
        @sourceProductCheckMask INT,
        @maxAmountParam MONEY,
        @credentialsCheck INT,

        @destinationCountryId BIGINT,
        @destinationRegionId BIGINT,
        @destinationCityId BIGINT,
        @destinationOwnerId BIGINT,
        @destinationAccountProductId BIGINT,
        @destinationAccountId NVARCHAR(255),

        @totals [rule].totals

    SELECT
        @channelCountryId = countryId,
        @channelRegionId = regionId,
        @channelCityId = cityId
    FROM
        [integration].[vChannel]
    WHERE
        channelId = @channelId

    SELECT
        @operationId = n.itemNameId
    FROM
        [core].[itemName] n
    JOIN
        [core].[itemType] t ON n.itemTypeId = t.itemTypeId AND t.alias = 'operation'
    WHERE
        itemCode = @operation

    SELECT
        @sourceCountryId = countryId,
        @sourceRegionId = regionId,
        @sourceCityId = cityId,
        @sourceOwnerId = ownerId,
        @sourceAccountProductId = accountProductId,
        @sourceAccountId = accountId,
        @sourceAccountCheckAmount = accountCheckAmount,
        @sourceAccountCheckMask = accountCheckMask,
        @sourceProductCheckAmount = productCheckAmount,
        @sourceProductCheckMask = productCheckMask
    FROM
        [integration].[vAccount]
    WHERE
        accountNumber = @sourceAccount AND
        (ownerId = @sourceAccountOwnerId OR @sourceAccountOwnerId IS NULL)

    SELECT
        @destinationCountryId = countryId,
        @destinationRegionId = regionId,
        @destinationCityId = cityId,
        @destinationOwnerId = ownerId,
        @destinationAccountProductId = accountProductId,
        @destinationAccountId = accountId
    FROM
        [integration].[vAccount]
    WHERE
        accountNumber = @destinationAccount AND
        (ownerId = @destinationAccountOwnerId OR @destinationAccountOwnerId IS NULL)

    -- if check amount has been setup for the account and/or the account product, assign the value to variable. account is with higher priority
    SET @maxAmountParam = CASE WHEN COALESCE (@sourceAccountCheckAmount, @sourceProductCheckAmount, 0) = 0 THEN NULL ELSE ISNULL (@sourceAccountCheckAmount, @sourceProductCheckAmount) END
    -- if check credentials has been setup for the account and/or the account product, assign the value to variable. account is with higher priority
    SET @credentialsCheck = CASE WHEN COALESCE (@sourceAccountCheckMask, @sourceProductCheckMask, 0) = 0 THEN NULL ELSE ISNULL (@sourceAccountCheckMask, @sourceProductCheckMask) END

    SELECT @operationDate = ISNULL(@operationDate, GETUTCDATE())

    INSERT INTO
        @totals(transferTypeId, amountDaily, countDaily, amountWeekly, countWeekly, amountMonthly, countMonthly)
    SELECT -- totals by transfer type
        t.transferTypeId,
        ISNULL(SUM(CASE WHEN t.transferDateTime >= DATEADD(DAY, DATEDIFF(DAY, 0, @operationDate), 0) THEN t.transferAmount ELSE 0 END), 0),
        ISNULL(SUM(CASE WHEN t.transferDateTime >= DATEADD(DAY, DATEDIFF(DAY, 0, @operationDate), 0) THEN 1 ELSE 0 END), 0),
        ISNULL(SUM(CASE WHEN t.transferDateTime >= DATEADD(WEEK, DATEDIFF(WEEK, 0, @operationDate - 1), 0) THEN t.transferAmount ELSE 0 END), 0), --week starts on Mon
        ISNULL(SUM(CASE WHEN t.transferDateTime >= DATEADD(WEEK, DATEDIFF(WEEK, 0, @operationDate - 1), 0) THEN 1 ELSE 0 END), 0), --week starts on Mon
        ISNULL(SUM(t.transferAmount), 0),
        ISNULL(COUNT(t.transferAmount), 0)
    FROM
        [integration].[vTransfer] t
    WHERE
        t.success = 1 AND
        t.sourceAccount = @sourceAccount AND
        t.transferCurrency = @currency AND
        t.transferDateTime < @operationDate AND -- look ony at earlier transfers
        t.transferDateTime >= DATEADD(MONTH, DATEDIFF(MONTH, 0, @operationDate), 0) --look back up to the start of month
    GROUP BY
        t.transferTypeId

    DECLARE
        @operationProperties [rule].properties

    INSERT INTO
        @operationProperties(factor, name, value)
    SELECT
        'co', 'channel.role' + CASE WHEN g.level > 0 THEN '^' + CAST(g.level AS VARCHAR(10)) ELSE '' END, r.actorId
    FROM
        core.actorGraph(@channelId, 'memberOf', 'subject') g
    CROSS APPLY
        core.actorGraph(g.actorId, 'role', 'subject') r
    WHERE
        g.actorId <> r.actorId
    UNION SELECT
        'so', 'source.owner.id' + CASE WHEN g.level > 0 THEN '^' + CAST(g.level AS VARCHAR(10)) ELSE '' END, g.actorId
    FROM
        core.actorGraph(@sourceOwnerId, 'memberOf', 'subject') g
    UNION SELECT
        'do', 'destination.owner.id' + CASE WHEN g.level > 0 THEN '^' + CAST(g.level AS VARCHAR(10)) ELSE '' END, g.actorId
    FROM
        core.actorGraph(@destinationOwnerId, 'memberOf', 'subject') g
    UNION SELECT
        'co', 'channel.id' + CASE WHEN g.level > 0 THEN '^' + CAST(g.level AS VARCHAR(10)) ELSE '' END, g.actorId
    FROM
        core.actorGraph(@channelId, 'memberOf', 'subject') g
    UNION SELECT
        'co', 'agentOf.id' + CASE WHEN g.level > 0 THEN '^' + CAST(g.level AS VARCHAR(10)) ELSE '' END, g.actorId
    FROM
        core.actorGraph(@channelId, 'agentOf', 'subject') g

    INSERT INTO
        @operationProperties(factor, name, value)
    VALUES
        --channel spatial
        ('cs', 'channel.country', @channelCountryId),
        ('cs', 'channel.region', @channelRegionId),
        ('cs', 'channel.city', @channelCityId),
        --operation category
        ('oc', 'operation.id', @operationId),
        --source spatial
        ('ss', 'source.country', @sourceCountryId),
        ('ss', 'source.region', @sourceRegionId),
        ('ss', 'source.city', @sourceCityId),
        --source category
        ('sc', 'source.account.product', @sourceAccountProductId),
        ('sc', 'source.card.product', @sourceCardProductId),
        --destination spatial
        ('ds', 'destination.country', @destinationCountryId),
        ('ds', 'destination.region', @destinationRegionId),
        ('ds', 'destination.city', @destinationCityId),
        --destination category
        ('dc', 'destination.account.product', @destinationAccountProductId)

    DELETE FROM @operationProperties WHERE value IS NULL

    EXEC [rule].[decision.fetch]
        @operationProperties = @operationProperties,
        @operationDate = @operationDate,
        @sourceAccountId = @sourceAccountId,
        @destinationAccountId = @destinationAccountId,
        @amount = @amount,
        @totals = @totals,
        @currency = @currency,
        @isSourceAmount = @isSourceAmount,
        @sourceAccount = @sourceAccount,
        @destinationAccount = @destinationAccount,
        @maxAmountParam = @maxAmountParam,
        @credentialsCheck = @credentialsCheck,
        @credentials = @credentials,
        @isTransactionValidate = @isTransactionValidate
END
