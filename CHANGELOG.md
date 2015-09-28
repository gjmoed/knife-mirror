# knife-mirror Change log

## 0.1.2 (2015-09-28)

- process cookbook dependencies, if requested

## 0.1.1 (2015-09-25)

- do not show orphaned cookbook count if count = 0
- improve get_cookbook_meta: return valid (empty) metadata if endpoint (cookbook) does not exist

## 0.1.0 (2015-09-23)

- Initial version (still lots of WIP)
- mirror single cookbook version(s)
- mirror single cookbook, all versions
- mirror all cookbooks, all versions
- skip on (most) errors
- specify source and target Supermarkets
- save failed cookbook versions
- configurable delay to ease load on Supermarkets
- disable meta data replication, supermarket does not honor it anyways
- add some initial docs to readme
- switch gpl license I defaulted my repo with, to Apache 2.0
