USE [Database 1]
GO
/****** Object:  StoredProcedure [dbo].[Update_CartItems_Qty_Rate_Into_Amount]    Script Date: 5/6/2025 1:09:42 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Update_CartItems_Qty_Rate_Into_Amount]
    @CompanyCode BIGINT,
    @CartItemId BIGINT,
    @CartId BIGINT,
    @Quantity INT,
    @Rate FLOAT,
    @UserCode NVARCHAR(50),
    @TotalPrice FLOAT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Variables to store user role and previous quantity
        DECLARE @UserRoleId INT;
        DECLARE @PreviousQuantity INT;
        DECLARE @PreviousAmount FLOAT;
        DECLARE @AmountDifference FLOAT;
        DECLARE @CustomerCode NVARCHAR(50);
        
        -- Step 0: Get user's RoleId from Users table
        SELECT @UserRoleId = RoleId
        FROM [dbo].[Users] 
        WHERE UserCode = @UserCode;
        
        -- Get previous quantity and amount for credit limit calculation
        IF @UserRoleId <> 1 -- Only needed for non-admin users
        BEGIN
            SELECT 
                @PreviousQuantity = Quantity,
                @PreviousAmount = Qty_Into_Rate_Amt
            FROM [dbo].[TB_Cart_Items]
            WHERE 
                CompanyCode = @CompanyCode AND 
                CartItemId = @CartItemId AND 
                CartId = @CartId;
                
            -- Get CustomerCode from Create_Dealer_Order for credit limit update
            SELECT @CustomerCode = CustomerCode
            FROM [dbo].[TB_Create_Dealer_Order]
            WHERE 
                CompanyCode = @CompanyCode AND 
                CartId = @CartId;
        END

        -- Step 1: Update Quantity and Amount in TB_Cart_Items
        UPDATE [dbo].[TB_Cart_Items]
        SET
            Quantity = @Quantity,
            QtyUpdateBy = @UserCode,
            UpdatedAt = GETDATE(),
            Qty_Into_Rate_Amt = @Quantity * @Rate
        WHERE 
            CompanyCode = @CompanyCode AND 
            CartItemId = @CartItemId AND 
            CartId = @CartId;
            
        -- Calculate the difference in amount (for credit limit adjustment)
        IF @UserRoleId <> 1 -- Only needed for non-admin users
        BEGIN
            SET @AmountDifference = (@PreviousQuantity * @Rate) - (@Quantity * @Rate);
        END

        -- Step 2: Calculate updated total cart price
        SELECT @TotalPrice = CAST(SUM(Qty_Into_Rate_Amt) AS FLOAT)
        FROM [dbo].[TB_Cart_Items]
        WHERE 
            CompanyCode = @CompanyCode AND 
            CartId = @CartId;

        -- Continue with additional steps only if user's RoleId is NOT 1
        IF @UserRoleId <> 1
        BEGIN
            -- Step 3: Update total in CreateOrderNumber table
            UPDATE [dbo].[TB_Create_Dealer_Order]
            SET Total_Price = @TotalPrice
            WHERE 
                CompanyCode = @CompanyCode AND 
                CartId = @CartId;
                
            -- Step 4: Update the customer's available credit limit
            -- If quantity decreased, refund the difference
            IF @AmountDifference > 0 AND @CustomerCode IS NOT NULL
            BEGIN
                UPDATE [dbo].[TB_CreditLimitOfDealer]
                SET AvailableCreditLimit = AvailableCreditLimit + @AmountDifference
                WHERE CustomerCode = @CustomerCode
                AND SalesOrganisation = @CompanyCode; -- Assuming CompanyCode maps to SalesOrganisation
            END
        END

        -- Step 5: Return a result code indicating success or failure
        IF @@ROWCOUNT = 0
        BEGIN
            SELECT -1 AS ResultCode; -- Failure: No rows affected
        END
        ELSE
        BEGIN
            SELECT 0 AS ResultCode; -- Success
        END
    END TRY
    BEGIN CATCH
        -- Error logging only
        DECLARE @ErrMessage NVARCHAR(MAX) = ERROR_MESSAGE();
        DECLARE @ErrProcedure NVARCHAR(128) = ERROR_PROCEDURE();
        DECLARE @ErrLine NVARCHAR(10) = CAST(ERROR_LINE() AS NVARCHAR);
        DECLARE @ControllerName NVARCHAR(128) = 'Update_CartItems_Qty_Rate_Into_Amount';
        DECLARE @MethodName NVARCHAR(256) = @ErrProcedure + ' (Line: ' + @ErrLine + ')';
        DECLARE @LogTable NVARCHAR(128) = 'ErrorLog_Update_CartItems_Qty_Rate_Into_Amount';

        DECLARE @DynamicSQL NVARCHAR(MAX);
        SET @DynamicSQL = N'
            INSERT INTO [dbo].[' + @LogTable + N'] 
            (ControllerName, MethodName, ErrorMessage, CreatedAt)
            VALUES (@ControllerName, @MethodName, @ErrorMessage, GETDATE());';

        EXEC sp_executesql 
            @DynamicSQL,
            N'@ControllerName NVARCHAR(128), @MethodName NVARCHAR(256), @ErrorMessage NVARCHAR(MAX)',
            @ControllerName = @ControllerName,
            @MethodName = @MethodName,
            @ErrorMessage = @ErrMessage;
            
        -- Return error code
        SELECT -1 AS ResultCode;
    END CATCH
END;
GO
