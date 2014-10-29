--
-- Schema initial creation
--
CREATE TABLE `PRODUCT` (
  `ID` bigint(20) NOT NULL AUTO_INCREMENT,
  `NAME` varchar(20) NOT NULL,
  `PRICE` float NOT NULL,
  `CURRENCY` varchar(3) NOT NULL,
  PRIMARY KEY (`ID`)
) AUTO_INCREMENT=1 ;