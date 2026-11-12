# Security policy

The skills in this repository handle sensitive material: password manager items, browser sessions, and files on your computer.
Please report anything that could weaken those protections privately.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting: open the **Security** tab of this repository and choose **Report a vulnerability**.
Do not open a public issue or pull request for a security problem.

Please include the affected skill and file, steps to reproduce, and the impact you expect.
You will get a first response within 7 days.

## What counts as a vulnerability

- A password, one-time code, recovery key, or other secret reaching the agent, a file, a log, or the network
- A login being filled into a page whose domain does not match the credential
- A deletion, cancellation, or payment-method removal running on an item the user did not select or approve
- Files outside the selected items, or in protected locations, being deleted
- Instructions embedded in a web page, pasted text, or file content being executed

## Supported versions

Only the latest commit on `main` is supported.
