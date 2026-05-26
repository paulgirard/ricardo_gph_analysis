import { graphsQuality } from "./qualityExport";

graphsQuality("gravity", false)
  .then(() => {
    console.log("done");
  })
  .catch((error) => console.error(error));
