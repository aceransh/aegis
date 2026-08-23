# Aegis Sprint Plan — Phase 2 (Infra) + Phase 3 (AI SRE Agent)

**How to use this file (for future Claude Code sessions and for the user):** this is the
active roadmap for finishing the project. Check items off as they're completed. Before
starting work in a new session, read the "Status" line below and the most recent unchecked
day to know exactly where things left off. This file follows the same **Struggle Method**
rules as the rest of the project (see `CLAUDE.md`) — it tracks *what* needs to happen, not
*how to code it*; guidance still gets given one small step at a time, not as finished blocks.

**Status: Day 2 complete. Starting Day 3 (ECS compute, part 2).**

**On the timeline:** originally scoped at 15 days; extended to **20** once Phase 3 turned out
to need a real design step this plan was initially missing — how broker error data actually
becomes a CloudWatch-alarmable metric, and how failures get reliably injected against the
*deployed* infra (not just localhost) to prove the whole pipeline fires. Phase 2 (Days 1-11)
didn't need the extra room and is unchanged; all 5 extra days went to Phase 3. Even at 20,
treat this as a target, not a hard deadline — if it still runs long, that's fine per the same
reasoning as before: don't compress real scope just to hit a date.

---

## Day 1 — Finish the networking module (Layer 2)
- [x] VPC (`aws_vpc.main`, `10.0.0.0/16`)
- [x] Public subnet (`us-east-1a`) + private subnet (`us-east-1b`)
- [x] Internet Gateway, attached to the VPC
- [x] Public route table (`0.0.0.0/0 → igw`) + association to the public subnet
- [x] Security group for the Fargate compute (broker/worker) — ingress on the broker's port
      from `0.0.0.0/0` (no ALB in this tier), egress open
- [x] Security group for RDS — ingress on `5432` scoped **only** to the compute security
      group, never `0.0.0.0/0`
- [x] `variables.tf` / `outputs.tf` for the networking module (expose VPC ID, both subnet
      IDs, both security group IDs — whatever `environments/cost/` will need to consume)
- [x] Wire the module into `environments/cost/main.tf` via a `module "networking" { source =
      "../../modules/networking" ... }` block — not yet called anywhere
- [x] `terraform plan` / `apply` from `environments/cost/`, confirm the VPC and both subnets
      actually exist in the console

## Day 2 — Layer 3: ECS compute, part 1
- [x] ECS cluster resource
- [x] Task execution role (pulls the image, ships logs) vs. task role (app's own AWS
      permissions, if any) — understand the distinction before writing either. Decided: no
      task role needed — broker/worker's Go code makes no direct AWS API calls, only an
      execution role was built.
- [x] Task definition for the broker (container image source, CPU/memory sizing, port
      mapping, environment variables placeholder for `DB_DSN`) — `image` left as an explicit
      placeholder (`"idk"`), same treatment as `DB_DSN`, to be replaced once Day 3 actually
      builds and pushes the image to ECR. Also flagged for Day 3: Mac (Apple Silicon) Docker
      builds default to ARM64 — either build with `--platform linux/amd64` or add
      `runtime_platform { cpu_architecture = "ARM64" }` to match, or the task will fail on an
      architecture mismatch.

## Day 3 — Layer 3: ECS compute, part 2
- [ ] Task definition for the worker (mirrors broker's shape, `BROKER_URL` placeholder)
- [ ] ECS service for each — `desired_count`, `assign_public_ip = true`, correct subnet +
      security group references from the Day 1 module outputs
- [ ] Push broker/worker images to ECR (or confirm existing Dockerfile/build path works for
      this) — first real integration point between the Go app and the infra

## Day 4 — Layer 3 verification and catch-up
- [ ] `terraform apply` from `environments/cost/`, confirm both ECS services reach RUNNING
- [ ] `aws ecs describe-tasks` to find the broker's ephemeral public IP
- [ ] Natural spillover slot if Day 2-3 ran long — ECS + IAM roles usually take longer than
      expected the first time

## Day 5 — Layer 4: stable addressing
- [ ] Decide and implement the answer to "how do you reach the broker's IP each session"
      (ephemeral lookup via `aws ecs describe-tasks`, EIP-on-ENI, or Route53 — this was left
      open, still open)
- [ ] `curl` the broker's `/health` endpoint from the actual public internet, not just from
      inside AWS — first real end-to-end proof this tier works

## Day 6-7 — Layer 5: RDS
- [ ] Verify actual free-tier eligibility in Billing → Free Tier (account is ~2 years old per
      earlier evidence — expect not eligible, budget accordingly)
- [ ] `aws_db_subnet_group` spanning the private subnet **and** a second private subnet in a
      different AZ (RDS requires 2+ AZs for the subnet group even for a single-AZ instance —
      you only have one private subnet so far, this means adding a second)
- [ ] `aws_db_instance`, single-AZ, `skip_final_snapshot = true` (required for `destroy` to
      actually work under the spin-up-on-demand posture, or `apply`/`destroy` cycles will
      fail waiting on a snapshot name)
- [ ] Confirm RDS is unreachable from the public internet, reachable from the broker/worker
      security group only

## Day 8 — Layer 6: wiring app config to infra
- [ ] Terraform outputs (RDS endpoint, etc.) feeding into the ECS task definitions'
      environment variables for `DB_DSN` and `BROKER_URL`
- [ ] Decide DB password handling — `sensitive = true` at minimum; consider Secrets
      Manager/SSM `SecureString` vs. a plain Terraform variable, and know where the password
      actually ends up either way (state file, task definition JSON) before deciding

## Day 9 — First full end-to-end cost-tier verification
- [ ] `terraform apply` from a clean slate, confirm broker + worker + RDS all come up
- [ ] Run the existing `./scripts/enqueue_spam.sh` / `./scripts/worker_loop.sh` harness
      against the real deployed broker, not just localhost — first real proof the whole
      distributed system behaves correctly on real infrastructure
- [ ] `terraform destroy`, confirm it tears down cleanly (this is the actual test of the
      `skip_final_snapshot` decision from Day 6-7)

## Day 10 — Layer 7: production tier (written, never applied)
- [ ] Decide NAT Gateway vs. VPC PrivateLink for the private subnet's egress — this is the
      one still-open architectural question from earlier sessions, pick one and be able to
      defend it
- [ ] ALB + target group wiring for the private-subnet Fargate service
- [ ] RDS Multi-AZ toggle (tier-conditional, same module, different variable value)
- [ ] `terraform plan -var-file=production.tfvars` (or equivalent), confirm it produces a
      materially different, larger plan than the cost tier — and confirm it stays
      `plan`-only, never `apply`

## Day 11 — Bearer token auth on the broker API
- [ ] Add bearer token authentication to the broker's HTTP handlers — this was identified
      early in the infra work as the real mitigation for having no ALB/WAF in the cost tier,
      deliberately deferred until infra was done. It's here now.
- [ ] Update `./scripts/enqueue_spam.sh` / `./scripts/worker_loop.sh` to send the token
- [ ] Re-verify the real deployed cost tier still works end-to-end with auth on

## Day 12 — Phase 3: the CloudWatch metrics bridge (new, previously missing)
- [ ] Decide how broker error data actually becomes a metric CloudWatch can alarm on —
      Prometheus counters (`task_queue_jobs_failed_total`, etc.) don't automatically appear
      in CloudWatch. Real options to weigh: publish a custom metric via `PutMetricData`
      directly from the broker, a CloudWatch Logs metric filter parsing structured log lines,
      or leaning on ECS Container Insights. Pick one and understand why the others don't fit.
- [ ] Implement whichever path is chosen, confirm the metric actually populates in CloudWatch
      under real (even zero-error) traffic before worrying about the alarm threshold itself

## Day 13 — CloudWatch Alarm + Lambda scaffold
- [ ] CloudWatch Alarm on the metric from Day 12 (>5% threshold, per the README's target
      design)
- [ ] Lambda function scaffold — runtime choice, handler shape, how it receives the alarm
      event
- [ ] IAM role for the Lambda (what does it actually need: read CloudWatch, invoke Bedrock,
      reach Secrets Manager for the GitHub token/Slack webhook — scope it to those, not admin)
- [ ] Secrets handling for the GitHub token and Slack webhook URL (Secrets Manager or SSM
      `SecureString` — same class of decision as Day 8's DB password, applied here)

## Day 14-15 — Phase 3: GitHub + Bedrock integration
- [ ] Lambda calls the GitHub API to fetch the relevant commit diff
- [ ] Lambda calls Amazon Bedrock with that diff for root-cause analysis
- [ ] Error handling for both external calls — what happens if GitHub or Bedrock is
      unreachable or rate-limits the request; this is real application code, treat failure
      paths as seriously as the Go broker/worker's own error handling was treated

## Day 16-17 — Phase 3: Slack + human-in-the-loop rollback
- [ ] Lambda posts the incident brief (RCA + commit context) to Slack via webhook
- [ ] Design the actual approval mechanism, not just the notification — a Slack message
      alone isn't an approval flow. Concretely: does approving require a Slack interactive
      button hitting back through API Gateway → Lambda, or a simpler manual step (approver
      clicks a link to a GitHub Actions workflow_dispatch)? Pick one and know why it's
      simpler/more reliable than the alternative for a solo-maintained project.
- [ ] Wire the approved action through to a real GitHub operation (revert PR, workflow
      dispatch, etc.)

## Day 18 — Failure injection design
- [ ] Figure out how to reliably drive the broker's error rate above the Day 13 alarm
      threshold against the *deployed* AWS infra, not just localhost — the existing
      `./scripts/enqueue_spam.sh` / `./scripts/worker_loop.sh` exercise queue-level failure
      paths (lease expiry, retries, DLQ), which isn't the same thing as tripping an HTTP
      error-rate alarm. Decide what actually needs to change: point the existing scripts at
      the deployed broker's address, add a deliberate failure mode if the current ones don't
      produce enough 5xx/error signal, or both.
- [ ] Confirm the scripts send the bearer token from Day 11 — deployed broker requires auth
      now, unlike when these scripts were first written

## Day 19 — Fire-drill test
- [ ] Run the actual end-to-end fire drill against deployed infra: inject failures → error
      metric crosses threshold → alarm fires → Lambda runs → GitHub commit fetch → Bedrock
      RCA → Slack post → approval → rollback action lands
- [ ] Fix whatever breaks in that chain — expect something to, first time through a chain
      this long

## Day 20 — Docs and close-out
- [ ] README's architecture diagrams match final reality for both tiers and both phases
- [ ] `docs/LEARNINGS.md` gets an entry for the infra + AI SRE phases, same day-by-day
      rationale style as the existing Phase 1 entries
- [ ] Draft the actual resume bullets this whole build was scoped around (two-tier Terraform
      design, scale-to-zero FinOps pattern, and now the AI SRE agent pipeline) while the
      reasoning is fresh
- [ ] Cost check-in against the Layer 0 budget alarm — confirm real spend matched estimates
      across the whole build, not just the first `apply`
- [ ] If Days 12-19 ran long (see the note at the top of this file), this is the natural
      spillover point; let it extend rather than cutting real scope

---

## Explicitly out of scope for this project (decided earlier, don't relitigate without a
## reason)
- S3 remote state / DynamoDB locking — solo laptop, no CI/CD, local state's built-in locking
  already covers the actual risk
- CI/CD pipeline — would dilute the resume story rather than add to it, and fights the
  spin-up-on-demand posture
- Hand-scoped least-privilege IAM beyond what already exists (the `ansh` → `aegis-admin-role`
  assume-role pattern) — `AdministratorAccess` on the role itself is a deliberate,
  reasoned choice for a personal sandbox account
