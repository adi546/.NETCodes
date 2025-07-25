USE [agriuatbackup3June2025]
GO
/****** Object:  StoredProcedure [dbo].[GetBalanceUtilization]    Script Date: 7/25/2025 5:33:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[GetBalanceUtilization]
    @CustomerCode NVARCHAR(50),
    @YearFilter NVARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- Standardize @YearFilter to match 'YYYY-YYYY' format
    IF @YearFilter IS NOT NULL 
    BEGIN
        DECLARE @StartYear INT = LEFT(@YearFilter, 4);
        SET @YearFilter = CONCAT(@StartYear, '-', @StartYear + 1);
    END

    -- Create a CTE to combine all transactions in a unified format
    ;WITH AllTransactions AS (
        -- Get Deposits
        SELECT 
            LastUpdated AS DateOfTransaction,
            DepositedBalance AS Amount,
            TotalAvailableBalance AS AvailableAmount,
            'Deposit' AS Description,
              CONCAT(
                CASE 
                    WHEN MONTH(LastUpdated) >= 4 THEN YEAR(LastUpdated)
                    ELSE YEAR(LastUpdated) - 1
                END,
                '-',
                CASE 
                    WHEN MONTH(LastUpdated) >= 4 THEN YEAR(LastUpdated) + 1
                    ELSE YEAR(LastUpdated)
                END
            ) AS Year,
            Id as TransactionId
        FROM TB_CustomerTransaction
        WHERE CustomerCode = @CustomerCode
        AND DepositedBalance > 0 
        AND TransactionType = 'Deposit' 
        AND (@YearFilter IS NULL OR 
            CONCAT(
                CASE 
                    WHEN MONTH(LastUpdated) >= 4 THEN YEAR(LastUpdated)
                    ELSE YEAR(LastUpdated) - 1
                END,
                '-',
                CASE 
                    WHEN MONTH(LastUpdated) >= 4 THEN YEAR(LastUpdated) + 1
                    ELSE YEAR(LastUpdated)
                END
            ) = @YearFilter
        )
        
        UNION ALL
        
        -- Get Deduct Transactions
        SELECT 
            LastUpdated AS DateOfTransaction,
            -DeductedBalance AS Amount,  -- Negative for debit
            TotalAvailableBalance AS AvailableAmount,
            'Booking' AS Description,
            CONCAT(
                CASE 
                    WHEN MONTH(LastUpdated) >= 4 THEN YEAR(LastUpdated)
                    ELSE YEAR(LastUpdated) - 1
                END,
                '-',
                CASE 
                    WHEN MONTH(LastUpdated) >= 4 THEN YEAR(LastUpdated) + 1
                    ELSE YEAR(LastUpdated)
                END
            ) AS Year,
            Id as TransactionId
        FROM TB_CustomerTransaction
        WHERE CustomerCode = @CustomerCode
        AND DeductedBalance > 0 
        AND TransactionType = 'Deduct' 
         AND (@YearFilter IS NULL OR 
            CONCAT(
                CASE 
                    WHEN MONTH(LastUpdated) >= 4 THEN YEAR(LastUpdated)
                    ELSE YEAR(LastUpdated) - 1
                END,
                '-',
                CASE 
                    WHEN MONTH(LastUpdated) >= 4 THEN YEAR(LastUpdated) + 1
                    ELSE YEAR(LastUpdated)
                END
            ) = @YearFilter
        )
        
        UNION ALL
        
        -- Get Refund Transactions
        SELECT 
            LastUpdated AS DateOfTransaction,
            RefundBalance AS Amount,  -- Positive for credit
            TotalAvailableBalance AS AvailableAmount,
            'Refund' AS Description,
           CONCAT(
                CASE 
                    WHEN MONTH(LastUpdated) >= 4 THEN YEAR(LastUpdated)
                    ELSE YEAR(LastUpdated) - 1
                END,
                '-',
                CASE 
                    WHEN MONTH(LastUpdated) >= 4 THEN YEAR(LastUpdated) + 1
                    ELSE YEAR(LastUpdated)
                END
            ) AS Year,
            Id as TransactionId
        FROM TB_CustomerTransaction
        WHERE CustomerCode = @CustomerCode
        AND RefundBalance > 0
        AND TransactionType = 'Refund'
        AND (@YearFilter IS NULL OR 
            CONCAT(
                CASE 
                    WHEN MONTH(LastUpdated) >= 4 THEN YEAR(LastUpdated)
                    ELSE YEAR(LastUpdated) - 1
                END,
                '-',
                CASE 
                    WHEN MONTH(LastUpdated) >= 4 THEN YEAR(LastUpdated) + 1
                    ELSE YEAR(LastUpdated)
                END
            ) = @YearFilter
        )
        
        UNION ALL
        
        -- Get Dispatch Transactions
        SELECT 
            LastUpdated AS DateOfTransaction,
            -DispatchBalance AS Amount,  -- Negative for debit
            TotalAvailableBalance AS AvailableAmount,
            'Dispatch' AS Description,
          CONCAT(
                CASE 
                    WHEN MONTH(LastUpdated) >= 4 THEN YEAR(LastUpdated)
                    ELSE YEAR(LastUpdated) - 1
                END,
                '-',
                CASE 
                    WHEN MONTH(LastUpdated) >= 4 THEN YEAR(LastUpdated) + 1
                    ELSE YEAR(LastUpdated)
                END
            ) AS Year,
            Id as TransactionId
        FROM TB_CustomerTransaction
        WHERE CustomerCode = @CustomerCode
        AND DispatchBalance > 0
        AND TransactionType = 'Dispatch'
       AND (@YearFilter IS NULL OR 
            CONCAT(
                CASE 
                    WHEN MONTH(LastUpdated) >= 4 THEN YEAR(LastUpdated)
                    ELSE YEAR(LastUpdated) - 1
                END,
                '-',
                CASE 
                    WHEN MONTH(LastUpdated) >= 4 THEN YEAR(LastUpdated) + 1
                    ELSE YEAR(LastUpdated)
                END
            ) = @YearFilter
        )
    )
    
    
    -- Add joins to get product/quantity information where applicable
    SELECT 
        t.DateOfTransaction, 
        t.Amount, 
        t.AvailableAmount, 
        CASE 
            WHEN t.Description = 'Booking' AND d.ProductName IS NOT NULL
                THEN CONCAT('Booking ', d.ProductName, ' (Qty: ', d.OrderQuantity, 'MT) [OrderNo: ', ct.OrderNumber, ']')
            WHEN t.Description = 'Dispatch' AND dr.RequestForQuantityMT IS NOT NULL
                THEN CONCAT('Dispatch Qty: ', dr.RequestForQuantityMT, 'MT [OrderNo: ', ct.OrderNumber, ']')
            WHEN t.Description = 'Refund' AND ct.OrderNumber IS NOT NULL
                THEN CONCAT('Refund against OrderNo: ', ct.OrderNumber)
            WHEN t.Description = 'Deposit' AND ct.ReferenceNumber IS NOT NULL
                THEN CONCAT('Deposit [Ref No: ', ct.ReferenceNumber, ']')
            ELSE t.Description
        END AS Description,
        t.Year
    FROM AllTransactions t
    LEFT JOIN TB_CustomerTransaction ct ON t.TransactionId = ct.Id
    LEFT JOIN DealerOrderMHZPC d ON d.OrderNumber = ct.OrderNumber AND t.Description = 'Booking'
    LEFT JOIN DispatchRequests dr ON dr.OrderNumber = ct.OrderNumber AND t.Description = 'Dispatch'
    ORDER BY t.DateOfTransaction DESC;
END;
GO
