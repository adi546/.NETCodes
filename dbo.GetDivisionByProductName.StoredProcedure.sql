USE [agriuatbackup3June2025]
GO
/****** Object:  StoredProcedure [dbo].[GetDivisionByProductName]    Script Date: 7/8/2025 6:08:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[GetDivisionByProductName] 
	 @ProductName NVARCHAR(255)
AS
BEGIN
	SET NOCOUNT ON;

    SELECT TOP 1 Division
    FROM TB_PriceMaster
    WHERE LTRIM(RTRIM(Material_Description)) = LTRIM(RTRIM(@ProductName));
END
GO
