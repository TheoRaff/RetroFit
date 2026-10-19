# TheoRaff

Our shared hackathon project.

## Working together

Read [our hackathon Git guide](CONTRIBUTING.md) for branch names, copyable commands, review rules, conflict recovery, project structure, and kickoff and demo checklists.

1. Update your local copy from `main` before starting a task.
2. Create a branch for your change, such as `add-homepage` or `fix-login`.
3. Commit and push your changes, then open a pull request into `main`.
4. Ask your teammate for a quick review, merge, and update both local copies.

Keep `main` ready to demo. Use issues to divide up tasks and coordinate when editing the same files.

## Project notes

Add the project idea, setup instructions, and demo link here as the build takes shape.

Keep passwords and API keys out of the repository. Use local environment files and share an `.env.example` containing placeholder values when needed.

## Repository automation

- [Repository checks](.github/workflows/repository-checks.yml) run on pull requests into `main`, pushes to `main`, and manual runs. They check required documentation, local Markdown file links, merge-conflict markers in Markdown, and accidentally committed environment files. Add application build and test steps when the stack is chosen.
- [Issue assignment](.github/workflows/assign-issues.yml) assigns a new unassigned issue to its author when opened by Raff407 or theorook. Existing assignments stay unchanged; issues from other authors are left for manual triage.
- A review rule for `main` is saved. GitHub currently labels it **Not enforced** because the repo is private on the Free organisation plan. Follow the review agreement in the Git guide; enforcement requires a supported plan or a public repository.
