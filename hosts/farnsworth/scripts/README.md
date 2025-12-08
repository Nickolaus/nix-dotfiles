# Farnsworth Scripts

Helper scripts for the **farnsworth** NixOS configuration.

## Scripts

- **[vm-test-setup.sh](./vm-test-setup.sh)** - Automated VM testing setup
  - Downloads NixOS ISO for testing
  - Checks for UTM installation
  - Prepares VM testing environment

## Usage

All scripts are designed to be run from the repository root:

```bash
# VM testing setup
./hosts/farnsworth/scripts/vm-test-setup.sh
```

For detailed instructions, see the [documentation](../docs/).
