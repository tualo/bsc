DELIMITER //

CREATE  OR REPLACE FUNCTION `getSessionID`() RETURNS varchar(100)
    DETERMINISTIC
RETURN (
    SELECT @sessionid
)  //
CREATE  OR REPLACE FUNCTION `getSessionUser`() RETURNS varchar(100)
    DETERMINISTIC
RETURN (
    SELECT @sessionuser
) //

CREATE  OR REPLACE FUNCTION `getSessionUserFullName`() RETURNS varchar(255)
    DETERMINISTIC
RETURN (
    SELECT @sessionuserfullname
) //

