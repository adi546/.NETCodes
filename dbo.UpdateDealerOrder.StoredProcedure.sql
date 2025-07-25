USE [agriuatbackup3June2025]
GO
/****** Object:  StoredProcedure [dbo].[UpdateDealerOrder]    Script Date: 7/25/2025 4:47:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateDealerOrder]
    @OrderNumber INT,
    @PriceCardType NVARCHAR(50),
    @OrderQuantity FLOAT,
    @OrderAmount DECIMAL(18,2),
    @BookingAmount DECIMAL(18,2),
    @BalanceAmountToPay DECIMAL(18,2),
    @SecondaryOrderQuantity FLOAT = NULL,
    @SecondaryOrderAmount DECIMAL(18,2) = NULL,
    @SecondaryBookingAmount DECIMAL(18,2) = NULL,
    @SecondaryBalanceAmountToPay DECIMAL(18,2) = NULL,
    @ProductId INT,
    @RowsAffected INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Variables for refund calculation
    DECLARE @CustomerCode NVARCHAR(50)
    DECLARE @OriginalBookingAmount DECIMAL(18,2)
    DECLARE @OriginalSecondaryBookingAmount DECIMAL(18,2)
    DECLARE @RefundAmount DECIMAL(18,2) = 0
    DECLARE @PreviousTotalAvailableBalance DECIMAL(18,2)
    
    -- Get the customer code and original booking amounts
    SELECT 
        @CustomerCode = o.CustomerCode,
        @OriginalBookingAmount = d.BookingAmount,
        @OriginalSecondaryBookingAmount = d.SecondaryBookingAmount
    FROM DealerOrderMHZPC d
    JOIN OrdersMHZPC o ON d.OrderNumber = o.OrderNumber
    WHERE d.OrderNumber = @OrderNumber AND d.ProductId = @ProductId
    
    -- Calculate refund based on PriceCardType
    IF @PriceCardType = 'Single'
    BEGIN
        -- Calculate refund amount (original - new booking amount)
        SET @RefundAmount = @OriginalBookingAmount - @BookingAmount
        
        UPDATE DealerOrderMHZPC
        SET 
            OrderQuantity = @OrderQuantity,
            OrderAmount = @OrderAmount,
            BookingAmount = @BookingAmount,
            BalanceAmountToPay = @BalanceAmountToPay
        WHERE OrderNumber = @OrderNumber AND ProductId = @ProductId
        
        SET @RowsAffected = @@ROWCOUNT
    END
    ELSE IF @PriceCardType = 'Combo'
    BEGIN
        -- For combo, refund is the difference in both primary and secondary booking amounts
        SET @RefundAmount = (@OriginalBookingAmount - @BookingAmount) + 
                           (@OriginalSecondaryBookingAmount - @SecondaryBookingAmount)
        
        UPDATE DealerOrderMHZPC
        SET 
            OrderQuantity = @OrderQuantity,
            OrderAmount = @OrderAmount,
            BookingAmount = @BookingAmount,
            BalanceAmountToPay = @BalanceAmountToPay,
            SecondaryOrderQuantity = @SecondaryOrderQuantity,
            SecondaryOrderAmount = @SecondaryOrderAmount,
            SecondaryBookingAmount = @SecondaryBookingAmount,
            SecondaryBalanceAmountToPay = @SecondaryBalanceAmountToPay
        WHERE OrderNumber = @OrderNumber AND ProductId = @ProductId
        
        SET @RowsAffected = @@ROWCOUNT
    END
    
    -- Process refund if necessary
    IF @RefundAmount > 0 AND @RowsAffected > 0
    BEGIN
        -- Get the previous total available balance for the customer
        SELECT TOP 1 @PreviousTotalAvailableBalance = TotalAvailableBalance
        FROM TB_CustomerTransaction
        WHERE CustomerCode = @CustomerCode
        ORDER BY LastUpdated DESC, Id DESC
        
        -- If no record exists, set available balance to 0
        IF @PreviousTotalAvailableBalance IS NULL
            SET @PreviousTotalAvailableBalance = 0
            
        -- Insert new transaction record for refund
        INSERT INTO TB_CustomerTransaction (
            CustomerCode,
            AvailableBalance,
            DepositedBalance,
            TotalAvailableBalance,
            TransactionType,
            LastUpdated,
            DeductedBalance,
            DispatchBalance,
            RefundBalance,
			OrderNumber,
			ReferenceNumber
        )
        VALUES (
            @CustomerCode,
            @PreviousTotalAvailableBalance, -- AvailableBalance is previous TotalAvailableBalance
            0,
            @PreviousTotalAvailableBalance + @RefundAmount, -- New TotalAvailableBalance
            'Refund',
            GETDATE(),
            0,
            0,
            @RefundAmount,
			@OrderNumber,
			NULL
        )
    END
END
GO
