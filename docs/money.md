# Exact currency integers

Money stores non-negative decimal integers as canonical strings.

| API | Result |
| --- | --- |
| Normalize(value) | Canonical integer string, or nil for invalid input |
| Compare(a, b) | -1, 0, or 1 |
| Clamp(value) | Normalized value capped at MAX, or nil |
| Add(a, b) | Exact addition saturated at MAX |
| Subtract(a, b) | Exact non-negative difference, or nil on underflow |
| Format(value) | Truncated display label such as 1.2M; not a stored value |

`MAX = "1000000000000000000"` (10^18).
Normalize accepts decimal strings up to 40 input characters; it does not apply the cap.
Subtract preserves the original exact arithmetic behavior and does not cap its result.
Use Clamp when accepting a stored balance.

Numeric inputs must be whole, finite, non-negative values at or below 2^53 - 1.
Supply larger values as strings. Add, Subtract, and Compare assert on invalid operands.
Scientific notation, signs, separators, and decimal points are rejected.

Treat NumberValues and Format output as display mirrors. Persist canonical decimal strings.
The module is arithmetic only; purchases and balances still require server authorization and
the integrating game's own atomic persistence.

