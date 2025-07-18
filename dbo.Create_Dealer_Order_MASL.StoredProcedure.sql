USE [agriuatbackup3June2025]
GO
/****** Object:  StoredProcedure [dbo].[Create_Dealer_Order_MASL]    Script Date: 6/19/2025 5:11:23 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Create_Dealer_Order_MASL]
    @ShippingAddress NVARCHAR(150),
    @BillingAddress NVARCHAR(150),
    @City NVARCHAR(50),
    @Dealer_State NVARCHAR(50),
    @ZipCode NVARCHAR(50),
    @ContactPersonName NVARCHAR(150),
    @ContactPersonNumber BIGINT,
    @CompanyCode BIGINT,
    @cartId BIGINT,
    @Email NVARCHAR(120),
    @userId BIGINT,
    @salesOrganisation NVARCHAR(50),
    @DistChannel NVARCHAR(50),
    @Division NVARCHAR(50),
    @ShippedFromPlant NVARCHAR(50),
    @Total_Items BIGINT,
    @CustomerCode NVARCHAR(50),
    @CustomerName NVARCHAR(120),
    @Role_Details NVARCHAR(MAX),
    @IsActive_User BIT,
    @UserName NVARCHAR(MAX),
    @RepManCode NVARCHAR(50),
    @UserCode NVARCHAR(50),
    @Sale_Price DECIMAL(18,3),
    @Total_Price DECIMAL(18,3),
    @Plant NVARCHAR(5),
    @SecondApprovalUserCode NVARCHAR(50),
    @ResultMessage NVARCHAR(500) OUTPUT,
    @AvailableCreditLimitold DECIMAL(18,2) OUTPUT,
    @CreditExposureold DECIMAL(18,2) OUTPUT,
	@ZSMCode NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Step 1: Initialize Output
        SET @AvailableCreditLimitold = 0;
        SET @CreditExposureold = 0;

        -- Step 2: Fetch Division from Cart Items (only 1 record, any is fine)
        DECLARE @DerivedDivision NVARCHAR(50);

        SELECT TOP 1 @DerivedDivision = Division
        FROM TB_Cart_Items
        WHERE CartId = @cartId;

        -- Step 3: Get Credit Info by Division too
        SELECT 
            @AvailableCreditLimitold = ISNULL(AvailableCreditLimit, 0), 
            @CreditExposureold = ISNULL(CreditExposure, 0)
        FROM TB_CreditLimitOfDealer
        WHERE SalesOrganisation = @salesOrganisation 
        AND CustomerCode = @UserCode
        AND Division = @DerivedDivision;

        -- Step 4: Insert Order (use incoming Division for recordkeeping, but not for logic)
        INSERT INTO TB_Create_Dealer_Order
        (
            ShippingAddress, BillingAddress, City, Dealer_State, ZipCode, ContactPersonName, ContactPersonNumber,
            CompanyCode, cartId, Email, UserId, salesOrganisation, DistChannel, Division, ShippedFromPlant,
            Total_Items, CustomerCode, CustomerName, Role_Details, IsActive_User, UserName, RepManCode, UserCode,
            Sale_Price, Total_Price, Plant, SecondApprovalUserCode, ZSMCode
        )
        VALUES
        (
            @ShippingAddress, @BillingAddress, @City, @Dealer_State, @ZipCode, @ContactPersonName, @ContactPersonNumber,
            @CompanyCode, @cartId, @Email, @userId, @salesOrganisation, @DistChannel, @Division, @ShippedFromPlant,
            @Total_Items, @CustomerCode, @CustomerName, @Role_Details, @IsActive_User, @UserName, @RepManCode, @UserCode,
            @Sale_Price, @Total_Price, @Plant, @SecondApprovalUserCode, @ZSMCode
        );

        -- Step 5: Update Credit Info based on Derived Division
        UPDATE TB_CreditLimitOfDealer
        SET 
            CreditExposure = @CreditExposureold + @Total_Price,
            AvailableCreditLimit = @AvailableCreditLimitold - @Total_Price
        WHERE SalesOrganisation = @salesOrganisation 
        AND CustomerCode = @UserCode
        AND Division = @DerivedDivision;

        -- Step 6: Success
        SET @ResultMessage = 'Success';
        RETURN 1;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000), @ErrorSeverity INT, @ErrorState INT;
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @ErrorSeverity = ERROR_SEVERITY();
        SET @ErrorState = ERROR_STATE();

        INSERT INTO ErrorLog_CreateSales_Indent 
        (ErrorMessage, ErrorSeverity, ErrorState, ErrorProcedure, ErrorLine, ErrorDate, ResultMessage)
        VALUES 
        (@ErrorMessage, @ErrorSeverity, @ErrorState, ERROR_PROCEDURE(), ERROR_LINE(), GETDATE(), 'Failed');

        SET @ResultMessage = 'Error: ' + @ErrorMessage;
        RETURN 0;
    END CATCH
END;
GO
