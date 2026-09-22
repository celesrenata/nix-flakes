# Portable Installer

Boot a current NixOS installer ISO, clone this repository, and run:

```bash
sudo ./installer/install-portable.sh
```

The script ranks whole disks with SSD/NVMe ahead of HDDs, prompts for the
hostname, primary username, and password, lets you choose a feature set, and
requires the exact `WIPE /dev/...` confirmation before it partitions anything.
It creates an EFI system partition and a Btrfs root filesystem, generates
hardware configuration after mounting them, and installs the `.#portable`
target.

The portable target deliberately excludes remote builders, SOPS, vLLM, Arcane,
Hyte, and esnixi-specific services. Ollama is an optional local-only service.
