--
-- Migration - Step 2
-- Add type to product table for each product
--
UPDATE `PRODUCT` SET `TYPE` = 'Fruit' WHERE `PRODUCT`.`NAME` = 'Apple';
UPDATE `PRODUCT` SET `TYPE` = 'Vegetable' WHERE `PRODUCT`.`NAME` = 'Cucumber';
...
