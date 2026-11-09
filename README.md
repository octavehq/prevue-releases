# PRevue

PRevue is a desktop app for reviewing pull requests. Each PR can have a Review Brief: what changed, what it touches and what needs your eyes, with every claim linked to the code. You read the brief before the diff, comment and approve from the app, and everything lands on GitHub.

This repository holds the macOS installer and releases. Apple Silicon Macs (M1 or later).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/octavehq/prevue-releases/main/install.sh | sh
```

The script downloads the latest release, copies `PRevue.app` into `/Applications` (or `~/Applications` if you can't write there) and opens it. Run the same command to update.

The app isn't signed with an Apple Developer ID yet. Installed this way it opens normally. If you download the DMG from the Releases page in a browser instead, drag PRevue into Applications and run this once before opening it:

```bash
xattr -dr com.apple.quarantine /Applications/PRevue.app
```

## Sign in

PRevue uses your GitHub CLI login and never stores a token itself:

```bash
brew install gh
```

```bash
gh auth login
```

```bash
gh auth refresh -s notifications
```

If your org uses SAML single sign-on, `gh` asks you to authorize the token for it the first time.

## Generate a brief

PRs without a brief show a **Generate brief** button. It writes the brief on your Mac with your own Claude Code, so you need:

- [Claude Code](https://code.claude.com/docs/en/setup) 2.1.38 or later, logged in once by running `claude`;
- git, which comes with Apple's command-line tools (`xcode-select --install` on a fresh Mac).

Everything else is built into the app. A brief takes a few minutes and runs on your own Claude seat. Briefs written automatically when a PR is opened are coming in a later release.

## Help

The guide opens on first launch and any time from **Help › PRevue Guide**, Settings, or ⌘K. Its setup step checks gh, git and Claude Code on your Mac and gives the command for anything missing. Press `?` in the app for every shortcut.

Briefs can miss bugs. Read the blockers and risky files yourself before you approve.

## Install options

Environment variables before `sh`:

- `PREVUE_VERSION=v0.1.0`: install that release instead of the latest.
- `PREVUE_INSTALL_DIR=~/Applications`: install somewhere else.
- `PREVUE_NO_OPEN=1`: don't open the app afterwards.
