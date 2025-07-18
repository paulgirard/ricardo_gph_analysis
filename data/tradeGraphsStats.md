# tradeGraphsStats

We aim at creating a full matrice of bilateral trade between GPH autonomous entities. To achieve this we:

- keep existing trade flows between GPH autonomous cited
- generate missing flows by aggregating existing flows
- generate missing flows by splitting existing flows
- discard internal flows
- discard all other flows (to entities which are not autonomous or to multiple entities we couldn't split)

## Columns

- year
- nbGPHAutonomousCited: number of cited autonomous GPH entities for which we have bilateral trade this year
- nbReportingFT: number of reporting in Federico Tena this year
- worldBilateral: sum of bilateral export trade flows between the GPH autonomous cited this year
- worldFT: sum of FedericoTena total flows (world trade estimation)
- ok_flows/value: flows between cited autonomous GPH entities existing in the source
- aggregation_flows/value: flows between cited autonomous GPH entities created by aggregating existing flows
- split_by_years_ratio_flows/value: flows between cited autonomous GPH entities created by splitting existing flows using ratios from nearby years
- ignore_internal_flows/value: existing flows in source which are identified as internal trade and thus discarded
- discard_collision_flows/value: generated flows which are discarded as we have equivalent data in existing source (duplicates)
- splitFailedParts_flows/value: flows we couldn't split
- toTreat_flows/value: flows we couldn't split (for different reasons... should be merged in splitFailedParts category)

## set theory

In theory we should have:

- nbGPHAutonomousCited = nbReportingFT
- worldBilateral = worldFT

Our worldBilateral should be : ok_value + aggregation_value + split_by_years_ratio_value

The difference between worldBilateral and worldFT can be explained by discarded flows:

worldFT ~= worldBilateral + splitFailedParts_value + toTreat_value

The differences between the numbers of entities is either a lack of source OR flows we couldn't solved which obliged us to discard trade with some entities including in FT.
