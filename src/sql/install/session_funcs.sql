DELIMITER //

CREATE FUNCTION IF NOT EXISTS `getSessionID`() RETURNS varchar(100)
    DETERMINISTIC
RETURN (
    SELECT @sessionid
)  //
CREATE FUNCTION IF NOT EXISTS `getSessionUser`() RETURNS varchar(100)
    DETERMINISTIC
RETURN (
    SELECT @sessionuser
) //

CREATE FUNCTION IF NOT EXISTS `getSessionUserFullName`() RETURNS varchar(255)
    DETERMINISTIC
RETURN (
    SELECT @sessionuserfullname
) //

