# gwt

Git worktree wrapper with auto-setup for zsh.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/1noilimrev/gwt/main/install.sh | sh
```

## Commands

```bash
gwt add <branch>        # Create worktree (auto-links .env, node_modules, .venv)
gwt ls                  # List all worktrees
gwt cd <branch>         # Navigate to worktree
gwt rm <branch>         # Remove worktree
gwt rm -s               # Remove current worktree (returns to git root)
gwt rm -a [-f]          # Remove all worktrees
gwt rm -m <branch>      # Merge into main, then remove
gwt path <branch>       # Print worktree path
gwt claude <branch>     # Run claude in worktree
gwt opencode <branch>   # Run opencode in worktree
```

## Notes

- Worktrees are created in `.git/worktree-workspace/`
- Branch `/` converted to `-` in directory names (`feature/foo` → `feature-foo`)
- Auto-links `.env`, `node_modules`, `.venv`, `.claude` from main repo
- Use `-- args` to pass extra arguments to AI tools
- Set `GWT_CLAUDE_ARGS` or `GWT_OPENCODE_ARGS` for default arguments

## Testing

```bash
./test_gwt.zsh      # Run all tests
./test_gwt.zsh -v   # Run with verbose output
```

## License

MIT
