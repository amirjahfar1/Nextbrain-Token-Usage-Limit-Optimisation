# Big-file management

No file is big. A file that must exist large is either guarded, indexed or split. Classes are set in `.agents/token-optimisation.conf` (`never`, `ranged`) and by `scripts/bigfile.py scan`.

## B1 Three classes
`never` (lockfiles, build output, minified), `ranged` (large sources that must stay whole, e.g. a catalog JSON), `split` (oversized docs). `bigfile.py scan` lists candidates and proposes a class.

## B2 never: query, do not open
Denied by `Read(...)` rules and the guard hook. Use the package manager (`pnpm why`, `npm ls`) or `grep -n -m 20`.

## B3 ranged: index plus slice
`bigfile.py index <file>` writes `<file>.index/` (a parent plus shards of 60 rows: key, start, end, title). `bigfile.py get <file> <key>` prints one slice (max 120 lines). The guard denies a full read without `limit`. A stale index (hash mismatch) is refused until re-indexed.

## B4 split: shards plus parent index
`bigfile.py split-md <file> --apply` splits by H2 into `<name>/NN-slug.md`; the original becomes a parent with one line per shard and its trigger. Shards are then the source of truth. Dry-run by default.

## B5 Generated files keep their generator
Never hand-edit a generated shard or index. Change the source and re-run the generator, then the size check.

## B6 New file over the limit
Split it in the same change. `scripts/check-size.sh` fails the check otherwise.
