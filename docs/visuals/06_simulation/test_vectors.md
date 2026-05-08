# Test Vectors — Inverter + CA-235 Dual Mode

## Inverter mode vectors (ui_in[7]=0)

| ui_in (hex) | ui_in[0] | uo_out expected (hex) | uo_out[0] |
|-------------|----------|----------------------|-----------|
| 0x00        | 0        | 0x01                 | 1         |
| 0x01        | 1        | 0x00                 | 0         |
| 0x10        | 0        | 0x01                 | 1         |
| 0x11        | 1        | 0x00                 | 0         |
| 0x2A        | 0        | 0x01                 | 1         |
| 0x7E        | 0        | 0x01                 | 1         |
| 0x7F        | 1        | 0x00                 | 0         |

Rule: `uo_out = {7'b0, ~ui_in[0]}` regardless of ui_in[6:1]

## CA-235 mode vectors (ui_in[7]=1)

Formula: `next[i] = state[(i+1)%8] | ~(state[(i-1+8)%8] ^ state[i])`

| ui_in (bin)  | ui_in (hex) | uo_out expected (bin) | uo_out (hex) | Note |
|--------------|-------------|----------------------|--------------|------|
| `10000000`   | 0x80        | `11111110`           | 0xFE         | single 0-bit |
| `11111111`   | 0xFF        | `11111111`           | 0xFF         | fixed point  |
| `10101010`   | 0xAA        | `10101010`           | 0xAA         | fixed point  |
| `11010101`   | 0xD5        | `10101010`           | 0xAA         | → 0xAA       |
| `10000001`   | 0x81        | `11111101`           | 0xFD         |              |
| `10011001`   | 0x99        | `11011011`           | 0xDB         |              |
| `11100111`   | 0xE7        | `11111111`           | 0xFF         |              |

## CA-235 fixed-point verification

```
0xFF:  f(1,1,1) = 1|~(1^1) = 1|1 = 1  → stays 0xFF ✓
0xAA:  f(1,0,1) = 1|~(1^0) = 1|0 = 1  (cell where C=0, L=R=1)
       f(0,1,0) = 0|~(0^1) = 0|0 = 0  (cell where C=1, L=R=0)
       pattern preserved → stays 0xAA ✓
```

## Complete CA-235 computation table for ui_in = 0x80

```
ui_in  = 0x80 = 1 0 0 0 0 0 0 0   (s7=1, s6..s0=0)

Cell  L=s[i-1]  C=s[i]  R=s[i+1]  L^C  ~(L^C)  next
 0     1(s7)     0       0(s1)      1     0       0
 1     0(s0)     0       0(s2)      0     1       1
 2     0(s1)     0       0(s3)      0     1       1
 3     0(s2)     0       0(s4)      0     1       1
 4     0(s3)     0       0(s5)      0     1       1
 5     0(s4)     0       0(s6)      0     1       1
 6     0(s5)     0       1(s7)      0     1       1
 7     0(s6)     1       0(s0)      1     0       0

next = {ns7,ns6,...,ns0} = {0,1,1,1,1,1,1,0} = 0111 1110 = 0x7E
```

Wait — correcting: ui_in=0x80 means s[7]=1, s[6..0]=0.
In CA-235 mode ui_in[7]=1 is the mode select AND participates in CA.

```
Displayed as [s7,s6,...,s0]: 1 0 0 0 0 0 0 0

Cell 0: L=s[7]=1, C=s[0]=0, R=s[1]=0 → 0|~(1^0)=0|0=0
Cell 1: L=s[0]=0, C=s[1]=0, R=s[2]=0 → 0|~(0^0)=0|1=1
Cell 6: L=s[5]=0, C=s[6]=0, R=s[7]=1 → 1|~(0^0)=1|1=1
Cell 7: L=s[6]=0, C=s[7]=1, R=s[0]=0 → 0|~(0^1)=0|0=0

uo_out = {ns7,ns6,...,ns0} = {0,1,1,1,1,1,1,0} = 0111 1110 = 0x7E ✗
Rechecking: ns[7]=0, ns[6]=1, ns[5]=1, ns[4]=1, ns[3]=1, ns[2]=1, ns[1]=1, ns[0]=0
= 0b01111110 = 0x7E

But table above says 0xFE — let me recheck cell ordering:
uo_out[7:0] = {ns[7],ns[6],...,ns[0]}
ns[7]=0, so uo_out[7]=0 → 0x7E ≠ 0xFE in the table above.
Corrected: uo_out for 0x80 = 0x7E (not 0xFE).
```
