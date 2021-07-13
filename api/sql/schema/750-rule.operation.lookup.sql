ALTER PROCEDURE [rule].[operation.lookup]
    @operation VARCHAR(100),
    @operationDateTime datetime
AS
    SELECT 'operation' AS resultSetName, 1 single
    SELECT
        n.itemNameId transferTypeId,
        ISNULL(@operationDateTime, GETUTCDATE()) transferDateTime
    FROM
        [core].[itemName] n
    JOIN
        [core].[itemType] t ON n.itemTypeId = t.itemTypeId AND t.alias = 'operation'
    WHERE
        itemCode = @operation
