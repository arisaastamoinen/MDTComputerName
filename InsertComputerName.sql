USE [MDT]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- CREATE 
CREATE PROCEDURE [dbo].[InsertComputerName]
	@MacAddress CHAR(17)
	,@ComputerType Char(1) -- K / P 
	,@AssetTag	nvarchar(255) = null
	,@UUID	 nvarchar(50) = null
	,@SerialNumber	nvarchar(255) = null
	,@OldHostName nvarchar(255) = null

AS

DECLARE @Cnt INT, @IDVal INT,
        @Prefix VARCHAR(50),
        @Sequence INT,
        @NewName VARCHAR(50)

SET NOCOUNT ON

/* See if there is an existing record for this machine */

/*
-- Cannot use MAC as there may be multiple computers using the same USB Dock Station

SELECT @Cnt=COUNT(*) FROM ComputerIdentity
WHERE MacAddress = @MacAddress
*/
SELECT @Cnt=COUNT(*) FROM ComputerIdentity
WHERE UUID = @UUID

/* No record?  Add one.  */

IF @Cnt = 0
BEGIN

    /* Create a new machine name */

	BEGIN TRANSACTION 

	SELECT @Prefix=[Prefix], @Sequence=[Sequence] FROM MachineNameSequence
    
	SET @Sequence = @Sequence + 1
    
	UPDATE MachineNameSequence SET [Sequence] = @Sequence
		
	/* MDT Does NOT detect all new laptops */
	SET @NewName = @Prefix + REPLACE(@ComputerType, ' ', 'X') + Right('0000'+LTrim(Str(@Sequence)),4)

	/* Insert the new record */
	/* This is for MDT, for possible later use */
	INSERT INTO ComputerIdentity ([MacAddress], [Description], [AssetTag], [UUID], [SerialNumber]) 
	VALUES (@MacAddress, @OldHostName + ' --> ' + @NewName, @AssetTag, @UUID, @SerialNumber)
		
	SELECT @IDVal = @@IDENTITY
		
	INSERT INTO Settings ([Type], [ID], [OSDComputerName], [OSInstall], [SkipComputerName]) 
	VALUES ('C', @IDVal , @NewName, 'Y', 'YES')

	/* insert names to our names transformation table */
	INSERT INTO ComputerNameMappings ([ID], [MACAddress], [OldName], [NewName], [InstallationDateTime], [UUID])
	VALUES (@IDVal , @MacAddress, @OldHostName, @NewName, CURRENT_TIMESTAMP, @UUID)

		
	COMMIT
END
ELSE
BEGIN
	-- Update installation time
	UPDATE ComputerNameMappings
	SET [InstallationDateTime] = CURRENT_TIMESTAMP
	WHERE UUID = @UUID
END

/*  Return the record as the result set */

SELECT * FROM ComputerIdentity
WHERE UUID = @UUID
GO


