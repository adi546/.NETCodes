USE [agriuatbackup3June2025]
GO
/****** Object:  StoredProcedure [dbo].[UpdateBookingApproval]    Script Date: 7/25/2025 4:47:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateBookingApproval]
    @OrderNumber INT,
    @RoleId INT,
    @UserCode NVARCHAR(50),
    @IsApproved BIT,   -- 1 for approval, 0 for rejection
    @RejectionReasonId INT = NULL,  -- Null for approval, required for rejection
    @CustomerCode NVARCHAR(50)  -- Added parameter to track customer balance updates
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RowsAffected INT = 0;
    DECLARE @UserName NVARCHAR(100);
    DECLARE @LatestTotalAvailableBalance DECIMAL(18,2);
    DECLARE @RefundAmount DECIMAL(18,2) = 0;
    DECLARE @TMApprovalStatus NVARCHAR(50);
    DECLARE @HAApprovalStatus NVARCHAR(50);
    DECLARE @TMUserCode NVARCHAR(50);
    DECLARE @HAUserCode NVARCHAR(50);
    
    -- Check if user has appropriate role
    IF @RoleId < 2
    BEGIN
        PRINT 'Error: User does not have sufficient privileges to approve/reject.';
        RETURN;
    END

    -- Fetch User's Name from Users table
    SELECT @UserName = Name 
    FROM Users 
    WHERE UserCode = @UserCode;

    -- Fetch the latest TotalAvailableBalance for the customer
    SELECT TOP 1 @LatestTotalAvailableBalance = COALESCE(TotalAvailableBalance, 0)
    FROM TB_CustomerTransaction
    WHERE CustomerCode = @CustomerCode
    ORDER BY LastUpdated DESC;

    -- If no record exists, assume 0 balance
    IF @LatestTotalAvailableBalance IS NULL
        SET @LatestTotalAvailableBalance = 0;

    -- Calculate the refund amount based on PriceCardType
    SELECT @RefundAmount = SUM(
        CASE 
            WHEN PriceCardType = 'Single' THEN BookingAmount
            WHEN PriceCardType = 'Combo' THEN BookingAmount + SecondaryBookingAmount
            ELSE 0 
        END
    )
    FROM DealerOrderMHZPC
    WHERE OrderNumber = @OrderNumber;

    -- Get the current approval statuses and user codes before the update
    SELECT 
        @TMApprovalStatus = ISNULL(TMApproval, ''),
        @HAApprovalStatus = ISNULL(HAApproval, ''),
        @TMUserCode = ISNULL(TMUserCode, ''),
        @HAUserCode = ISNULL(HAUserCode, '')
    FROM DealerOrderMHZPC
    WHERE OrderNumber = @OrderNumber;

    -- Determine which approval to update
    -- First approval goes to TMApproval, second to HAApproval, regardless of role
    -- Also ensure the same user cannot approve both steps

    -- If approved
    IF @IsApproved = 1
    BEGIN
        -- Case 1: First approval (TM approval is empty/pending)
        IF (@TMApprovalStatus = '' OR @TMApprovalStatus = 'Pending')
        BEGIN
            UPDATE DealerOrderMHZPC
            SET TMApproval = 'Approved',
                TMApproval_Date = GETDATE(),
                TMUserCode = @UserCode,
                TMName = @UserName,
                TMRejectionReasonId = NULL
            WHERE OrderNumber = @OrderNumber;
        END
        -- Case 2: Second approval (TM approval is done, HA approval is pending, and different user)
        ELSE IF @TMApprovalStatus = 'Approved' AND (@HAApprovalStatus = '' OR @HAApprovalStatus = 'Pending') AND @TMUserCode <> @UserCode
        BEGIN
            UPDATE DealerOrderMHZPC
            SET HAApproval = 'Approved',
                HAApproval_Date = GETDATE(),
                HAUserCode = @UserCode,
                HAName = @UserName,
                HARejectionReasonId = NULL
            WHERE OrderNumber = @OrderNumber;
        END
        -- Case 3: First was rejected, allow to retry with another user (should rarely happen)
        ELSE IF @TMApprovalStatus = 'Rejected' AND @TMUserCode <> @UserCode
        BEGIN
            UPDATE DealerOrderMHZPC
            SET TMApproval = 'Approved',
                TMApproval_Date = GETDATE(),
                TMUserCode = @UserCode,
                TMName = @UserName,
                TMRejectionReasonId = NULL
            WHERE OrderNumber = @OrderNumber;
        END
        -- Handle case where same user is trying to approve both steps
        ELSE IF @TMUserCode = @UserCode AND (@HAApprovalStatus = '' OR @HAApprovalStatus = 'Pending')
        BEGIN
            PRINT 'Error: The same user cannot perform both approvals.';
            RETURN;
        END
    END
    ELSE  -- If rejected
    BEGIN
        -- Case 1: First rejection (TM approval is empty/pending)
        IF (@TMApprovalStatus = '' OR @TMApprovalStatus = 'Pending')
        BEGIN
            UPDATE DealerOrderMHZPC
            SET TMApproval = 'Rejected',
                TMApproval_Date = GETDATE(),
                TMUserCode = @UserCode,
                TMName = @UserName,
                TMRejectionReasonId = @RejectionReasonId
            WHERE OrderNumber = @OrderNumber;
        END
        -- Case 2: Second rejection (TM approval is done, HA approval is pending, and different user)
        ELSE IF @TMApprovalStatus = 'Approved' AND (@HAApprovalStatus = '' OR @HAApprovalStatus = 'Pending') AND @TMUserCode <> @UserCode
        BEGIN
            UPDATE DealerOrderMHZPC
            SET HAApproval = 'Rejected',
                HAApproval_Date = GETDATE(),
                HAUserCode = @UserCode,
                HAName = @UserName,
                HARejectionReasonId = @RejectionReasonId
            WHERE OrderNumber = @OrderNumber;
        END
        -- Handle case where same user is trying to reject both steps
        ELSE IF @TMUserCode = @UserCode AND (@HAApprovalStatus = '' OR @HAApprovalStatus = 'Pending')
        BEGIN
            PRINT 'Error: The same user cannot perform both approvals/rejections.';
            RETURN;
        END

        -- Insert refund transaction if any approval is rejected
        INSERT INTO TB_CustomerTransaction (
            CustomerCode, AvailableBalance, DepositedBalance, TotalAvailableBalance,
            TransactionType, LastUpdated, DeductedBalance, DispatchBalance, RefundBalance, OrderNumber, ReferenceNumber
        )
        VALUES (
            @CustomerCode,  -- CustomerCode
            @LatestTotalAvailableBalance,  -- Available Balance (Previous TotalAvailableBalance)
            0,  -- Deposited Balance
            @LatestTotalAvailableBalance + @RefundAmount,  -- New TotalAvailableBalance
            'Refund',  -- Transaction Type
            GETDATE(),  -- LastUpdated
            0,  -- DeductedBalance
            0,  -- DispatchBalance
            @RefundAmount,  -- RefundBalance
			@OrderNumber,
			NULL
        );
    END

    -- Get the current approval statuses after the update
    SELECT 
        @TMApprovalStatus = ISNULL(TMApproval, ''),
        @HAApprovalStatus = ISNULL(HAApproval, '')
    FROM DealerOrderMHZPC
    WHERE OrderNumber = @OrderNumber;

    -- Update OrderStatus in OrdersMHZPC table based on approval statuses
    IF @TMApprovalStatus = 'Approved' AND @HAApprovalStatus = 'Approved'
    BEGIN
        -- Both approvals are approved, update OrderStatus to 'Approved'
        UPDATE OrdersMHZPC
        SET OrderStatus = 'Approved'
        WHERE OrderNumber = @OrderNumber;
    END
    ELSE IF @TMApprovalStatus = 'Rejected' OR @HAApprovalStatus = 'Rejected'
    BEGIN
        -- If either approval is rejected, update OrderStatus to 'Rejected'
        UPDATE OrdersMHZPC
        SET OrderStatus = 'Rejected'
        WHERE OrderNumber = @OrderNumber;
    END
    ELSE
    BEGIN
        -- Default case - no approvals yet or both are pending or only one is approved
        UPDATE OrdersMHZPC
        SET OrderStatus = 'Pending'
        WHERE OrderNumber = @OrderNumber;
    END

    -- Return rows affected
    SET @RowsAffected = @@ROWCOUNT;
    SELECT @RowsAffected AS RowsAffected;
END;
GO
