# Standard tag contract (see standards/NAMING-STANDARD.md):
# lifetime, owner, project, created.
# The state group is kept (lifetime=keep) so the nightly delete never removes
# the state file. The pipeline group is deleted nightly (lifetime=1d).

locals {
  created = formatdate("YYYY-MM-DD'T'hh:mm:ss'Z'", timestamp())

  state_tags    = merge(var.tags, { lifetime = "keep", created = local.created })
  pipeline_tags = merge(var.tags, { lifetime = "1d", created = local.created })
}
