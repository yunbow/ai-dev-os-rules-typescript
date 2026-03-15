$NOTE
# Decision Criteria for Technology Selection

A decision framework for introducing new technologies, libraries, and tools.

---

## Library Evaluation Criteria

| Evaluation Axis | Weight | Decision Criteria |
|--------|------|---------|
| **Bundle size** | High | Critical if included on the client side. Acceptable for server-only |
| **Maintenance status** | High | Has there been a release in the last 6 months? This threshold catches abandoned projects (no release in 6+ months means likely unmaintained) while allowing for stable libraries with slower release cycles. Also check issue response speed. |
| **Type definitions** | High | TypeScript-first, or reliant on `@types`? |
| **Breaking change frequency** | Medium | Frequency of major version upgrades and migration cost |
| **Learning cost** | Medium | Can the entire team understand it? |
| **Community size** | Low | Activity on Stack Overflow and GitHub |
| **License** | Required | MIT / Apache 2.0 preferred. GPL requires consideration |

Weight definitions: **High** = can veto adoption on its own. **Medium** = weigh against other factors. **Low** = tiebreaker between otherwise equal options. **Required** = must pass, no trade-offs.

### De Facto Standard Identification

A library qualifies as "de facto standard" when it meets 2+ of:
- Referenced in the framework's official documentation (e.g., Next.js docs mention it)
- 10x+ GitHub stars compared to the next alternative
- Used by the framework's own starter templates or examples
- Dominant in npm download counts for its category (>70% market share)

### Bundle Size Guidelines

| Library Type | Acceptable Size | Countermeasure |
|-------------|----------|------|
| UI components | < 10KB with individual imports | Tree-shaking required |
| Utilities | < 5KB | Individual import like lodash → lodash/debounce |
| Date handling | < 10KB | moment.js ❌ → day.js / date-fns ✔ |
| Rich editors, etc. | > 100KB | `dynamic(() => import(), { ssr: false })` |

---

## "Build vs Use" Decision

| Condition | Decision |
|------|------|
| Can be implemented in 50 lines or less | **Build**. Adding a dependency costs more |
| Project-specific domain logic | **Build**. Don't distort the domain to fit an external library |
| An area with 3+ competing libraries | **Choose carefully**. Prefer the de facto standard (see identification criteria above) |

---

## CSS Approach Decision

| Approach | Verdict | Reason |
|------|------|------|
| Tailwind CSS (utility-first) | ✔ Recommended | Static, purgeable, consistent |
| CSS Modules | ✔ Acceptable | Scoped, static |
| CSS Variables | ✔ Recommended | SSOT for themes |
| Runtime CSS-in-JS (styled-components, etc.) | ✖ Prohibited | Bundle bloat, runtime cost |

---

## Database Selection Decision

| Requirement | Option | Decision Criteria |
|------|--------|---------|
| Single server, medium scale | SQLite | Prioritize simplicity. Easy to operate with file-based storage |
| High concurrent writes | PostgreSQL | When SQLite's WAL mode reaches its limits |
| Global distribution | Turso (libSQL) / PlanetScale | When fast reads at the edge are needed |
| Schemaless | MongoDB | Not recommended. Poor compatibility with type safety |

---

## Authentication Method Decision

| Factor | JWT (Default) | Database Session |
|------|-----------------|-----------------|
| Scalability | ✔ Excellent | △ Shared store required |
| Distributed environments | ✔ Excellent | △ Session sharing required |
| Immediate invalidation | △ Handle with version field | ✔ Can be invalidated immediately |
| Recommended case | **Default** | When multi-session management is essential |
