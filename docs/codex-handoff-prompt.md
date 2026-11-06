# Suggested Codex Handoff Prompt

Read `AGENTS.md` and the project documentation it requires for the task.

The repository is a customized Quickshell shell already used daily. Treat v1.2.0 as the documented stable baseline and check the current QML before relying on version notes.

Your priorities are:

1. preserve stable subsystems;
2. make only task-scoped changes;
3. avoid regressions;
4. preserve current visual language;
5. validate QML/Python carefully;
6. never reintroduce the removed `config/bar.json` architecture;
7. keep Network after Tray;
8. preserve the active native NotificationServer and its toast, history, and DND behavior.

Before coding, summarize:
- what files are relevant;
- what behavior is currently stable;
- what you plan to modify;
- what you will intentionally not modify.

After coding, report:
- exact files changed;
- validation performed;
- any unresolved risks;
- whether the user-facing visual layout changed.
