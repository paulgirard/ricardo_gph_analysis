import json
from csv import DictReader, DictWriter
from os.path import exists, join

import networkx
import signed_louvain.community_detection as cd
from signed_louvain import util

flow_file_headers = [
    "key",
    "source",
    "target",
    "TIBI",
    "maxObservedTradeValues",
    "observedTradeValues",
    "coMembershipScore",
    "bridgeNessEdgeScore",
    "ambiguityScore",
    "maxObservedTradeValue",
    "sourceCited",
    "sourceReporting",
    "sourceLabel",
    "sourceGphStatus",
    "sourceBlockLouvainTibi",
    "sourceBlockLouvainMaxobservedtradevalues",
    "sourceBlockIntraMax",
    "sourceBlockAn",
    "sourceMeanAmbiguityScore",
    "targetCited",
    "targetReporting",
    "targetLabel",
    "targetGphStatus",
    "targetBlockLouvainTibi",
    "targetBlockLouvainMaxobservedtradevalues",
    "targetBlockIntraMax",
    "targetBlockAn",
    "targetMeanAmbiguityScore",
]


if __name__ == "__main__":
    # read undirected TIBI weighted networks

    for year in range(1833, 2026):
        flowCsvFilePath = join("../../results/communities/louvain", f"{year}.csv")
        if exists(flowCsvFilePath):
            print(year)
            graph = networkx.Graph()
            communities = {}
            flows = []
            with open(flowCsvFilePath, "r") as dataF:
                flows = list(DictReader(dataF))
                
                for flow in flows:
                    if flow["TIBI"] != "":
                        if not graph.has_node(flow["source"]):
                            graph.add_node(flow["source"])
                        if not graph.has_node(flow["target"]):
                            graph.add_node(flow["target"])
                        graph.add_edge(
                            flow["source"], flow["target"], TIBI=float(flow["TIBI"])
                        )
            # SIGNED-LOUVAIN
            posgraph, neggraph = util.build_subgraphs(graph, weight="TIBI")
            communities:dict= cd.best_partition(
                    layers=[posgraph, neggraph],
                    layer_weights=[1.0, -1.0],
                    resolutions=[1.0, 1.0],
                    masks=[False, True],
                    k=2,
                    initial_membership=None,
                    weight="TIBI",
                    random_state=42,
                    pass_max=40,
                    return_dendogram=False,
                    silent=True,
                )
            missing_node_in_communities = [n for n in graph.nodes() if n not in communities]
            if len(missing_node_in_communities)>0:
                print(f"missing {missing_node_in_communities} in communities")
                for n in missing_node_in_communities:
                    if not posgraph.has_node(n):
                        print("not in posgraph")
                    if not neggraph.has_node(n):
                        print("not in neggraph")
            print(year, communities)
            
            for flow in flows:
                try:
                    flow["sourceBlockLouvainTibi"] = communities[flow["source"]]
                    flow["targetBlockLouvainTibi"] = communities[flow["target"]]
                except KeyError:
                    for n in [flow['source'], flow['target']]:
                        if not graph.has_node(n):
                            print(f"{n} not in graph")
                        if not posgraph.has_node(n):
                            print(f"{n} not in posgraph")
                        if not neggraph.has_node(n):
                            print(f"{n} not in neggraph")
            # EXPORT CSV
            with open(flowCsvFilePath, "w") as dataF:
                writer = DictWriter(dataF, flow_file_headers)
                writer.writeheader()
                writer.writerows(flows)
            
            # EXPORT BLOCKS CSV
            gphBlocksByYearFieldnames = [
                "id",
                "label",
                "blockTibi",
                "blockLouvainMaxobservedtradevalues",
                "blockIntraMax",
                "year",
                "cafFob",
            ]
            flowCsvFilePath = join(
                "../../results/communities/gph_blocks_by_year/", f"{year}.csv"
            )
            with open(flowCsvFilePath, "r") as blockFile:
                blocks = list(DictReader(blockFile))
            with open(flowCsvFilePath, "w") as blockFile:
                writer = DictWriter(blockFile, gphBlocksByYearFieldnames)
                writer.writeheader()
                for block in blocks:
                    block["blockTibi"] = communities[block["id"]]
                    writer.writerow(block)

            # Gephi lite
            with open(join("../../results/communities/louvain/", f"{year}_gephi_lite.json"), 'r', encoding='utf8') as f:
                gephiLiteFileString = f.read()
                
                gephiLiteFile = json.loads(gephiLiteFileString)
            with open(join("../../results/communities/louvain/", f"{year}_gephi_lite.json"), 'w') as f:
                for node, community in communities.items():
                    gephiLiteFile['graphDataset']['nodeData'][node]['blockLouvainTibi']=community
                json.dump(gephiLiteFile, f)
        else:
            print(f'file {flowCsvFilePath} does not exist')
