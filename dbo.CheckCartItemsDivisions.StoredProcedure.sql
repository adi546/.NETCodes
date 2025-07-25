USE [agriuatbackup3June2025]
GO
/****** Object:  StoredProcedure [dbo].[CheckCartItemsDivisions]    Script Date: 6/16/2025 4:50:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CheckCartItemsDivisions]
    @CartId NVARCHAR(50),
    @HasSameDivision BIT OUTPUT,
    @DivisionName NVARCHAR(100) OUTPUT,
    @ErrorMessage NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @DivisionCount INT;
    DECLARE @ItemCount INT;
    DECLARE @CustomerCode NVARCHAR(50);
    DECLARE @CustomerDivisionCount INT;
    DECLARE @HasFieldCropEnrollment BIT = 0;
    DECLARE @HasVegetableEnrollment BIT = 0;
    DECLARE @CartHasFieldCrop BIT = 0;
    DECLARE @CartHasVegetable BIT = 0;
    
    -- Step 1: Check if cart has any non-deleted items
    SELECT @ItemCount = COUNT(CartItemId)
    FROM TB_Cart_Items
    WHERE CartId = @CartId;
    
    IF @ItemCount = 0
    BEGIN
        SET @HasSameDivision = 0;
        SET @DivisionName = NULL;
        SET @ErrorMessage = 'Cart is empty or does not exist.';
        RETURN;
    END
    
    -- Step 2: Get customer code from cart items
    SELECT TOP 1 @CustomerCode = UserCode
    FROM TB_Cart_Items
    WHERE CartId = @CartId;
    
    -- Step 3: Check customer's division enrollments in TB_CreditLimitOfDealer
    SELECT @HasFieldCropEnrollment = CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END
    FROM TB_CreditLimitOfDealer
    WHERE CustomerCode = @CustomerCode AND Division = '25';
    
    SELECT @HasVegetableEnrollment = CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END
    FROM TB_CreditLimitOfDealer
    WHERE CustomerCode = @CustomerCode AND Division = 'VG';
    
    -- Step 4: Check what divisions are in the cart
    SELECT @CartHasFieldCrop = CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END
    FROM TB_Cart_Items
    WHERE CartId = @CartId AND Division = '25';
    
    SELECT @CartHasVegetable = CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END
    FROM TB_Cart_Items
    WHERE CartId = @CartId AND Division = 'VG';
    
    -- Step 5: Count DISTINCT non-null divisions in cart
    SELECT @DivisionCount = COUNT(DISTINCT Division)
    FROM TB_Cart_Items
    WHERE CartId = @CartId AND Division IS NOT NULL;
    
    -- Step 6: Apply business logic based on customer enrollment and cart contents
    
    -- Case 1: Customer has both division enrollments (25 and VG)
    IF @HasFieldCropEnrollment = 1 AND @HasVegetableEnrollment = 1
    BEGIN
        -- If cart has both divisions, show error
        IF @CartHasFieldCrop = 1 AND @CartHasVegetable = 1
        BEGIN
            SET @HasSameDivision = 0;
            SET @DivisionName = 'Mixed';
            SET @ErrorMessage = 'Please place separate indents for Field Crop and Vegetable Crop products. Only one product type is allowed per indent.';
            RETURN;
        END
        -- If cart has only one division, proceed normally
        ELSE IF @DivisionCount = 1
        BEGIN
            SELECT TOP 1 @DivisionName = Division
            FROM TB_Cart_Items
            WHERE CartId = @CartId AND Division IS NOT NULL;
            
            SET @HasSameDivision = 1;
            SET @ErrorMessage = NULL;
            RETURN;
        END
    END
    
    -- Case 2: Customer has only Field Crop enrollment (25)
    ELSE IF @HasFieldCropEnrollment = 1 AND @HasVegetableEnrollment = 0
    BEGIN
        -- If cart has vegetable products, show error
        IF @CartHasVegetable = 1
        BEGIN
            SET @HasSameDivision = 0;
            SET @DivisionName = 'VG';
            SET @ErrorMessage = 'You are Not Enrolled for Vegetable Crop Products. You cannot place the Indent';
            RETURN;
        END
        -- If cart has only field crop products, proceed
        ELSE IF @CartHasFieldCrop = 1 AND @DivisionCount = 1
        BEGIN
            SET @HasSameDivision = 1;
            SET @DivisionName = '25';
            SET @ErrorMessage = NULL;
            RETURN;
        END
    END
    
    -- Case 3: Customer has only Vegetable enrollment (VG)
    ELSE IF @HasFieldCropEnrollment = 0 AND @HasVegetableEnrollment = 1
    BEGIN
        -- If cart has field crop products, show error
        IF @CartHasFieldCrop = 1
        BEGIN
            SET @HasSameDivision = 0;
            SET @DivisionName = '25';
            SET @ErrorMessage = 'You are Not Enrolled for Field Crop Products. You cannot place the Indent';
            RETURN;
        END
        -- If cart has only vegetable products, proceed
        ELSE IF @CartHasVegetable = 1 AND @DivisionCount = 1
        BEGIN
            SET @HasSameDivision = 1;
            SET @DivisionName = 'VG';
            SET @ErrorMessage = NULL;
            RETURN;
        END
    END
    
    -- Case 4: Customer has no enrollment for either division
    ELSE IF @HasFieldCropEnrollment = 0 AND @HasVegetableEnrollment = 0
    BEGIN
        SET @HasSameDivision = 0;
        SET @DivisionName = NULL;
        SET @ErrorMessage = 'You are not enrolled for any product divisions. Please contact administrator.';
        RETURN;
    END
END
GO
