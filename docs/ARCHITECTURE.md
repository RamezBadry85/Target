# Architecture decisions

## Scope and dependency rule

Phase 1 is the application shell, not a sales engine. Each feature owns
`presentation`, `domain`, and `data` boundaries. Domain/data folders currently hold
boundary guidance rather than invented entities or nonfunctional repositories.
Add executable domain contracts only when the corresponding workflows are agreed.

Dependency direction for future work:

```text
presentation -> domain <- data
                    ^
            app composition root
```

- Domain: pure Dart entities, value objects, use cases and repository interfaces.
  No Flutter, persistence, networking or presentation imports.
- Data: serialization models, local/remote sources and repository implementations.
  Convert external exceptions into domain-safe failures.
- Presentation: feature pages and future controllers; never call storage or cloud
  clients directly. Shared UI belongs in core only when actually reused.
- App: composes dependencies and shell navigation; not a business service layer.
- Core: small shared technical policies, failure codes, themes and localized copy.
  Do not grow it into a miscellaneous feature/business-logic directory.

## State and navigation

Flutter `StatefulWidget` is sufficient for session locale and selected module.
No operational state is stored in widgets. Future feature controllers receive
use cases through constructors. A state-management library can be introduced
behind feature presentation boundaries if complexity warrants it.

Stable destination IDs decouple labels from selection. The Phase 1 shell uses
in-app selection, not URL routes: deep links and browser history are deferred.
Pages are constructed cheaply on rebuild; only the active page is mounted.
Do not add persistence or network calls to page constructors/build methods.

## Local storage and future synchronization

No persistence technology or backend provider is selected. Before selecting one:

1. Define customer identity, currencies, amount rounding, dates/time zones,
   validation, deletion rules and migration requirements.
2. Put repository contracts and synchronization-independent use cases in domain.
3. Implement a transactional local source and test migrations on all target hosts.
4. Use stable IDs, schema versions and an explicit synchronization metadata strategy.
   Consider a transactional outbox, retry/backoff, tombstones and idempotent writes.
5. Specify conflict detection/resolution and recovery before adding a cloud adapter.
   Keep transport credentials outside domain entities and logs.

Prepare for future multi-user operation through repository/query contracts and
explicit actor/ownership context once identity requirements exist. Do not assume
a global mutable current user or treat the single-user UI as an authorization
boundary. Add real authorization at the service/storage boundary in that phase.

## Design and localization

Material 3, navy `#142D4E`, white surfaces and a light neutral workspace provide a
centralized visual baseline. Theme entries establish form/table defaults without
pretending those business forms exist yet. Reusable spacing and empty states
avoid divergent feature styling.

Arabic is explicit at startup. SDK localization delegates supply Material,
Cupertino and widget translations, text direction and localized controls.
Application strings are centralized in one delegate; migrate to generated ARB
localizations as the copy expands. No remote fonts are downloaded. Flutter's
platform font fallback is used; Arabic typography needs native-device review.

Layout follows directionality rather than hardcoded left/right placement. A
scrollable sidebar starts at 1100 logical pixels; tablet/mobile use a drawer.
Content is vertically scrollable for compact landscape and enlarged text. No
fabricated dashboard KPIs or disabled pretend CRUD actions are presented.

## Failures, logging and privacy

`AppFailure` carries a safe failure classification. Future use cases/repositories
must define their result/exception policy consistently, with localized messages
in presentation. This phase installs framework and unhandled asynchronous error
hooks, backed by `dart:developer`. No telemetry/crash service is integrated.
Never place sales records, balances, customer details, tokens or database payloads
in logs. Global logging is a last-resort diagnostic, not business error recovery.

## Explicitly deferred

Customers CRUD, sales/quotation calculations and approvals, opportunities,
follow-up reminders, targets, collections, analytics, Excel/PDF, database,
synchronization, authentication, permissions, backups and installers.
Inventory and warehouse management remain outside the initial product scope.
