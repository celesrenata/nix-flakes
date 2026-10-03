# Independent work and visible task progress

Preserve the selected mode/profile. Implementation uses code routes; architecture,
planning and long-context work use planner/long routes; focused checks use tester/fast.

Batch independent discovery reads in one assistant response. Once the paths and
arguments are known, issue all needed independent read_file calls together (up to
eight), in one response; brief commentary may appear between them because the executor batches those reads. Apply the same
rule to independent list_files, search_files, codebase_search and read_command_output
calls. Do not spend a separate model turn on each already-known file or arbitrarily
split a known read set into pairs. Prefer focused ranges when those answer the question.
Wait for results when a later call needs an earlier result, before edits/commands,
or before choosing new search paths. Generic "one at a time" guidance applies to
those dependencies, not to independent reads. Collect the whole read batch before
drawing conclusions or integrating changes.

Before delegating a substantial feature, identify independent ready scopes with
separate file ownership. When at least two exist and native parallel_tasks is
available, dispatch 2–3 together with clear scope, acceptance criteria and initial
todos. new_task transfers control to one child while its parent waits; putting
the entire feature in one code subtask does not provide concurrency. Do not wrap
independent implementation, UI and review work in one large serial child. Give
each worker its outstanding repairs instead of finishing those repairs in the
coordinator before dispatch. Workers have
repository tools in isolated worktrees. Review returned patches and integrate in
one code task. Keep dependencies and final integration sequential with new_task.
Use mixed modes only when appropriate to the work; do not turn code work into
long-context work just to move it to another GPU. Gateway host caps remain in force.

Use update_todo_list in each substantial task so the chat header and Zoo Task Board
show current work. Include stable task IDs and spec paths when using Spec Orchestrator.
Open the Command Palette's "Zoo: Show Task Board" for all open chats in this window;
"Zoo: Export Task Board JSON" and omniroute-workers.list_zoo_chats expose progress.

If native parallel_tasks is unavailable or work needs only inference proposals,
omniroute-workers.start_parallel_tasks can still distribute explicit context across
code (5090), fast (4070 Ti Super) and long (M5 Max). Those MCP workers cannot read
files or execute tools. Collect all results before applying proposals. The MCP
fallback has two 5090 slots, one 4070 slot, and one M5 slot with no cloud fallback.

Independent source research or acceptance/spec audits use `project-research`, mapped to `OmniRoute-Local-Long` on the M5 Max. Bounded, read-only file gathering uses `project-reader`, mapped to `OmniRoute-Local-M5-Reader` on the M5 Max small Qwen3.5 model with reasoning effort `none`. It co-resides with GLM, so routine reads no longer occupy Ornith's one slot. Dispatch reader, Code, and long workers together when their scopes are independent. Keep implementation in Code with high reasoning effort on hybrid/code so independent workers can use eligible 5090, 4070 Ti Super, and M5 Max targets. Keep broad synthesis on the warm M5 GLM model. A later live integration test does not block disjoint implementation against the written contract.
