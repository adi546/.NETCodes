USE [agriuatbackup3June2025]
GO
/****** Object:  StoredProcedure [dbo].[Get_Available_Credit_Limit]    Script Date: 6/19/2025 5:11:23 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Get_Available_Credit_Limit]
	@SalesOrganisation NVARCHAR(5),
	@CustomerCode NVARCHAR(50),
	@CartId BIGINT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Division NVARCHAR(10);

	-- Fetch Division from CartId
	SELECT TOP 1 @Division = Division
	FROM TB_Cart_Items
	WHERE CartId = @CartId;

	SELECT 
		SalesOrganisation,
		Dist_Channel,
		Division,
		CustomerCode,
		CreditControlArea,
		CreditLimit,
		TotalReceivables,
		CreditExposure,
		AvailableCreditLimit
		FROM [dbo].[TB_CreditLimitOfDealer]
	WHERE SalesOrganisation= @SalesOrganisation AND CustomerCode= @CustomerCode AND Division = @Division;
END
GO
