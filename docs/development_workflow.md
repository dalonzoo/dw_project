# Development Workflow

The goal is to keep every project step understandable and demo-ready.

## Milestone Rhythm

For each milestone, we will use this loop:

1. Define the small outcome.
2. Make the files or database changes.
3. Run a verification command or SQL check.
4. Review the Git diff.
5. Commit.
6. Push when the milestone is stable.

## Useful Git Commands

Check what changed:

```powershell
git status --short
git diff
```

Stage a focused set of files:

```powershell
git add README.md .gitignore requirements.txt .env.example docs sql scripts diagrams reports data_raw data_processed
```

Commit:

```powershell
git commit -m "Set up project structure and database bootstrap"
```

Push:

```powershell
git push origin main
```

## Commit Style

Use small messages that explain the milestone:

- `Set up project structure and database bootstrap`
- `Add Citi Bike source acquisition script`
- `Create staging schema and trip load checks`
- `Build reconciled station geography layer`
- `Add warehouse dimensions and fact tables`
- `Add OLAP demo queries`

## Presentation Control

Each technical milestone should produce something visible:

- A script in the repository
- A SQL file that can be opened in DBeaver
- A table or schema visible in PostgreSQL
- A row-count or quality check
- A diagram or query result used later in slides

This makes the final presentation easier because we can show the development path, not only the final result.
