USE [agriuatbackup3June2025]
GO
/****** Object:  StoredProcedure [dbo].[sp_CheckEmailExists]    Script Date: 7/10/2025 12:44:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_CheckEmailExists]
	 @Email NVARCHAR(MAX)
AS
BEGIN
	 SET NOCOUNT ON;
    
    SELECT 
                u.UserId,
                u.UserCode,
                u.Name,
                u.Email,
                u.Password,
                u.RoleId,
                u.CompanyCode,
                u.IsActive,
                u.RepManCode,
                u.ContactNumber,
                u.FirstName,
                u.LastName,
                u.JobTitle,
                u.Location,
                u.MPIN,
                u.UserType,
                u.Role_Details,
                r.RoleId as Role_RoleId,
                r.RoleName
            FROM Users u
            LEFT JOIN Roles r ON u.RoleId = r.RoleId
            WHERE u.Email = @Email 
               OR LOWER(LTRIM(RTRIM(u.Email))) = LOWER(LTRIM(RTRIM(@Email)))
END
GO
