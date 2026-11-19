# Architecture

Two diagrams. The design picture is the reference. The Mermaid in the README is the live map. If a name disagrees, the Terraform files win.

The design canvas is [Terraform from GitHub to Azure](https://claude.ai/artifact/GoQPZAggwkNXoW3t5sdptY). Export `architecture.png` and `architecture.pdf` into this folder without the "Made with Claude Design" mark. Claude's file exports do not carry it.

The picture is the first-pass map (files on 26 October 2026). Solid boxes are the design. The yellow “Where this stands” box is that day's note, when teardown was still open; teardown finished the same day. Live Azure matches this picture only while `az group exists` prints `true` for `rg-tfpipe-state-zeon01` and `rg-tfpipe-poc-zeon01`. The Mermaid in the README is the live map of the files. If a name disagrees, the Terraform files win. Claude can redraw the yellow box after a rebuild.
