--
-- Migration - Step 3
-- Adding the missing constraint to avoid nullable type in Product table
--
ALTER TABLE `PRODUCT` CHANGE `TYPE` `TYPE` VARCHAR( 15 ) NOT NULL;
