# Feature Design Prompt

A prompt template for making guideline-based design decisions during the design phase of new features.

---

## Prompt

```
Please design the following feature.

## Design Process

### 1. Organizing Requirements
- What problem does this feature solve
- Who is affected and what is the expected outcome

### 2. Architecture Decisions (02_decision-criteria/architecture.md)

#### Data Flow Design
- Data sources (DB / External API / User input)
- Data flow (Action → Service → Repository)
- State management location (Server / Context / Local state)

### 3. File Structure Design

Design the file structure following project-structure.md:
- List files to create or modify
- Assign each file to the correct layer (router/service/schema/etc.)
- Verify no cross-feature imports are introduced

### 4. Security Design (common/security.md)
- [ ] Is authentication required
- [ ] Is resource ownership check required
- [ ] Input validation schema definition
- [ ] Is rate limiting required
- [ ] Handling of sensitive data (encryption/masking)

### 5. Error Handling Design (02_decision-criteria/error-strategy.md)
- List and classify possible errors (System / Application / User)
- Display method for each error
- Identify retryable errors

### 6. Test Strategy (common/testing.md)
- Unit test targets (business logic, schemas)
- Integration test targets (actions, DB operations)
- E2E test targets (user journeys)

## Design Checklist

### Required
- [ ] Authentication check in protected operations
- [ ] Server-side input validation
- [ ] Type-safe error handling
- [ ] Structured log output
- [ ] File and variable names following naming conventions (common/naming.md)

### Recommended
- [ ] Internationalization support (i18n key definitions)
- [ ] Accessibility considerations
- [ ] Performance optimization
- [ ] Edge case testing

### Requires Decision
- [ ] Can existing common patterns be reused (02_decision-criteria/abstraction.md)
- [ ] Is introducing new technology/libraries needed (02_decision-criteria/technology-selection.md)

## Output Format

### Design Document

#### Overview
{Explain the purpose of the feature in 1-2 sentences}

#### File Structure
{List of files to create or modify}

#### Data Flow
{Flow from user action → service → database}

#### Security
{Authentication, authorization, and validation design}

#### Error Handling
{Possible errors and how to handle them}

#### Test Plan
{Test targets and types}

#### Open Items
{Points that cannot be decided at the design stage}
```
