import { graphsQuality } from "./qualityExport";

graphsQuality("ratios", true)
  .then(() => {
    console.log("done");
  })
  .catch((error) => console.error(error));
