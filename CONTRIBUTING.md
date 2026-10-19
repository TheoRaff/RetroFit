# TheoRaff: hackathon Git guide

Raff407 and theorook are equal organisation Owners. These are our shared working conventions; this guide does not configure GitHub to enforce them.

**Our routine:** pick a task -> create a branch -> commit and push -> open a pull request -> teammate reviews -> merge -> both update.

## 1. Ground rules

- Keep `main` working and ready to demo. Put feature work and fixes on task branches.
- Give each task one lead. Agree before editing the same files, shared configuration, or dependency lockfile.
- Use one branch per task: `feat/raff-login`, `feat/theo-dashboard`, `fix/theo-login-error`, or `docs/raff-setup`.
- Commit small, understandable changes. Push at useful checkpoints and before taking a break.
- Open a pull request (PR) into `main` and ask the other person for a quick review before merging.
- Use **Create a merge commit** when merging PRs to preserve the individual commits and authors.
- Use your own GitHub account and commit identity. Both people should commit their own work.
- Keep API keys, passwords, and real `.env` files local. Add placeholder settings to `.env.example` when needed.
- Add build output and dependency folders to `.gitignore` as the stack takes shape. Commit the package manifest and lockfile together when dependencies change.
- Avoid force pushes and history rewrites during the hackathon. If `main` breaks, agree on a fix or revert before merging more features.

## 2. Set up once on each laptop

Clone the repo while signed in to your own GitHub account:

```sh
git clone https://github.com/TheoRaff/TheoRaff.git
cd TheoRaff
```

Set your identity for this repo. Replace both example values with your own details; the email must be linked to your GitHub account. You can use the GitHub-provided no-reply email from your email settings.

```sh
git config user.name "Your name"
git config user.email "YOUR_GITHUB_COMMIT_EMAIL"
```

These commands set the identity recorded on commits; GitHub sign-in is separate. GitHub Desktop can perform the same clone, branch, commit, push, and PR workflow through buttons.

## 3. The everyday workflow

### Start a task

Create an issue with a clear goal, one owner, and a short description of what counts as finished. A simple task list can use **To do -> Doing -> Review -> Done**.

Run these commands from the repo folder after committing any current work on its task branch. If you have uncommitted work on `main`, create a task branch before committing it.

```sh
git status
git switch main
git pull --ff-only
git switch -c feat/raff-login
```

Use a new, descriptive branch name for your own task. `--ff-only` updates your local `main` without creating an accidental merge commit. If it refuses, inspect the local changes with your teammate before continuing.

### Save and share progress

Check your changes, then stage the files belonging to the task. Replace `path/to/changed-file` with the actual file paths.

```sh
git status
git diff
git add path/to/changed-file
git diff --staged
git commit -m "Add login form"
git push -u origin feat/raff-login
```

Use a message that says what changed, such as `Fix empty search results`. For later commits on this branch, repeat the review/add/commit steps and use `git push`.

### Review and merge

1. Open a PR on GitHub with **base: main** and **compare: your task branch**.
2. Fill in the existing PR template: what changed and how you checked it. Link the issue; add a screenshot for visible changes.
3. Ask your teammate to review. Check that the app starts, the changed behaviour works, and the changes belong to the task. Run relevant tests if the project has them.
4. Address feedback, push again, then merge using **Create a merge commit**.
5. Delete the merged branch on GitHub. Mark the issue done if it did not close automatically.

Both people then update their local copy before starting their next branch:

```sh
git switch main
git pull --ff-only
```

If you are midway through another task, keep working on its branch and use the next section to bring in the latest `main` when needed.

## 4. When changes overlap

Commit your current task work first so your working tree is clean. While on your task branch, bring in the latest shared work:

```sh
git fetch origin
git merge origin/main
```

If Git reports conflicts:

1. Run `git status` to find the affected files.
2. Resolve them together in your editor. Keep the intended behaviour from both changes and remove conflict markers such as `<<<<<<<`, `=======`, and `>>>>>>>`.
3. Check the app and any relevant tests again.
4. Stage each resolved file, finish the merge, and push:

```sh
git add path/to/resolved-file
git commit
git push
```

If you need to abandon an in-progress merge, `git merge --abort` returns to the state before it began. Start the merge with a clean working tree so this is straightforward.

## 5. Suggested project structure

Add folders as needed once you choose the stack; follow the framework's usual layout where it differs from this example.

```text
.github/          PR template and any later automation
src/              Application code, grouped by feature
tests/            Automated tests as they are introduced
docs/             Decisions, API notes, screenshots, demo notes
README.md         What it does, setup, run commands, demo link, both authors
CONTRIBUTING.md   This Git guide
.env.example      Placeholder environment settings, when needed
.gitignore        Local files and generated output to exclude
```

Keep the README current whenever setup or run commands change. Record decisions that affect both people in an issue or a short note in `docs/`.

## 6. Hackathon checklist

### At kickoff

- [ ] Check the event's rules on existing work, submissions, and repo visibility.
- [ ] Agree on the smallest useful demo and split the first tasks.
- [ ] Confirm both laptops can clone, create a branch, and push.
- [ ] Choose the stack and record exact setup and run commands.
- [ ] Agree the data or API format before building parts that connect.

### During the build

- [ ] Keep task status and blockers visible to each other.
- [ ] Integrate small pieces regularly instead of leaving integration to the end.
- [ ] After merging, check the main user journey still works.
- [ ] Push work before breaks and handovers; leave a note on unfinished work.

### In the final hour

- [ ] Pause large new features and focus on the complete demo journey.
- [ ] Test setup from a clean clone or on the other laptop.
- [ ] Merge the work intended for submission and tag the tested commit `demo-v1`.
- [ ] Finish the README with both names, contributions, setup, demo link, and limitations.
- [ ] Save the submission links and a backup demo recording or screenshots.
- [ ] Agree whether to make the repo public under the event rules. Once public, both can pin it to their profiles after contributing.

## References

- [GitHub flow](https://docs.github.com/en/get-started/using-github/github-flow)
- [Git pull and --ff-only](https://git-scm.com/docs/git-pull)
- [Resolving merge conflicts](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/resolving-a-merge-conflict-using-the-command-line)
- [Contribution credit on your profile](https://docs.github.com/en/account-and-profile/reference/profile-contributions-reference)
