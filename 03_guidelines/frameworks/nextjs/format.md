# Format Utility Design Guidelines

This document defines the design policy and implementation patterns for display formatting of dates, numbers, currencies, and more.
It leverages the `Intl` API to provide unified, locale-aware formatting across the entire application.

---

## 1. Core Principles

- **`Intl` API first**: Use the browser/Node.js standard `Intl.*Format` APIs. This eliminates external library dependencies (moment.js, day.js, numeral.js) which typically add 20-70KB to the bundle. The `Intl` API is built into all modern runtimes (browsers, Node.js, Edge), receives locale data from the OS/ICU, and is maintained by the platform rather than requiring npm updates. Libraries are only justified when `Intl` lacks a needed feature (e.g., complex calendar systems or parsing).
- **Locale support**: All format functions accept a locale option
- **Unified input type**: Accept `Date | string | number` and convert internally with `new Date()`
- **Style variations**: Provide presets such as short / medium / long to standardize usage
- **Pure Function**: No side effects, easy to test

---

## 2. Directory Structure

```
src/
  lib/
    format/
      date.ts       # Date formatting
      number.ts     # Number, currency, and byte formatting
      index.ts      # Re-exports
```

---

## 3. Date Formatting

### 3.1 Format Styles

| Style | Output Example (ja) | Output Example (en) | Use Case |
|-------|--------------------|--------------------|----------|
| `short` | 3/4 | 3/4 | List display, compact display |
| `medium` | 3月4日 | Mar 4 | General date display |
| `long` | 2024年3月4日 | March 4, 2024 | Formal date display |
| `full` | 2024年3月4日月曜日 | Monday, March 4, 2024 | Full display with day of week |
| `shortTime` | 3月4日 14:30 | Mar 4, 14:30 | Brief date + time display |
| `mediumTime` | 2024年3月4日 14:30 | Mar 4, 2024, 14:30 | Standard date + time display |
| `longTime` | 2024年3月4日 14:30 | March 4, 2024 14:30:00 | Detailed date + time display |
| `relative` | 2時間前 | 2 hours ago | Relative time |
| `iso` | 2024-03-04 | 2024-03-04 | For APIs / logs |

### 3.2 Unified Format Function

```ts
export type DateFormatStyle =
  | "short" | "medium" | "long" | "full"
  | "shortTime" | "mediumTime" | "longTime"
  | "relative" | "iso";

export interface DateFormatOptions {
  locale?: string;    // Default: "en"
  timeZone?: string;  // Time zone specification
}

// Unified entry point
export function formatDate(
  date: Date | string | number,
  style: DateFormatStyle = "medium",
  options: DateFormatOptions = {}
): string;
```

### 3.3 Individual Format Functions

```ts
// Date only
formatDateShort(date, options)      // "3/4"
formatDateMedium(date, options)     // "3月4日"
formatDateLong(date, options)       // "2024年3月4日"

// Date + time
formatDateTimeShort(date, options)  // "3月4日 14:30"
formatDateTimeMedium(date, options) // "2024年3月4日 14:30"
formatDateTimeLong(date, options)   // "2024年3月4日 14:30:00"

// Time only
formatTime(date, { showSeconds: true })  // "14:30:00"

// ISO format
formatDateISO(date)       // "2024-03-04"
formatDateTimeISO(date)   // "2024-03-04T14:30:00"
```

### 3.4 Relative Time

```ts
export function formatRelativeTime(
  date: Date | string | number,
  options: DateFormatOptions & { now?: Date } = {}
): string {
  const rtf = new Intl.RelativeTimeFormat(locale, { numeric: "auto" });

  // Automatically select appropriate unit
  // < 60 seconds → seconds, < 60 minutes → minutes, < 24 hours → hours,
  // < 7 days → days, < 4 weeks → weeks, < 12 months → months, beyond → years
}
```

**Key points**:
- Uses `Intl.RelativeTimeFormat` to auto-generate locale-appropriate "ago" / "from now" expressions
- `numeric: "auto"` enables natural expressions like "yesterday" and "tomorrow"

---

## 4. Number Formatting

### 4.1 Basic Numbers

```ts
// Locale-aware number formatting
formatNumber(1234567)                      // "1,234,567"
formatNumber(1234567, { locale: "de" })    // "1.234.567"
```

### 4.2 Compact Display

Two approaches to choose from:

```ts
// Manual compact (fixed K / M / B)
formatCompactNumber(1234)       // "1.2K"
formatCompactNumber(1234567)    // "1.2M"
formatCompactNumber(1234567890) // "1.2B"

// Intl compact (locale-aware)
formatCompactNumberIntl(12345, { locale: "ja" })  // "1.2万"
formatCompactNumberIntl(12345, { locale: "en" })  // "12K"
```

| Function | Use Case |
|----------|----------|
| `formatCompactNumber` | Fixed English display (dashboards, etc.) |
| `formatCompactNumberIntl` | Display requiring multilingual support |

### 4.3 Currency Formatting

```ts
// General currency formatting
formatCurrency(1234.56, { currency: "USD" })  // "$1,234.56"
formatCurrency(1234, { currency: "JPY" })     // "¥1,234"

// Shortcut functions
formatUSD(1234.56)   // "$1,234.56"  (2-4 decimal places)
formatJPY(1234)      // "¥1,234"     (no decimals)
```

**Key points**:
- Uses `Intl.NumberFormat` with `style: "currency"`
- Sets appropriate decimal places per currency (JPY: 0, USD: 2)
- Locale-appropriate currency symbol placement ($1,234 vs 1,234 USD)

### 4.4 Percentage

```ts
formatPercent(0.1234)                     // "12.34%"
formatPercent(0.1234, { precision: 0 })   // "12%"
formatPercent(85, { multiply: false })    // "85%" (when value is already a percentage)
```

### 4.5 Byte Size

```ts
formatBytes(0)          // "0 B"
formatBytes(1024)       // "1 KB"
formatBytes(1234567)    // "1.18 MB"
formatBytes(1234567890) // "1.15 GB"
```

### 4.6 Duration

```ts
// Compact format
formatDuration(125)   // "2:05"
formatDuration(3661)  // "1:01:01"

// Human-readable format (locale-aware)
formatDurationLong(3661, "ja")  // "1時間1分1秒"
formatDurationLong(3661, "en")  // "1h 1m 1s"

// Milliseconds
formatMilliseconds(123)   // "123ms"
formatMilliseconds(1234)  // "1.23s"
```

### 4.7 Decimals and Ordinals

```ts
// Specifying decimal places
formatDecimal(3.14159, 2)  // "3.14"

// Ordinals (English)
formatOrdinal(1)   // "1st"
formatOrdinal(2)   // "2nd"
formatOrdinal(3)   // "3rd"
formatOrdinal(11)  // "11th"
```

---

## 5. Implementation Patterns

### 5.1 Unified Input Type

All format functions accept `Date | string | number`:

```ts
// All produce the same result
formatDateLong(new Date("2024-03-04"))
formatDateLong("2024-03-04")
formatDateLong(1709510400000)
```

### 5.2 Options Design

```ts
// Common options type
interface DateFormatOptions {
  locale?: string;     // Default: "en"
  timeZone?: string;
}

interface NumberFormatOptions {
  locale?: string;     // Default: "en"
}

// Extended options type
interface CurrencyFormatOptions extends NumberFormatOptions {
  currency?: string;
  minimumFractionDigits?: number;
  maximumFractionDigits?: number;
}
```

**Key points**:
- All options are optional (have default values)
- Extend base types with extends to maintain type consistency

### 5.3 Re-export Pattern

```ts
// lib/format/index.ts
export * from "./date";
export * from "./number";
```

Consumer side:

```ts
import { formatDate, formatCurrency, formatBytes } from "@/lib/format";
```

---

## 6. Usage Guidelines

### Recommended Styles by Screen

| Screen | Date Style | Number Style |
|--------|-----------|-------------|
| Table list | `short` / `medium` | `formatNumber` / `formatCompactNumber` |
| Detail page | `long` / `mediumTime` | `formatNumber` |
| Logs / Audit | `mediumTime` / `iso` | `formatNumber` |
| Timeline | `relative` | - |
| Dashboard | `short` | `formatCompactNumber` |
| Monetary amounts | - | `formatCurrency` / `formatUSD` / `formatJPY` |
| File information | - | `formatBytes` |
| Performance | - | `formatMilliseconds` |

---

## 7. Best Practices

### DO (Recommended)

```ts
// ✅ Use unified format functions
formatDate(createdAt, "medium")
formatCurrency(price, { currency: "USD" })

// ✅ Propagate locale option from parent
function UserProfile({ locale }: { locale: string }) {
  return <span>{formatDate(user.createdAt, "long", { locale })}</span>;
}
```

### DON'T (Not Recommended)

```ts
// ❌ Hardcoded date format
`${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()}`

// ❌ Calling toLocaleString directly with options every time
date.toLocaleDateString("ja", { year: "numeric", month: "long", day: "numeric" })
// → Use formatDateLong(date) instead

// ❌ Hardcoded number formatting
(num / 1000000).toFixed(1) + "M"
// → Use formatCompactNumber(num) instead
```

---

## 8. Summary

| Category | Function | Use Case |
|----------|----------|----------|
| Date | `formatDate(date, style)` | Unified entry point |
| Date | `formatDateShort/Medium/Long` | Style-specific formatting |
| Date + Time | `formatDateTimeShort/Medium/Long` | Combined date and time |
| Relative Time | `formatRelativeTime` | "ago" display |
| ISO | `formatDateISO / formatDateTimeISO` | For APIs / logs |
| Number | `formatNumber` | Locale-aware number |
| Compact | `formatCompactNumber / formatCompactNumberIntl` | K/M/B display |
| Currency | `formatCurrency / formatUSD / formatJPY` | Currency display |
| Percent | `formatPercent` | Percentage |
| Bytes | `formatBytes` | File size |
| Duration | `formatDuration / formatDurationLong` | Time display |
| Milliseconds | `formatMilliseconds` | Performance measurement |
| Decimal | `formatDecimal` | Decimal place specification |
| Ordinal | `formatOrdinal` | 1st, 2nd, 3rd |
