# Architecture

Two diagrams. The design picture is the reference. The Mermaid in the README is the live map. If a name disagrees, the Terraform files win.

The design canvas is [Terraform from GitHub to Azure](https://claude.ai/artifact/GoQPZAggwkNXoW3t5sdptY). Export `architecture.png` and `architecture.pdf` into this folder without the "Made with Claude Design" mark. Claude's file exports do not carry it.

Both groups, the state account, the app registration, two federated credentials, the GitHub roles, remote state, both jobs, and `verify.sh` are built. Apply on `main` created `sttfpipepoczeon01`. On the picture, a solid box means built and working. Teardown and a branch rule that requires the plan check are still open.
