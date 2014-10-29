--
-- Data for migration step 1
--
INSERT INTO `COUNTRY` (`ID`, `NAME`, `ISOCODE`) VALUES (1, 'Switzerland', 'CH');
INSERT INTO `COUNTRY` (`ID`, `NAME`, `ISOCODE`) VALUES (2, 'United States of America', 'US');
...
INSERT INTO `CURRENCY` (`ID`, `NAME`, `ISOCODE`) VALUES (1, 'Euro', 'EUR');
INSERT INTO `CURRENCY` (`ID`, `NAME`, `ISOCODE`) VALUES (2, 'US Dollar ', 'USD');
...
INSERT INTO `COUNTRY_CURRENCY` (`COUNTRY_ID`, `CURRENCY_ID`) VALUES ('1', '6');
INSERT INTO `COUNTRY_CURRENCY` (`COUNTRY_ID`, `CURRENCY_ID`) VALUES ('2', '2');
...
-- Request to check associations
-- SELECT * FROM `COUNTRY` cou, `CURRENCY` cur, `COUNTRY_CURRENCY` cc
--		WHERE cou.ID = cc.COUNTRY_ID AND cur.ID = cc.CURRENCY_ID;