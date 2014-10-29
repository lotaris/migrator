-- Add the prices into the Price table based on the prices stored in the Product table
INSERT INTO `PRICE` (`AMOUNT`, `CURRENCY_ID`) 
	SELECT p.`PRICE`, c.ID FROM `PRODUCT` p, `CURRENCY` c WHERE c.`ISOCODE` = p.`CURRENCY`;

-- Removing the column in the product table
ALTER TABLE `PRODUCT` DROP COLUMN `PRICE`;
ALTER TABLE `PRODUCT` DROP COLUMN `CURRENCY`;