# CA Rule-235 — Truth Table & Boolean Derivation

## Rule number to bit pattern

```
Rule 235  =  0xEB  =  0b 1110 1011

Bit index:   7  6  5  4  3  2  1  0
             ↕  ↕  ↕  ↕  ↕  ↕  ↕  ↕
Binary:      1  1  1  0  1  0  1  1
```

## Full truth table

```
┌───┬───┬───┬───────────────────┬──────┐
│ L │ C │ R │ {L,C,R} = idx    │ next │
├───┼───┼───┼───────────────────┼──────┤
│ 1 │ 1 │ 1 │ 7  (bit 7 of 235)│  1   │
│ 1 │ 1 │ 0 │ 6  (bit 6 of 235)│  1   │
│ 1 │ 0 │ 1 │ 5  (bit 5 of 235)│  1   │
│ 1 │ 0 │ 0 │ 4  (bit 4 of 235)│  0   │ ← zero
│ 0 │ 1 │ 1 │ 3  (bit 3 of 235)│  1   │
│ 0 │ 1 │ 0 │ 2  (bit 2 of 235)│  0   │ ← zero
│ 0 │ 0 │ 1 │ 1  (bit 1 of 235)│  1   │
│ 0 │ 0 │ 0 │ 0  (bit 0 of 235)│  1   │
└───┴───┴───┴───────────────────┴──────┘
```

## Boolean minimisation (Karnaugh map)

```
          LR
    C  │ 00  01  11  10
   ────┼────────────────
    0  │  1   1   1   0   ← only 100 gives 0
    1  │  0   1   1   1   ← only 010 gives 0
```

### Zero minterms
- `m₂` : L=0, C=1, R=0  →  ~L & C & ~R
- `m₄` : L=1, C=0, R=0  →   L & ~C & ~R

Both zeros share: **R = 0** and **L ≠ C**

### Minimal SOP (groups from K-map)

| Group | Cells covered | Term |
|-------|--------------|------|
| R=1 column | m₁,m₃,m₅,m₇ | R |
| ~L·~C block | m₀,m₁ | ~L·~C |
| L·C block | m₆,m₇ | L·C |

```
f = R  |  (~L & ~C)  |  (L & C)
  = R  |  ~(L ^ C)           ← since (L XNOR C) = ~L·~C | L·C
```

### Final minimised expression

```
   next  =  R  |  ~(L ^ C)
```

Gate count: **XOR2 + INV + OR2 = 3 gates per cell × 8 cells = 24 gates**

## Fixed points (8-cell wrap-around)

| State  | Binary     | Property |
|--------|------------|---------|
| `0xFF` | `11111111` | All-ones fixed point: f(1,1,1)=1 ✓ |
| `0xAA` | `10101010` | Alternating fixed point: f(1,0,1)=1, f(0,1,0)=0 ✓ |
| `0x55` | `01010101` | Converges to 0xAA in one step |
| `0x00` | `00000000` | Converges to 0xFF in one step: f(0,0,0)=1 |
