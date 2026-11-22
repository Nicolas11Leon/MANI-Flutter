# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

One visual language across Flutter web, Android and iOS; only layout and sizing adapt to screen width. Confirmed by the product owner (2026-11-10). Platform-native control styles per OS are explicitly out of scope.

## Users

Three primary roles, weighted equally (confirmed):

- **Client** (person or company): publishes service requests, compares quotes, follows execution, pays and rates. Mostly on a phone, occasionally.
- **Ally** (independent technician or service company): declares coverage, categories and availability, receives and accepts requests, quotes, executes and logs work. Phone-first, often in the field.
- **Tenant admin**: verifies allies (KYC), manages the category catalog, tariffs, operating rules, complaints and metrics. Desk and laptop, during the working day.

A platform admin manages tenants and can act inside a tenant's context.

## Product Purpose

MANI is a multi-tenant SaaS that formalizes service operations that today run informally over calls and messaging. It carries every service through one traceable lifecycle: request → quote → execution → rating → close. Success means each tenant can verify allies, standardize tariffs, control dispatch and audit the operation without leaving the platform.

## Positioning

Each tenant (company) runs its own isolated operation with its own rules, configured rather than custom-built. Dispatch guarantees that a request ends with exactly one valid assignment: if two allies accept at once, one gets a clear "already taken" (HTTP 409) answer.

## Operating Context

- Coverage is by zones and neighborhoods; there is no live GPS tracking or radius search in the MVP.
- Allies upload KYC documents; admins approve or reject them with a mandatory reason.
- Quotes can receive additions for unforeseen work; the payable total is the accepted quote plus accepted additions.
- Ratings are bidirectional and closing a service depends on them; late cancellation carries a penalty.
- Client-ally messaging is per request; a notification inbox covers platform events.

## Capabilities and Constraints

- Client: Flutter (web and mobile), presentation layer only. All APIs go through the API Gateway (`/api/v1/core`, `/rules`, `/dispatch`); no direct service ports.
- State: flutter_bloc / Cubit with domain / data / presentation layers.
- Language of the UI: Spanish (Colombia). Currency COP.
- Second increment (payments, complaints, metrics) is partially built; payment runs against a sandbox.
- Existing copy, widget keys and routes are a test contract (about 1,100 widget and integration tests assert on them).

## Brand Commitments

- Name: MANI. Logotype: the letter "M" on a brand-color square with a hard offset shadow.
- Identity: neo-brutalist, taken from the official Figma prototypes: thick charcoal borders, hard offset shadows without blur, Plus Jakarta Sans. The product owner chose to **refine and keep** this identity (2026-11-10).
- Brand color: **#F8DE7E** (replaces the former #FACC15), pinned by the product owner on 2026-11-10.

## Evidence on Hand

- Product documentation: `MANI-docs` (README, `wiki/01-producto`, SRS, backlog).
- No customer testimonials, metrics, client logos or pricing exist; none may be invented in the UI.

## Product Principles

1. Traceability first: every state of a service is visible and reconstructable by the people involved.
2. One clear next action per screen for the role in front of it.
3. Tenant isolation is visible: users always know which company context they act in.
4. Configurable, not custom: differences between tenants appear as data and rules, not separate screens.

## Accessibility & Inclusion

WCAG 2.2 AA is the required standard (workspace `UI_DESIGN_WORKFLOW_GUIDELINES.md`): text contrast at least 4.5:1, UI and focus indicators at least 3:1, full keyboard use on web, touch targets at least 44 px on mobile, reduced motion honored.
