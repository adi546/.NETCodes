USE [agriuatbackup19-05-25]
GO
/****** Object:  StoredProcedure [dbo].[Get_All_DEBIT_CREDIT_TOTAL_NEW]    Script Date: 5/31/2025 2:06:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Get_All_DEBIT_CREDIT_TOTAL_NEW] 
    @CompanyCode BIGINT,
    @FromDate DATE = NULL,
    @ToDate DATE = NULL,
    @CustomerCodes NVARCHAR(MAX),
    @Document_Type NVARCHAR(50) = NULL,
    @FinancialYear NVARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @FinancialYear IS NOT NULL
    BEGIN
        DECLARE @StartYear INT = CAST(LEFT(@FinancialYear, 4) AS INT);
        DECLARE @EndYear INT = @StartYear + 1;

        SET @FromDate = CAST(CONCAT(@StartYear, '-04-01') AS DATE);
        SET @ToDate = CAST(CONCAT(@EndYear, '-03-31') AS DATE);
    END

    DECLARE @TotalDebitAmount DECIMAL(18, 2) = 0;
    DECLARE @TotalCreditAmount DECIMAL(18, 2) = 0;
    DECLARE @TotalClosingAmount DECIMAL(18, 2) = 0;  -- Fixed: consistent naming
    DECLARE @OpeningBalance DECIMAL(18, 2) = 0;

    -- Opening Balance calculation
    SELECT 
        @OpeningBalance = 
            ISNULL(SUM(CASE 
                        WHEN Amount_in_Local_Currency >= 0 THEN Amount_in_Local_Currency 
                        ELSE 0 
                    END), 0)
          - ISNULL(SUM(CASE 
                        WHEN Amount_in_Local_Currency < 0 THEN ABS(Amount_in_Local_Currency) 
                        ELSE 0 
                    END), 0)
    FROM TB_CustomerLedger
    WHERE CompanyCode = @CompanyCode
        AND Document_Date < @FromDate
        AND (@CustomerCodes IS NULL
            OR EXISTS (
                SELECT 1 FROM STRING_SPLIT(@CustomerCodes, ',') s 
                WHERE COALESCE(CustomerCode, '') = COALESCE(s.value, '')
            )
        )
        AND (@Document_Type IS NULL OR Document_Type = @Document_Type);

    -- Period totals calculation
    SELECT 
        @TotalDebitAmount = ISNULL(SUM(CASE 
                                    WHEN Amount_in_Local_Currency >= 0 THEN Amount_in_Local_Currency 
                                    ELSE 0 
                                END), 0),
        @TotalCreditAmount = ISNULL(SUM(CASE 
                                    WHEN Amount_in_Local_Currency < 0 THEN ABS(Amount_in_Local_Currency) 
                                    ELSE 0 
                                END), 0)
    FROM TB_CustomerLedger
    WHERE CompanyCode = @CompanyCode
        AND (@FromDate IS NULL OR Document_Date >= @FromDate)
        AND (@ToDate IS NULL OR Document_Date <= @ToDate)
        AND (@CustomerCodes IS NULL
            OR EXISTS (
                SELECT 1 FROM STRING_SPLIT(@CustomerCodes, ',') s 
                WHERE COALESCE(CustomerCode, '') = COALESCE(s.value, '')
            )
        )
        AND (@Document_Type IS NULL OR Document_Type = @Document_Type);

    -- Calculate Closing Balance
    SET @TotalClosingAmount = @OpeningBalance + (@TotalDebitAmount - @TotalCreditAmount);
    
    SELECT 
        @TotalDebitAmount AS TotalDebitAmount,
        @TotalCreditAmount AS TotalCreditAmount,
        @TotalClosingAmount AS ClosingBalance,  -- Fixed: use correct variable
        @OpeningBalance AS OpeningBalance
END;
GO
