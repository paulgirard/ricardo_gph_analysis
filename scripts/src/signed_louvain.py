import signed_louvain.community_detection as cd
from signed_louvain import util

nb_nodes = 8
edges = [(0, 1, -1), (1, 2, -1), (2, 3, 1), (3, 4, -1), (4, 5, -1), (5, 6, 1), (6, 7, -1)]
graph = util.build_nx_graph(nb_nodes, edges)
posgraph, neggraph = util.build_subgraphs(graph, weight='weight')

communities = cd.best_partition(layers=[posgraph, neggraph],
                                layer_weights=[1., -1.],
                                resolutions=[1., 1.],
                                masks=[False, True],
                                k=2,
                                initial_membership=None,
                                weight='weight',
                                random_state=42,
                                pass_max=40,
                                return_dendogram=False,
                                silent=True)

print(communities)
assert communities == {0: 2, 1: 1, 2: 2, 3: 2, 4: 1, 5: 0, 6: 0, 7: 1}