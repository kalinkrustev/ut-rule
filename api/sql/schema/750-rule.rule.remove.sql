ALTER PROCEDURE [rule].[rule.remove]
    @conditionId core.arrayList READONLY,
    @meta core.metaDataTT READONLY -- information for the user that makes the operation
AS
DECLARE @userId BIGINT = (SELECT [auth.actorId] FROM @meta)
BEGIN TRY

    BEGIN TRANSACTION
        DELETE x
        FROM
            [rule].limit x
        JOIN
            @conditionId item ON x.conditionId = item.value

        DELETE x
        FROM
            [rule].conditionActor x
        JOIN
            @conditionId item ON x.conditionId = item.value

        DELETE x
        FROM
            [rule].conditionItem x
        JOIN
            @conditionId item ON x.conditionId = item.value

        DELETE x
        FROM
            [rule].conditionProperty x
        JOIN
            @conditionId item ON x.conditionId = item.value

        DELETE
            x
        FROM
            [rule].splitRange x
        JOIN
            [rule].splitName s ON s.splitNameId = x.splitNameId
        JOIN
            @conditionId item ON s.conditionId = item.value
        DELETE
            x
        FROM
            [rule].splitAnalytic x
        JOIN
            [rule].splitAssignment y ON y.splitAssignmentId = x.splitAssignmentId
        JOIN
            [rule].splitName s ON s.splitNameId = y.splitNameId
        JOIN
            @conditionId item ON s.conditionId = item.value

        DELETE
            x
        FROM
            [rule].splitAssignment x
        JOIN
            [rule].splitName s ON s.splitNameId = x.splitNameId
        JOIN
            @conditionId item ON s.conditionId = item.value
        DELETE
            x
        FROM
            [rule].splitName x
        JOIN
            @conditionId item ON x.conditionId = item.value

        UPDATE x
        SET isDeleted = 1,
        updatedOn = SYSDATETIMEOFFSET(),
        updatedBy = @userId
        FROM
            [rule].condition x
        JOIN
            @conditionId item ON x.conditionId = item.value
    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION
    EXEC core.error
    RETURN 55555
END CATCH
