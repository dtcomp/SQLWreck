DELIMITER ;
select 'global.sql' as 'file';

-- ============================================================================================================
-- Global Customization
-- 
-- Possibly assume the following, if nothing can be determined ( Bad/Missing data )
-- 
SET @DEFAULT_COUNTRY    = 'United States';
SET @DEFAULT_COUNTRY_A  = 'US';
SET @DEFAULT_STATE      = 'Alaska';
SET @DEFAULT_STATE_A    = 'AK';
SET @DEFAULT_AREACODE   = '907';
SET @DEFAULT_POSTCODE   = '99676';

