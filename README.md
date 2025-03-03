# Backup and System Health Check Script

_By Ahmad Emad_  
- **YouTube Video**: [Watch Here](https://www.youtube.com/watch?v=EsSXpTnk0D4)  
- **Documentation**: [Click Here](Linux%20Backup%20and%20System%20Health%20Shell%20Scripting%20Report.pdf).
- **Email**: [ahmademad995.ae@gmail.com](mailto:ahmademad995.ae@gmail.com)

## Description

This repository contains two key scripts:

1. **backup.sh**: A shell script for creating backups of a specified directory based on user inputs. It supports local and remote backups with options for compression, encryption, and exclusions.
2. **system-health.sh**: A shell script for generating a system health report, checking disk space, memory usage, running services, and the status of system updates.

## Features

### backup.sh
- **Interactive Setup**: Prompts users for input on which directories, files, and file extensions to exclude from backups.
- **Encryption**: Option to encrypt backup data using GPG for confidentiality.
- **Compression**: Option to compress backups using the tar command.
- **Remote Backup**: Supports remote backups via rsync over SSH to a remote server.
- **Disk Space Check**: Validates if there is enough space for the backup before initiating.
- **Error Logging**: Logs errors and status updates to a timestamped log file for troubleshooting.
- **Cleanup Mechanism**: Deletes incomplete backups if the script is interrupted, ensuring a clean environment.
- **Input Validation**: Ensures that the user inputs are valid and that the required directories and files exist.

### system-health.sh
- **Disk Space Check**: Provides a report on the system's storage usage, including warnings when disk space usage exceeds 90%.
- **Memory Usage**: Displays current memory and swap usage with alerts if memory consumption is high.
- **Running Services**: Lists active system services.
- **System Updates**: Checks the last update time and prompts the user to update the system if updates haven't been applied in the last 7 days.

## Usage

### backup.sh

To run the backup script:

1. Clone the repository:
   ```bash
   git clone https://github.com/ahmademadd/Linux-Backup-and-System-Health-Shell-Scripting.git
   cd Linux-Backup-and-System-Health-Shell-Scripting
   ```

2. Make the script executable:
   ```bash
   chmod +x backup.sh
   ```

3. Run the script:
   ```bash
   ./backup.sh
   ```

4. Follow the on-screen prompts to configure your backup preferences.

### system-health.sh

To run the system health script:

1. Clone the repository:
   ```bash
   git clone https://github.com/ahmademadd/Linux-Backup-and-System-Health-Shell-Scripting.git
   cd Linux-Backup-and-System-Health-Shell-Scripting
   ```

2. Make the script executable:
   ```bash
   chmod +x system-health.sh
   ```

3. Run the script:
   ```bash
   ./system-health.sh
   ```

4. The script will display the system health report, including disk space, memory usage, and system updates.

## Requirements

- **rsync**: For backup synchronization.
- **tar**: For compressing backups.
- **gpg**: For encrypting backups.
- **ssh**: For remote backup support.

To check if dependencies are installed, use the `check_dependencies` function within the script.

## Troubleshooting

If you encounter issues or errors, refer to the log file generated during the backup process (e.g., `backup_YYYY-MM-DDTHH:MM:SSZ.log`) for more details. The log file provides error messages and insights into where the script may have failed.

