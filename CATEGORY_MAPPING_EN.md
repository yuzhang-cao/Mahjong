# Category Mapping

The current single-tile classifier uses 34 classes.

## Suited Tiles

| Label | Tile |
|---|---|
| 0 | 1-man |
| 1 | 2-man |
| 2 | 3-man |
| 3 | 4-man |
| 4 | 5-man |
| 5 | 6-man |
| 6 | 7-man |
| 7 | 8-man |
| 8 | 9-man |
| 9 | 1-pin |
| 10 | 2-pin |
| 11 | 3-pin |
| 12 | 4-pin |
| 13 | 5-pin |
| 14 | 6-pin |
| 15 | 7-pin |
| 16 | 8-pin |
| 17 | 9-pin |
| 18 | 1-sou |
| 19 | 2-sou |
| 20 | 3-sou |
| 21 | 4-sou |
| 22 | 5-sou |
| 23 | 6-sou |
| 24 | 7-sou |
| 25 | 8-sou |
| 26 | 9-sou |

## Honor Tiles

| Label | Tile |
|---|---|
| 27 | East |
| 28 | South |
| 29 | West |
| 30 | North |
| 31 | White |
| 32 | Green |
| 33 | Red |

## Notes

- This mapping is used for single-tile classification and the local dataset folder layout
- `Training/0..33` follows this table directly
- If red fives or `UNKNOWN` are added later, keep a separate detection mapping instead of changing this 34-class table
