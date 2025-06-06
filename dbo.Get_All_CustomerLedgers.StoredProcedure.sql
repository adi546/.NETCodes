USE [agriuatbackup19-05-25]
GO
/****** Object:  StoredProcedure [dbo].[Get_All_CustomerLedgers]    Script Date: 5/31/2025 2:06:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Get_All_CustomerLedgers] 
    @CompanyCode BIGINT,
    @FromDate DATE = NULL,
    @ToDate DATE = NULL,
    @CustomerCodes NVARCHAR(MAX),
    @Document_Type NVARCHAR(50) = NULL,
    @FinancialYear NVARCHAR(10) = NULL
AS
BEGIN
    
    SET NOCOUNT ON;
    IF @FinancialYear IS NOT NULL AND (@FromDate IS NULL OR @ToDate IS NULL)
    BEGIN
        DECLARE @StartYear INT = CAST(LEFT(@FinancialYear, 4) AS INT);
        DECLARE @EndYear INT = @StartYear + 1;

		IF @FromDate IS NULL
			SET @FromDate = CAST(CONCAT(@StartYear, '-04-01') AS DATE);
        
		IF @ToDate IS NULL
			SET @ToDate = CAST(CONCAT(@EndYear, '-03-31') AS DATE);
    END
    SELECT
        CompanyCode,
        CustomerCode, -- Make sure CustomerCode is returned in the result set
        Document_Type,
        Document_Number,
        Credit_Control_Area,
        Document_Date,
        Net_Due_Date,
        Posting_Date,
        Arrears_by_Net_Due_Date,
        Credit_Control_Area_Currency,
        Baseline_Payment_Date,
        Amount_in_Local_Currency,
        -- Categorizing Amount as Debit or Credit
        CASE 
        WHEN Amount_in_Local_Currency >= 0 THEN Amount_in_Local_Currency 
        ELSE 0 
        END AS DebitAmount,
        CASE 
        WHEN Amount_in_Local_Currency < 0 THEN ABS(Amount_in_Local_Currency) 
        ELSE 0 
        END AS CreditAmount,
        Clearing_Date,
        Clearing_Document,
        Assignment,
        Reference,
        Text,
        Account,
        Document_Header_Text,
        UserCode,
        GLAccount
    FROM TB_CustomerLedger
    WHERE CompanyCode = @CompanyCode 
    
    AND (@FromDate IS NULL OR Document_Date >= @FromDate)
    AND (@ToDate IS NULL OR Document_Date <= @ToDate)
    AND (
        @CustomerCodes IS NULL
        OR EXISTS (
            SELECT 1 FROM STRING_SPLIT(@CustomerCodes, ',') s 
            WHERE COALESCE(CustomerCode, '') = COALESCE(s.value, '')
        )
    )
    
    AND (@Document_Type IS NULL OR Document_Type = @Document_Type);
END;
GO
