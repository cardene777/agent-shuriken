# Checks

The ikkan gates read this file.
The implementation step's gate runs the reached checks after the command the test step recorded, so the repository checks run for every issue.
They also run every plugin test that reads a root file the branch changed, since such a test can break without a change to its own plugin.

| Field | Value |
|---|---|
| Reached checks | `bash scripts/reached-checks.sh` |
