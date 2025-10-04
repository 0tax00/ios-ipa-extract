# iOS IPA Extraction Tool

This tool provides a streamlined method to extract iOS applications from jailbroken devices via SSH, package them into IPA format, and download them to your local system.

## Features

- **Automated Application Discovery**: Automatically locates applications by name fragment
- **SSH Integration**: Secure extraction via SSH with configurable credentials

## Requirements

### System Requirements
- Linux/macOS/Unix system
- `sshpass` utility installed

### Target Device Requirements
- Jailbroken iOS device
- SSH service enabled
- Root access available
- Applications installed in standard locations

## Installation

### Install Dependencies

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install sshpass
```

**macOS (using Homebrew):**
```bash
brew install hudochenkov/sshpass/sshpass
```

**Alternative - SSH Key Authentication:**
If you prefer SSH key authentication over password-based authentication, configure SSH keys and modify the script accordingly.

### Download Script
```bash
# Make the script executable
chmod +x ipa-extract.sh
```

## Usage

### Basic Syntax
```bash
./ipa-extract.sh <IP_ADDRESS> <APP_NAME_FRAGMENT> <OUTPUT_FILENAME.ipa>
```

### Parameters
- `IP_ADDRESS`: Target iOS device IP address
- `APP_NAME_FRAGMENT`: Partial application name to search for (case-insensitive)
- `OUTPUT_FILENAME.ipa`: Desired output IPA filename (must have .ipa extension)

### Examples

**Extract a specific application:**
```bash
./ipa-extract.sh 10.0.0.38 "MyApp" myapp.ipa
```

### Help
```bash
./ipa-extract.sh
```
Shows detailed usage information and examples.

## Configuration

### Default Settings
The script uses the following default configuration:
- **SSH User**: `root`
- **SSH Password**: `alpine` (default iOS jailbreak password)

### Customization
To modify default settings, edit the configuration section at the top of the script:

```bash
# Configuration
readonly SSH_USER="root"
readonly SSH_PASS="alpine"
readonly SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR"
```

## Output

### Example Output
```
[INFO] Testing SSH connectivity to 10.0.0.38...
[SUCCESS] SSH connection established
[INFO] Searching for application containing: 'MyApp'
[SUCCESS] Found application: /var/containers/Bundle/Application/E8C10C61-F45F-4E82-9885-1497F00990FA/MyApp.app
[INFO] Application basename: MyApp.app
[INFO] Preparing extraction environment on remote device
[SUCCESS] Extraction environment prepared
[INFO] Copying application bundle to extraction directory
[SUCCESS] Application bundle copied successfully
[INFO] Creating IPA archive: myapp.ipa
[SUCCESS] IPA archive created successfully
[INFO] Verifying IPA archive creation
total 46148
drwxr-xr-x 3 root wheel       96 Sep 28 09:02 Payload
-rw-r--r-- 1 root wheel 46638083 Sep 28 09:02 myapp.ipa
[SUCCESS] IPA archive verified
[INFO] Downloading IPA file to local system
[SUCCESS] IPA file downloaded: /home/user/myapp.ipa
[INFO] Cleaning up remote temporary files
[SUCCESS] Remote cleanup completed

[SUCCESS] Extraction completed successfully
┌─────────────────────────────────────────────────────────────┐
│                    EXTRACTION SUMMARY                       │
├─────────────────────────────────────────────────────────────┤
│ Target Device: 10.0.0.38
│ Application:   MyApp.app
│ Output File:   /home/user/myapp.ipa
│ File Size:     44.5M
└─────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### Common Issues

**"sshpass utility not found"**
- Install sshpass using the installation instructions above
- Alternatively, configure SSH key authentication

**"Cannot establish SSH connection"**
- Verify the device IP address is correct
- Ensure SSH service is running on the target device
- Check network connectivity
- Verify SSH credentials (default: root/alpine)

**"No application bundles found"**
- Ensure the target device is properly jailbroken
- Verify applications are installed in standard locations
- Check SSH permissions and access

**"No application found matching fragment"**
- Use a more specific or different application name fragment
- Check the list of available applications shown in the error message
- Ensure the application is actually installed
- **Important**: Sometimes the application name on the home screen differs from the actual bundle name. If extraction fails even with the correct home screen name, use a file manager like Filza to navigate to `/var/containers/Bundle/Application` and locate the actual `.app` folder. The folder name (e.g., `MyApp.app`) is what you should use for extraction, not the display name shown on the home screen.

**"Failed to create IPA archive"**
- Ensure zip utility is available on the target device
- Check available disk space on the target device
- Verify application bundle integrity

---

**Disclaimer**: This tool is provided as-is for educational and authorized security testing purposes. Users are responsible for ensuring compliance with applicable laws and regulations.
