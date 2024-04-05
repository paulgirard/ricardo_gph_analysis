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

Quality CSV:

```bash
npm run quality
```