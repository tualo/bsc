DELIMITER //
CREATE FUNCTION IF NOT EXISTS `getNextPossibleBookingDate`(in_date date) RETURNS longtext CHARSET utf8mb4 COLLATE utf8mb4_general_ci
    DETERMINISTIC
BEGIN 
    DECLARE buchhaltungsabschluss_start date;
    DECLARE buchhaltungsabschluss_stop date;
    DECLARE buchhaltungsabschluss_laststart date;

    select 
        date_add( cast( concat(  replace(max(buchungsperiode),'.','-'),'-01') as date),interval 1 month ),
        date_add( date_add( cast( concat(  replace(max(buchungsperiode),'.','-'),'-01') as date),interval 2 month ),interval -1 day),
        current_date
    into 
        buchhaltungsabschluss_start,
        buchhaltungsabschluss_laststart,
        buchhaltungsabschluss_stop
    from 
        buchhaltungsabschluss
    ;

    if  (in_date between buchhaltungsabschluss_start and buchhaltungsabschluss_laststart) and buchhaltungsabschluss_stop > buchhaltungsabschluss_laststart  then
        return buchhaltungsabschluss_laststart;
    end if;

    if  in_date between buchhaltungsabschluss_start and buchhaltungsabschluss_stop then
        return in_date;
    end if;

    return buchhaltungsabschluss_stop;

END //