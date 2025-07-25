USE [agriuatbackup3June2025]
GO
/****** Object:  StoredProcedure [dbo].[InsertDispatchRequest]    Script Date: 7/25/2025 4:47:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[InsertDispatchRequest]
    @CustomerCode NVARCHAR(50),
    @PricePerKg DECIMAL(18,2),
    @BookingPrice DECIMAL(18,2),
    @BookedQty FLOAT,
    @BookingAmtPaid DECIMAL(18,2),
    @BalanceAmtToPay DECIMAL(18,2),
    @ExpectedDelivery DATE,
    @BalanceQuantity FLOAT,
    @DispatchStatus NVARCHAR(20),
    @RequestForQuantityMT DECIMAL(18,2),
    @AmountRequiredToDispatch DECIMAL(18,2),
    @BookingAmountReceived DECIMAL(18,2),
    @BalanceAmount DECIMAL(18,2),
    @FromDate DATE,
    @ToDate DATE,
    @DispatchAddress NVARCHAR(255),
    @OrderNumber INT,
    @ProductId INT,
	@PriceCardType NVARCHAR(50),
	@ItemId INT

AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LatestTotalAvailableBalance DECIMAL(18,2);
	DECLARE @DispatchBalance DECIMAL(18,2);

    -- Get the latest TotalAvailableBalance for the customer
    SELECT TOP 1 @LatestTotalAvailableBalance = TotalAvailableBalance
    FROM TB_CustomerTransaction
    WHERE CustomerCode = @CustomerCode
    ORDER BY LastUpdated DESC;

    -- If no record exists, assume 0 balance
    IF @LatestTotalAvailableBalance IS NULL
        SET @LatestTotalAvailableBalance = 0;

    
        SET @DispatchBalance = @BalanceAmount;
   

    -- Insert into DispatchRequests table
    INSERT INTO DispatchRequests (
        CustomerCode, PricePerKg, BookingPrice, BookedQty, BookingAmtPaid, BalanceAmtToPay,
        ExpectedDelivery, BalanceQuantity, DispatchStatus, RequestForQuantityMT, AmountRequiredToDispatch,
        BookingAmountReceived, BalanceAmount, FromDate, ToDate, DispatchAddress, CreatedOn, OrderNumber, ProductId,
	    ItemId, PriceCardType
        
    )
    VALUES (
        @CustomerCode, @PricePerKg, @BookingPrice, @BookedQty, @BookingAmtPaid, @BalanceAmtToPay,
        @ExpectedDelivery, @BalanceQuantity, @DispatchStatus, @RequestForQuantityMT, @AmountRequiredToDispatch,
        @BookingAmountReceived, @BalanceAmount, @FromDate, @ToDate, @DispatchAddress, GETDATE(), @OrderNumber, @ProductId,
		@ItemId, @PriceCardType
        
    );

    -- Insert transaction into TB_CustomerTransaction
    INSERT INTO TB_CustomerTransaction (
        CustomerCode, AvailableBalance, DepositedBalance, DeductedBalance, DispatchBalance, RefundBalance,
        TotalAvailableBalance, TransactionType, LastUpdated, OrderNumber, ReferenceNumber
    )
    VALUES (
        @CustomerCode, @LatestTotalAvailableBalance, 0, 0, @DispatchBalance, 0,
        @LatestTotalAvailableBalance - @DispatchBalance, 'Dispatch', GETDATE(), NULL,NULL
    );

	IF @BalanceQuantity = 0
    BEGIN
        IF @PriceCardType = 'Combo'
        BEGIN
            IF @ItemId = 1
            BEGIN
                UPDATE DealerOrderMHZPC
                SET PrimaryDispatchStatus = 'Completed'
                WHERE OrderNumber = @OrderNumber 
                      AND ProductId = @ProductId 
                      AND PriceCardType = @PriceCardType;
            END
            ELSE IF @ItemId = 2
            BEGIN
                UPDATE DealerOrderMHZPC
                SET SecondaryDispatchStatus = 'Completed'
                WHERE OrderNumber = @OrderNumber 
                      AND ProductId = @ProductId 
                      AND PriceCardType = @PriceCardType;
            END
        END
        ELSE IF @PriceCardType = 'Single'
        BEGIN
            UPDATE DealerOrderMHZPC
            SET PrimaryDispatchStatus = 'Completed'
            WHERE OrderNumber = @OrderNumber 
                  AND ProductId = @ProductId 
                  AND PriceCardType = @PriceCardType;
        END
    END
    -- Return the inserted DispatchRequest Id
    SELECT SCOPE_IDENTITY() AS InsertedId;
END;
GO
