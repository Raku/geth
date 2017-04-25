# geth
GitHub Push Updates to IRC Bot


# Commit Filters

To add commit filters stick a `.pm6` file into `commit-filters/`
and make it contain 1 sub that takes 1 arg with a name.

- Return undefined value to signal that filter did not match
- Return a false value to stop further processing of the
    event and do not send any response to IRC
- Return string to send to IRC to send it
