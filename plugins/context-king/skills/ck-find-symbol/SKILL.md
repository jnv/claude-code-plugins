---
name: ck-find-symbol
description: Find type/member declarations in C#, TypeScript, Kotlin, and Python/TSX files with ranked matches. Use when grep loops on the same token start forming.
---

# ck find-symbol — Symbol Declaration Locator

Use this command to locate declarations directly instead of repeated grep/find loops.

## Syntax

```bash
ck find-symbol "<symbol>" [--path <folder-or-file>] [--kind type|member] [--top <n>]
```

## Typical usage

```bash
ck find-symbol "TypedGatewayPayment"
ck find-symbol "RefundPaymentAsync" --path src/Modules/PaymentProcessing/ --kind member
ck find-symbol "AdyenBalancePaymentGateway" --kind type
```

## Output

Tab-separated rows:

```
<score>  <file:line>  <kind>  <symbol>  <container>  <signature>
```

- `score`: 0.000–1.000, higher = more exact
- `kind`: `type` or `member`
- `container`: containing type for members

