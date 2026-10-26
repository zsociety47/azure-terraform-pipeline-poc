# Architecture

Two diagrams. The design picture is the reference. The Mermaid in the README is the live map. If a name disagrees, the Terraform files win.

The design canvas is [Terraform from GitHub to Azure](https://claude.ai/artifact/GoQPZAggwkNXoW3t5sdptY). Export `architecture.png` and `architecture.pdf` into this folder without the "Made with Claude Design" mark. Claude's file exports do not carry it.

The laptop already created `rg-tfpipe-state-zeon01`, `sttfpipezeon01`, `rg-tfpipe-poc-zeon01`, and the Entra app `github-actions-azure-terraform-pipeline-poc`. The pull-request plan job is in the repository. The apply job is not. On the picture, a solid line means Terraform, a dashed line means the portal or a runner, and a dotted line means not written yet.
