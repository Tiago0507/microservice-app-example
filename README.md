#1. Branching Strategy

Below is a clear branching strategy for both team roles.

##1.1 Developers – GitHub Flow (2.5%)

The development team uses GitHub Flow for small and frequent changes with `main` always deployable.

- main is always deployable; small and frequent changes.
- short-lived branches off main: feature/<topic>, fix/<bug>, chore/<task>, hotfix/<incident>.
- open a PR to main with mandatory review; CI must be green before merge.
- merging to main triggers CD to the target environment.
- hotfix: prioritized, quick validation, merge to main and immediate deploy.

Guards: required CI checks, branch protection on main, and required approvals.

Rationale: simplicity, agility, and short recovery times.

##1.2 Operations – GitHub Flow (2.5%)

The operations team also uses GitHub Flow for operational changes and continuous delivery.

- main is always deployable; small and frequent changes.
- short-lived branches off main: fix/<topic>, chore/<task>, hotfix/<incident>.
- PR to main with review; merging triggers CD to the target environment.
- hotfix: prioritized, quick validation, merge to main and immediate deploy.

Guards: required CI checks, branch protection on main, and required approvals.

Rationale: simplicity, agility, and short recovery times aligned with availability goals.