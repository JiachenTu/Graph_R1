# Retrieval Server Documentation

## Overview

The retrieval server (`script_api.py`) provides a FastAPI-based search endpoint for the Graph-R1 system. It loads embedding models, FAISS indices, and a knowledge hypergraph to perform semantic search over entities and hyperedges.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Retrieval Server (Port 8001)                 │
├─────────────────────────────────────────────────────────────────┤
│  1. FlagEmbedding Model (BGE-large-en-v1.5)                     │
│     - Encodes queries into dense vectors                        │
│                                                                 │
│  2. FAISS Indices                                               │
│     - index_entity.bin (~494MB) - Entity embeddings             │
│     - index_hyperedge.bin (~402MB) - Hyperedge embeddings       │
│                                                                 │
│  3. KV Stores (JSON)                                            │
│     - kv_store_entities.json (~31MB)                            │
│     - kv_store_hyperedges.json (~33MB)                          │
│                                                                 │
│  4. GraphR1 Knowledge Hypergraph                                │
│     - graph_chunk_entity_relation.graphml (~120MB)              │
└─────────────────────────────────────────────────────────────────┘
```

## Request Flow

```
POST /search
    │
    ▼
┌──────────────────┐
│ Encode queries   │  FlagEmbedding model
│ into vectors     │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ FAISS search     │  Find top-k similar entities & hyperedges
│ (k=5 each)       │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ GraphR1 aquery   │  Traverse hypergraph for context
│                  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Return JSON      │  Knowledge snippets with relevance scores
│ results          │
└──────────────────┘
```

## The Issue: Connection Refused

### Symptoms
- `curl` to `http://localhost:8001/search` returned "Connection refused"
- Multiple `script_api.py` processes stuck in `Dl` state (uninterruptible disk I/O wait)
- Port 8001 not listening despite processes running

### Root Cause: NFS vs Local SSD

The cluster has two storage systems:

| Storage | Mount Point | Speed | Use Case |
|---------|-------------|-------|----------|
| NFS (Network) | `/home/jtu9/` | Slow (~10-50 MB/s) | Home directories |
| Local NVMe SSD | `/srv/local/` | Fast (~3000 MB/s) | Large data, caches |

**The problem:** HuggingFace was downloading the `BAAI/bge-large-en-v1.5` model (~1.3GB) to the default cache at `~/.cache/huggingface/` which is on slow NFS storage. This caused:

1. Extremely slow model download (10+ minutes vs ~30 seconds)
2. Processes stuck in disk I/O wait (`Dl` state)
3. Multiple competing processes all trying to download/load simultaneously

### The Fix

Set `HF_HOME` environment variable to use local SSD cache:

```bash
export HF_HOME=/srv/local/shared/temp/tmp1/jtu9/hf_cache
```

**Permanent fix** (added to `~/.bashrc`):
```bash
export HF_HOME="/srv/local/shared/temp/tmp1/jtu9/hf_cache"
export HF_DATASETS_CACHE="$HF_HOME/datasets"
export TRANSFORMERS_CACHE="$HF_HOME/transformers"
```

## Data Location

The `expr/` directory containing FAISS indices and graph data is already symlinked to local SSD:

```
expr/ → /srv/local/shared/temp/tmp1/jtu9/graph-r1/expr
```

See `SYMLINKS.md` for all symlink configurations.

## Running the Server

### Quick Start
```bash
cd /home/jtu9/cs512/Graph-R1
source ~/miniconda3/etc/profile.d/conda.sh
conda activate graphr1
python script_api.py --data_source 2WikiMultiHopQA
```

### With tmux (Recommended for Long-Running)
```bash
tmux new-session -d -s retrieval \
  "source ~/miniconda3/etc/profile.d/conda.sh && \
   conda activate graphr1 && \
   python script_api.py --data_source 2WikiMultiHopQA"

# Attach to view logs
tmux attach -t retrieval
```

### Expected Startup Sequence

| Step | Duration | Description |
|------|----------|-------------|
| 1 | 30-60s | Load FlagAutoModel (BGE-large) |
| 2 | 10-30s | Load `index_entity.bin` (494MB) |
| 3 | 5-10s | Load `kv_store_entities.json` |
| 4 | 10-30s | Load `index_hyperedge.bin` (402MB) |
| 5 | 5-10s | Load `kv_store_hyperedges.json` |
| 6 | 20-60s | Initialize GraphR1 (load graphml) |
| 7 | - | Server starts on port 8001 |

**Total startup time:** 2-5 minutes (first run may be longer if model needs downloading)

## Testing the Endpoint

```bash
curl -X POST http://localhost:8001/search \
  -H "Content-Type: application/json" \
  -d '{"queries": ["What is the capital of France?"]}'
```

## Troubleshooting

### Server won't start / Connection refused
1. Check for stuck processes: `ps aux | grep script_api`
2. Kill stuck processes: `pkill -9 -f "script_api.py"`
3. Verify HF_HOME is set: `echo $HF_HOME`
4. Start server with explicit HF_HOME:
   ```bash
   export HF_HOME=/srv/local/shared/temp/tmp1/jtu9/hf_cache
   python script_api.py --data_source 2WikiMultiHopQA
   ```

### Check if server is running
```bash
lsof -i :8001
# or
curl http://localhost:8001/docs  # OpenAPI docs
```

### View tmux session
```bash
tmux list-sessions
tmux attach -t retrieval
```
