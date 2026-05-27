rubin-stoker is a profile plugin for the [Stoker](https://github.com/jsickcodes/stoker) agentic engineering harness.
This profile captures the workflow defaults for Rubin Observatory work, such as in the https://github.com/lsst-sqre GitHub organization.

## Rubin Observatory-specific workflow considerations

### Jira integration

Work starts with Jira tickets, and we use Jira tickets as a central communication touch point for high-level stakeholders.
We use the Atlassian instance hosted at https://rubinobs.atlassian.net/jira/.
Our Jira tickets typically have `DM-` prefixes (e.g., `DM-12345`).

When creating a PRD, we'll pass in a reference to the Jira ticket. The `/stoker-prd` skill should use the Jira ticket description as the seed for the PRD, in addition to any additional context that the user provides. Jira ticket descriptions as high-level, so a PRD needs to translate  tickets into technical and actionable designs.

When we create the PRD and create implementation tasks we want to post comments to the Jira ticket to keep stakeholders updated with out progress.

Our preference is to use the Atlassian MCP server for interacting with Jira. The user should configure this MCP server.

### Git branch naming

Work should always be done on a branch, never on the default branch (typically `main`).
When doing work associated with a Jira ticket, the branch name should have a `tickets/` prefix followed by the ticket (e.g., `tickets/DM-12345`).
If there's only one Git branch for a Jira ticket, you can just use that branch name.
But if there are multiple Git branches for a Jira ticket, then add a short description suffix that's dash separated (e.g., `tickets/DM-12345-feature-a` and `tickets/DM-12345-feature-b`).

### Working without a Jira ticket

Some PRDs are small, and can be created without a Jira ticket. In that case, the Git branch template is `u/<username>/<description>` where `<username>` is the user's GitHub username.
For example, `u/jonathansick/docs-fix`.
