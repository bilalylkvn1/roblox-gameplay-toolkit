# Exact currency integers

Money stores non-negative decimal integers as canonical strings.

| API | Result |
| --- | --- |
| Normalize(value) | Canonical integer string, or nil for invalid input |
| Compare(a, b) | -1, 0, or 1 |
| Clamp(value) | Normalized value capped at MAX, or nil |
| Add(a, b) | Exact addition saturated at MAX |
| Subtract(a, b) | Exact non-negative difference, or nil on underflow |
| Multiply(a, b) | Exact multiplication saturated at MAX |
| Divide(a, b) | Exact floor quotient and remainder; asserts when b is zero |
| Format(value) | Truncated display label such as 1.2M; not a stored value |
| FormatFull(value) | Full integer with comma grouping, such as 9,007,199,254,740,993 |

`MAX = "1000000000000000000"` (10^18).
Normalize accepts decimal strings up to 40 input characters; it does not apply the cap.
Subtract preserves the original exact arithmetic behavior and does not cap its result.
Divide also preserves the full result up to the input limit. Its remainder is always smaller
than the divisor. Multiply returns zero for a zero operand, even if the other operand exceeds MAX.
Use Clamp when accepting a stored balance.

Numeric inputs must be whole, finite, non-negative values at or below 2^53 - 1.
Supply larger values as strings. Arithmetic and Compare assert on invalid operands.
Scientific notation, signs, separators, and decimal points are rejected.

```lua
local reward = Money.Multiply("9007199254740993", "3") -- "27021597764222979"
local share, leftover = Money.Divide(reward, "4") -- "6755399441055744", "3"
print(Money.FormatFull(reward)) -- 27,021,597,764,222,979
```

Format and FormatFull display invalid input as "0"; validate separately before persistence.
FormatFull output contains separators and cannot be passed back to Normalize.

Treat NumberValues and Format output as display mirrors. Persist canonical decimal strings.
The module is arithmetic only; purchases and balances still require server authorization and
the integrating game's own atomic persistence.

