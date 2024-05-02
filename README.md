# Historical trade analysis based on RICardo and GeoPolHist datasets

## Requirements

To use these scripts, you need to clone Ricardo and GeoPolHist (GPH) datasets from github and indicate their path into `scripts/src/configuration.json`.

Then you will need node/npm runtime version >= 18 and install deps:

```bash
cd scripts
npm i
```

## Structure

The `scripts` folder contains Typescript code to generate data table from the datasets to fuel the analysis work.

The `data` folder holds extra Work-In-Progress data we edit for our analysis. Those data might well be publish directly in RICardo or GPH once we settled format and scope.

## How to use

### Quality CSV

**How to generate?**

```bash
npm run quality
```

**How to read?**

- Reportings (BestGuess/FT)

value is the ratio of total trade (BestGuess) of the reporting on Federico-Tena series.

Sorted by `avg(log(abs(1-ratio))))`

This metric is used to identify the most suspicious trade values when compared to Federico-Tena.

- Partners (percentage on total bilateral trade)

Sorted by average value among years.

The value is the percentage [0-100] of the sum of export flows to a not reporting partner divided by total bilateral trade (sum of Best Guess).

This metric weights the trade of this `dead-hand` partner in the bilateral world trade of that year.
