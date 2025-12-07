# Symlinks Configuration

This repository uses symlinks for large data directories to avoid storing them in git.

## Symlink Locations

| Symlink | Target |
|---------|--------|
| `checkpoints/` | `/srv/local/shared/temp/tmp1/jtu9/graph-r1/checkpoints` |
| `datasets/` | `/srv/local/shared/temp/tmp1/jtu9/graph-r1/datasets` |
| `expr/` | `/srv/local/shared/temp/tmp1/jtu9/graph-r1/expr` |
| `expr_results/` | `/srv/local/shared/temp/tmp1/jtu9/graph-r1/expr_results` |
| `models/` | `/srv/local/shared/temp/tmp1/jtu9/graph-r1/models` |

## Purpose

- **checkpoints/** - Model training checkpoints
- **datasets/** - Training and evaluation datasets
- **expr/** - Experiment configurations and logs
- **expr_results/** - Experiment output results
- **models/** - Pre-trained and fine-tuned models

## Recreating Symlinks

If you need to recreate these symlinks:

```bash
ln -s /srv/local/shared/temp/tmp1/jtu9/graph-r1/checkpoints ./checkpoints
ln -s /srv/local/shared/temp/tmp1/jtu9/graph-r1/datasets ./datasets
ln -s /srv/local/shared/temp/tmp1/jtu9/graph-r1/expr ./expr
ln -s /srv/local/shared/temp/tmp1/jtu9/graph-r1/expr_results ./expr_results
ln -s /srv/local/shared/temp/tmp1/jtu9/graph-r1/models ./models
```
