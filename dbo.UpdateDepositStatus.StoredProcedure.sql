USE [agriuatbackup3June2025]
GO
/****** Object:  StoredProcedure [dbo].[UpdateDepositStatus]    Script Date: 7/25/2025 4:47:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[UpdateDepositStatus] 
    @Id INT,
    @Status NVARCHAR(20),
	@RowsAffected INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
	SET @RowsAffected = 0;
	
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @CustomerCode NVARCHAR(50);
        DECLARE @DepositedAmount DECIMAL(18,2);
        DECLARE @CurrentBalance DECIMAL(18,2);
		DECLARE @ReferenceNumber NVARCHAR(100);

        -- Get the CustomerCode and DepositedAmount from TB_DepositBalance
        SELECT @CustomerCode = CustomerCode, 
               @DepositedAmount = AmountPaid,
			   @ReferenceNumber = TransactionReferenceNo
        FROM TB_DepositBalance 
        WHERE Id = @Id AND Status = 'Pending';

        -- If no matching record is found, rollback and return
        IF @CustomerCode IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Update status in TB_DepositBalance
        UPDATE TB_DepositBalance
        SET Status = @Status,
            ApprovedAt = CASE WHEN @Status = 'Approved' THEN GETDATE() ELSE ApprovedAt END
        WHERE Id = @Id;

		SET @RowsAffected = @@ROWCOUNT;
        -- If the deposit is approved, update customer balance
        IF @Status = 'Approved'
        BEGIN
            -- Fetch latest TotalAvailableBalance
            SET @CurrentBalance = ISNULL(
                (SELECT TOP 1 TotalAvailableBalance 
                 FROM TB_CustomerTransaction 
                 WHERE CustomerCode = @CustomerCode 
                 ORDER BY LastUpdated DESC), 0);

            -- Insert new transaction record
            INSERT INTO TB_CustomerTransaction (CustomerCode, AvailableBalance, DepositedBalance, TotalAvailableBalance, TransactionType, LastUpdated, DeductedBalance, DispatchBalance, OrderNumber, ReferenceNumber)
            VALUES (@CustomerCode, @CurrentBalance, @DepositedAmount, @CurrentBalance + @DepositedAmount, 'Deposit', GETDATE(), 0,0,NULL,@ReferenceNumber);
        END;                                            

        COMMIT TRANSACTION;
		RETURN @RowsAffected;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
