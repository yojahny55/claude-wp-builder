- **`wp-config.mjs git-init` puts an adopted site's root under git in place.** Opt-in
  (`/wp-adopt` Step 6b): it refuses a root that is already, or sits inside, a repository,
  merges a WordPress `.gitignore` (template plus every tool state path) without duplicates,
  runs `git init -b <branch>`, adds the remote and prints a dry-run summary with large and
  secret-looking files before anything is staged. Commit and push are separate confirmed
  steps, and only the named branch is ever pushed, never a second one.
