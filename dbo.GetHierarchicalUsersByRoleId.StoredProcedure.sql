USE [agriuatbackup3June2025]
GO
/****** Object:  StoredProcedure [dbo].[GetHierarchicalUsersByRoleId]    Script Date: 7/11/2025 5:07:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[GetHierarchicalUsersByRoleId]
	@UserCode NVARCHAR(50),
    @RoleId INT,
    @RequestedRoleId INT 
AS
BEGIN
    SET NOCOUNT ON;

    -- Declare variables
    DECLARE @CurrentUserCode NVARCHAR(50) = @UserCode;
    DECLARE @CurrentRoleId INT = @RoleId;
    DECLARE @RequestedRole INT = @RequestedRoleId;

    -- BusinessAdmin (7), BHM (6), NSM (5) - Can see all TM, ZM, and Customers
    IF @CurrentRoleId IN (7, 6, 5)
    BEGIN
        SELECT 
            [UserCode], [CompanyCode], [UserType], [Name], [Email], 
            [RepManCode], [IsActive], [RoleId], [UserId]
        FROM Users 
        WHERE RoleId = @RequestedRole AND IsActive = 1 AND CompanyCode = '1054'
        ORDER BY Name;
    END

    -- Zonal Manager (4) - Can see TMs under them and customers under those TMs + direct customers
    ELSE IF @CurrentRoleId = 4
    BEGIN
        IF @RequestedRole = 2 -- TM requested
        BEGIN
            SELECT 
                [UserCode], [CompanyCode], [UserType], [Name], [Email], 
                [RepManCode], [IsActive], [RoleId], [UserId]
            FROM Users 
            WHERE RoleId = 2 -- TM
            AND IsActive = 1
			AND CompanyCode = '1054'
            AND (
                RepManCode = @CurrentUserCode -- Direct TMs under this ZM
                OR 
                RepManCode IN (
                    SELECT UserCode FROM Users 
                    WHERE RoleId = 3 AND RepManCode = @CurrentUserCode AND IsActive = 1 AND CompanyCode = '1054'-- TMs under RM who reports to this ZM
                )
            )
            ORDER BY Name;
        END

        ELSE IF @RequestedRole = 1 -- Customer requested
        BEGIN
            SELECT 
                [UserCode], [CompanyCode], [UserType], [Name], [Email], 
                [RepManCode], [IsActive], [RoleId], [UserId]
            FROM Users 
            WHERE RoleId = 1 -- Customer
            AND IsActive = 1
			AND CompanyCode = '1054'
            AND (
                RepManCode = @CurrentUserCode -- Direct customers under this ZM
                OR 
                RepManCode IN (
                    SELECT UserCode FROM Users 
                    WHERE RoleId = 2 -- TM
                    AND IsActive = 1
					AND CompanyCode = '1054'
                    AND (
                        RepManCode = @CurrentUserCode -- TMs directly under this ZM
                        OR 
                        RepManCode IN (
                            SELECT UserCode FROM Users 
                            WHERE RoleId = 3 AND RepManCode = @CurrentUserCode AND IsActive = 1 -- TMs under RM who reports to this ZM
                        )
                    )
                )
            )
            ORDER BY Name;
        END
        ELSE
        BEGIN
            -- Invalid role requested
            SELECT 
                [UserCode], [CompanyCode], [UserType], [Name], [Email], 
                [RepManCode], [IsActive], [RoleId], [UserId]
            FROM Users 
            WHERE 1 = 0;
        END
    END

    -- Regional Manager (3) - Can see TMs under them and customers under those TMs
    ELSE IF @CurrentRoleId = 3
    BEGIN
        IF @RequestedRole = 2 -- TM requested
        BEGIN
            SELECT 
                [UserCode], [CompanyCode], [UserType], [Name], [Email], 
                [RepManCode], [IsActive], [RoleId], [UserId]
            FROM Users 
            WHERE RoleId = 2 -- TM
            AND IsActive = 1
			AND CompanyCode = '1054'
            AND RepManCode = @CurrentUserCode
            ORDER BY Name;
        END
        ELSE IF @RequestedRole = 4 -- ZM requested
        BEGIN
            -- RM cannot see ZMs
            SELECT 
                [UserCode], [CompanyCode], [UserType], [Name], [Email], 
                [RepManCode], [IsActive], [RoleId], [UserId]
            FROM Users 
            WHERE 1 = 0;
        END
        ELSE IF @RequestedRole = 1 -- Customer requested
        BEGIN
            SELECT 
                [UserCode], [CompanyCode], [UserType], [Name], [Email], 
                [RepManCode], [IsActive], [RoleId], [UserId]
            FROM Users 
            WHERE RoleId = 1 -- Customer
            AND IsActive = 1
			AND CompanyCode = '1054'
            AND RepManCode IN (
                SELECT UserCode FROM Users 
                WHERE RoleId = 2 AND RepManCode = @CurrentUserCode AND IsActive = 1 -- TMs under this RM
            )
            ORDER BY Name;
        END
        ELSE
        BEGIN
            -- Invalid role requested
            SELECT 
                [UserCode], [CompanyCode], [UserType], [Name], [Email], 
                [RepManCode], [IsActive], [RoleId], [UserId]
            FROM Users 
            WHERE 1 = 0;
        END
    END

    -- Territory Manager (2) - Can see only customers under them
    ELSE IF @CurrentRoleId = 2
    BEGIN
        IF @RequestedRole = 1 -- Customer requested
        BEGIN
            SELECT 
                [UserCode], [CompanyCode], [UserType], [Name], [Email], 
                [RepManCode], [IsActive], [RoleId], [UserId]
            FROM Users 
            WHERE RoleId = 1 -- Customer
            AND IsActive = 1
			AND CompanyCode = '1054'
            AND RepManCode = @CurrentUserCode
            ORDER BY Name;
        END
        ELSE
        BEGIN
            -- TM cannot see TMs or ZMs
            SELECT 
                [UserCode], [CompanyCode], [UserType], [Name], [Email], 
                [RepManCode], [IsActive], [RoleId], [UserId]
            FROM Users 
            WHERE 1 = 0;
        END
    END

    -- Customer (1) or Other roles - No access to hierarchy
    ELSE
    BEGIN
        -- Return empty result set for all requests
        SELECT 
            [UserCode], [CompanyCode], [UserType], [Name], [Email], 
            [RepManCode], [IsActive], [RoleId], [UserId]
        FROM Users 
        WHERE 1 = 0;
    END

    SET NOCOUNT OFF;
END
GO
