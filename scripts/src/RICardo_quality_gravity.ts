import { graphsQuality } from "./qualityExport";

graphsQuality("gravity", true)
  .then(() => {
    console.log("done");
  })
  .catch((error) => console.error(error));
