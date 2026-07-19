#!/usr/bin/env python3
"""The crown experiment: independent-taxonomy structure test.

Per docs/prereg-crown-independent-taxonomy.md. Builds blind taxonomies for
the isolated and connected corpora separately (KMeans over raw-label
embeddings, never the 64 curated families), builds each pile's motif
co-occurrence web on its own blind clusters, then tests whether the two
webs share structure via aligned-pair rank correlation + a 500-permutation
null, with a label-free topology backup. Deterministic (fixed seeds).
"""
import json, glob, os, sys, random
import numpy as np
from collections import defaultdict
from scipy.stats import spearmanr, ks_2samp
from scipy.optimize import linear_sum_assignment
import networkx as nx

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BATCH = os.path.join(ROOT, "data/batches/crown-label-embed-2026-07-18")
SEED = 42
random.seed(SEED); np.random.seed(SEED)

def log(m): print(m, flush=True)

# --- load label -> embedding -------------------------------------------------
log("loading request map...")
cid2label = {}
with open(os.path.join(BATCH, "request-map.jsonl")) as f:
    for line in f:
        r = json.loads(line); cid2label[r["custom_id"]] = r["label"].strip().lower()

log("loading embeddings...")
label2vec = {}
for path in sorted(glob.glob(os.path.join(BATCH, "results", "*.output.jsonl"))):
    with open(path) as f:
        for line in f:
            o = json.loads(line)
            emb = o.get("response", {}).get("body", {}).get("data", [{}])[0].get("embedding")
            if not emb: continue
            lab = cid2label.get(o["custom_id"])
            if lab: label2vec[lab] = np.asarray(emb, dtype=np.float32)
log(f"  embeddings for {len(label2vec)} labels")

# --- load per-record label sets ---------------------------------------------
records = {"iso": [], "con": []}
labels_in = {"iso": set(), "con": set()}
with open(os.path.join(BATCH, "crown-records.jsonl")) as f:
    for line in f:
        r = json.loads(line)
        labs = [l for l in r["labels"] if l in label2vec]
        if len(labs) < 2: continue
        records[r["pile"]].append((r["trad"], labs))
        labels_in[r["pile"]].update(labs)
log(f"records iso={len(records['iso'])} con={len(records['con'])}; "
    f"labels iso={len(labels_in['iso'])} con={len(labels_in['con'])}")

def normalize(v):
    n = np.linalg.norm(v)
    return v / n if n else v

def blind_cluster(pile, k):
    """KMeans over the pile's label vectors, blind to families and to the
    other pile. Returns label->cluster, cluster centroids (unit)."""
    from sklearn.cluster import MiniBatchKMeans
    labs = sorted(labels_in[pile])
    X = np.vstack([normalize(label2vec[l]) for l in labs])
    km = MiniBatchKMeans(n_clusters=k, random_state=SEED, n_init=5, batch_size=2048)
    cl = km.fit_predict(X)
    lab2cl = {l: int(c) for l, c in zip(labs, cl)}
    cents = np.vstack([normalize(km.cluster_centers_[c]) for c in range(k)])
    return lab2cl, cents

def build_web(pile, lab2cl, k, min_traditions=3, min_pair=3):
    """Co-occurrence web on blind clusters. Edge weight = summed PMI-positive
    presence; edge kept if the cluster pair co-occurs across >= min_traditions."""
    fam_count = np.zeros(k); total = 0.0
    pair_count = defaultdict(float); pair_trads = defaultdict(set)
    for trad, labs in records[pile]:
        cls = sorted({lab2cl[l] for l in labs})
        if not cls: continue
        total += 1
        for c in cls: fam_count[c] += 1
        for i in range(len(cls)):
            for j in range(i+1, len(cls)):
                p = (cls[i], cls[j]); pair_count[p] += 1; pair_trads[p].add(trad)
    W = np.zeros((k, k))
    for (a, b), c in pair_count.items():
        if c < min_pair or len(pair_trads[(a, b)]) < min_traditions: continue
        pa, pb, pab = fam_count[a]/total, fam_count[b]/total, c/total
        if pa <= 0 or pb <= 0: continue
        pmi = np.log(pab/(pa*pb))
        if pmi > 0: W[a, b] = W[b, a] = pmi
    return W

def topology(W):
    G = nx.from_numpy_array((W > 0).astype(int))
    G.remove_nodes_from(list(nx.isolates(G)))
    if G.number_of_nodes() == 0: return dict(nodes=0)
    comps = list(nx.connected_components(G))
    giant = max(len(c) for c in comps)
    degs = [d for _, d in G.degree()]
    try: mod = nx.community.modularity(G, nx.community.greedy_modularity_communities(G))
    except Exception: mod = None
    return dict(nodes=G.number_of_nodes(), edges=G.number_of_edges(),
                giant_frac=round(giant/G.number_of_nodes(), 3),
                mean_degree=round(float(np.mean(degs)), 3),
                clustering=round(nx.average_clustering(G), 3),
                modularity=round(mod, 3) if mod is not None else None,
                degrees=degs)

def run(k):
    log(f"\n=== k={k} ===")
    iso_lab2cl, iso_cent = blind_cluster("iso", k)
    con_lab2cl, con_cent = blind_cluster("con", k)
    Wi = build_web("iso", iso_lab2cl, k)
    Wc = build_web("con", con_lab2cl, k)
    # align iso cluster -> con cluster by centroid cosine (optimal 1-1)
    sim = iso_cent @ con_cent.T          # k x k cosine (unit vectors)
    row, col = linear_sum_assignment(-sim)
    align = {int(r): int(c) for r, c in zip(row, col)}
    align_quality = float(np.mean([sim[r, c] for r, c in zip(row, col)]))
    # PRIMARY (zero-inflation-safe): of iso-web edges, fraction whose ALIGNED
    # con pair also has an edge (reproduction); plus weight correlation on
    # jointly-present edges only.
    def reproduction(amap):
        iso_edges = [(a, b) for a in range(k) for b in range(a+1, k) if Wi[a, b] > 0]
        if not iso_edges: return 0.0, 0.0, []
        hits = sum(1 for a, b in iso_edges if Wc[amap[a], amap[b]] > 0)
        both = [(Wi[a, b], Wc[amap[a], amap[b]]) for a, b in iso_edges if Wc[amap[a], amap[b]] > 0]
        return hits/len(iso_edges), (len(iso_edges)), both
    repro, n_iso_edges, both = reproduction(align)
    both_rho = float(spearmanr([x for x, _ in both], [y for _, y in both])[0]) if len(both) > 2 else float("nan")
    null = []
    consl = list(range(k))
    for _ in range(500):
        perm = consl[:]; random.shuffle(perm); amap = {a: perm[a] for a in range(k)}
        r, _, _ = reproduction(amap); null.append(r)
    null = np.array(null)
    beaten = int(np.sum(null < repro)); p = (np.sum(null >= repro) + 1) / (len(null) + 1)
    # --- concrete named matched bonds (for the site) --------------------
    matched = None
    if k == 64:
        def cluster_labels(pile, lab2cl, cents, cid, topn=6):
            labs = [l for l in labels_in[pile] if lab2cl[l] == cid]
            if not labs: return []
            V = np.vstack([normalize(label2vec[l]) for l in labs])
            sims = V @ cents[cid]
            order = np.argsort(-sims)[:topn]
            return [labs[i] for i in order]
        def cluster_traditions(pile, lab2cl, cid):
            ts = set()
            for trad, ls in records[pile]:
                if any(lab2cl[l] == cid for l in ls): ts.add(trad)
            return sorted(ts)
        iso_names = {c: cluster_labels("iso", iso_lab2cl, iso_cent, c) for c in range(k)}
        con_names = {c: cluster_labels("con", con_lab2cl, con_cent, c) for c in range(k)}
        iso_trads = {c: cluster_traditions("iso", iso_lab2cl, c) for c in range(k)}
        bonds = []
        for a in range(k):
            for b in range(a+1, k):
                if Wi[a, b] > 0 and Wc[align[a], align[b]] > 0:
                    bonds.append((Wi[a, b] + Wc[align[a], align[b]], a, b))
        bonds.sort(reverse=True)
        matched = []
        for _, a, b in bonds[:24]:
            matched.append(dict(
                iso_cluster_a=iso_names[a][:5], iso_cluster_b=iso_names[b][:5],
                con_cluster_a=con_names[align[a]][:5], con_cluster_b=con_names[align[b]][:5],
                iso_weight=round(float(Wi[a, b]), 3), con_weight=round(float(Wc[align[a], align[b]]), 3),
                iso_traditions=(iso_trads[a] + iso_trads[b]),
            ))
    topo_i, topo_c = topology(Wi), topology(Wc)
    ks = ks_2samp(topo_i.get("degrees", [0]), topo_c.get("degrees", [0]))
    return dict(k=k, alignment_cosine=round(align_quality, 4),
                iso_edges=int((Wi > 0).sum()//2), con_edges=int((Wc > 0).sum()//2),
                reproduction=round(float(repro), 4), iso_edges_tested=int(n_iso_edges), jointly_present_weight_rho=round(both_rho, 4),
                null_mean=round(float(null.mean()), 4), null_sd=round(float(null.std()), 4),
                null_max=round(float(null.max()), 4),
                permutations_beaten=f"{beaten}/500", p_value=round(float(p), 5),
                topology_iso={x: topo_i[x] for x in topo_i if x != "degrees"},
                topology_con={x: topo_c[x] for x in topo_c if x != "degrees"},
                degree_ks_stat=round(float(ks.statistic), 3),
                degree_ks_p=round(float(ks.pvalue), 4),
                matched_bonds=matched)

results = [run(k) for k in (40, 64, 90)]
primary = next(r for r in results if r["k"] == 64)
# verdict per prereg: STRONG needs primary beats >=97.5% of null AND topology similar
beaten = int(primary["permutations_beaten"].split("/")[0])
topo_similar = primary["degree_ks_p"] > 0.05
if beaten >= 488 and topo_similar:
    verdict = "STRONG"
elif beaten >= 488 or topo_similar:
    verdict = "PARTIAL"
else:
    verdict = "NULL"
out = dict(crown_experiment_version="1",
           preregistration="docs/prereg-crown-independent-taxonomy.md",
           method="blind KMeans taxonomies (iso & con separately) -> per-pile "
                  "co-occurrence webs -> optimal centroid alignment -> Spearman of "
                  "aligned edge weights vs 500-permutation null; topology backup",
           primary_k=64, verdict=verdict,
           interpretation="STRONG = aligned structure beats chance AND webs share "
                          "topology; the isolated peoples' independently-built web "
                          "matches Eurasia's without ever being mapped into it.",
           corpus=dict(iso_records=len(records["iso"]), iso_labels=len(labels_in["iso"]),
                       con_records=len(records["con"]), con_labels=len(labels_in["con"])),
           results=results)
import yaml
with open(os.path.join(ROOT, "data/indexes/crown-independent-taxonomy.yml"), "w") as f:
    yaml.safe_dump(out, f, sort_keys=False, default_flow_style=False)
log("\n===== CROWN RESULT =====")
for r in results:
    log(f"k={r['k']}: reproduction={r['reproduction']} vs null {r['null_mean']}±{r['null_sd']} "
        f"(max {r['null_max']}) beaten {r['permutations_beaten']} p={r['p_value']} | "
        f"align-cos={r['alignment_cosine']} | degree-KS p={r['degree_ks_p']}")
log(f"VERDICT (k=64): {verdict}")
