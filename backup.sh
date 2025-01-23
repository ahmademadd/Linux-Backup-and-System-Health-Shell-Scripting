#!/usr/bin/env bash

# Script Name: backup.sh
# Description: Create a backup of the provided directory based on user inputs.
# Usage: backup.sh

set -e
trap cleanup INT

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
LOG_FILE="backup_$(date -u +%Y-%m-%dT%H:%M:%SZ).log"

cleanup() {
    echo -e "${RED}Script interrupted. Cleaning up...${NC}" | tee -a "${LOG_FILE}"

    if [[ -n "${BACKUP_DIR}" ]]; then
        echo "Removing incomplete backup files in ${BACKUP_DIR}" | tee -a "${LOG_FILE}"
        find "${BACKUP_DIR}" -name 'backup_*' -mmin -5 -delete
    fi

    exit 1
}

check_dependencies() {
    dependencies=("rsync" "tar" "gpg" "ssh")

    for i in "${dependencies[@]}"; do
        command -v "$i" >/dev/null 2>&1 || { echo -e "${RED}$i is required but it's not installed. Aborting.${NC}" | tee -a "${LOG_FILE}" >&2; exit 1; }
    done
}

expand_tilde() {
    local path=$1
    if [[ $path == \~/* ]]; then
        echo "${HOME}/${path:2}"
    else
        echo "$path"
    fi
}

validate_inputs() {
    # Check if source directory exists and is a directory
    if [[ -z "${SOURCE_DIR}" || ! -d "${SOURCE_DIR}" ]]; then
        echo -e "${RED}Source directory is invalid or does not exist. Aborting.${NC}" | tee -a "${LOG_FILE}"
        exit 1
    fi

    # Check if remote backup is enabled and remote directory is provided
    if [[ "${REMOTE_BACKUP}" == true ]]; then
        if [[ -z "${REMOTE_DIR}" ]]; then
            echo -e "${RED}Remote backup selected but no remote directory provided. Aborting.${NC}" | tee -a "${LOG_FILE}"
            exit 1
        fi
    else
        # Check if local backup directory is provided
        if [[ -z "${BACKUP_DIR}" ]]; then
            echo -e "${RED}Local backup directory is not provided. Aborting.${NC}" | tee -a "${LOG_FILE}"
            exit 1
        fi

        # Check if local backup directory exists or can be created
        if ! mkdir -p "${BACKUP_DIR}" 2>/dev/null; then
            echo -e "${RED}Unable to create or access the local backup directory. Aborting.${NC}" | tee -a "${LOG_FILE}"
            exit 1
        fi
    fi

    # Check if encryption is enabled and passphrase is provided
    if [[ "${WITH_ENCRYPTION}" == true && -z "${GPG_PASSPHRASE}" ]]; then
        echo -e "${RED}Encryption selected but no passphrase provided. Aborting.${NC}" | tee -a "${LOG_FILE}"
        exit 1
    fi

    # Validate boolean inputs
    if [[ "${WITH_COMPRESSION}" != "true" && "${WITH_COMPRESSION}" != "false" ]]; then
        echo -e "${RED}Invalid input for backup compression. Please enter true or false. Aborting.${NC}" | tee -a "${LOG_FILE}"
        exit 1
    fi

    if [[ "${WITH_ENCRYPTION}" != "true" && "${WITH_ENCRYPTION}" != "false" ]]; then
        echo -e "${RED}Invalid input for backup encryption. Please enter true or false. Aborting.${NC}" | tee -a "${LOG_FILE}"
        exit 1
    fi

    if [[ "${REMOTE_BACKUP}" != "true" && "${REMOTE_BACKUP}" != "false" ]]; then
        echo -e "${RED}Invalid input for remote backup. Please enter true or false. Aborting.${NC}" | tee -a "${LOG_FILE}"
        exit 1
    fi

    echo -e "${GREEN}Input validation complete${NC}" | tee -a "${LOG_FILE}"
}

check_disk_space() {
    required_space=$(du -sBG "${SOURCE_DIR}" | cut -f1 | sed 's/G//')
    available_space=$(df -BG "${BACKUP_DIR}" | awk 'NR==2 {print $4}' | sed 's/G//')

    if [[ "${available_space}" -lt "${required_space}" ]]; then
        echo -e "${RED}Not enough disk space for backup. Aborting.${NC}" | tee -a "${LOG_FILE}"
        exit 1
    fi
}

prompt_user_inputs() {
    read -p "Enter the source directory path that needs to be backed up: " SOURCE_DIR

    echo "Enter directories to exclude from the backup (space-separated, leave blank if none). Example: dir1 dir2"
    read -a EXCLUDE_DIRS

    echo "Enter specific files to exclude from the backup (space-separated, leave blank if none). Example: /absolute/path/to/file2.txt"
    read -a EXCLUDE_FILES

    echo "Enter file extensions to exclude from the backup (space-separated, leave blank if none, start with a dot). Example: .txt .log"
    read -a EXCLUDE_EXTENSIONS

    read -p "Do you want to enable backup compression? (true/false): " WITH_COMPRESSION

    read -p "Do you want to enable backup encryption? (true/false): " WITH_ENCRYPTION
    if [ "$WITH_ENCRYPTION" = true ]; then
        read -s -p "Enter the passphrase for encryption: " GPG_PASSPHRASE
        echo
    fi

    read -p "Do you want to backup to a remote destination? (true/false): " REMOTE_BACKUP
    if [ "$REMOTE_BACKUP" = true ]; then
        read -p "Enter the remote backup directory (user@host:/path). Example: user@ipaddress:/backup/path " REMOTE_DIR
    else
        read -p "Enter the local backup directory path where the backup will be stored: " BACKUP_DIR
    fi

    echo -e "${GREEN}Input collection complete${NC}" | tee -a "${LOG_FILE}"
}

compress_backup() {
    echo "Compressing backup" | tee -a "${LOG_FILE}"
    tar -czf "${BACKUP_FILE}.tar.gz" -C "${BACKUP_DIR}" "$(basename "${BACKUP_FILE}")"
    rm -rf "${BACKUP_FILE}"  # Remove the uncompressed directory
    BACKUP_FILE="${BACKUP_FILE}.tar.gz"
    echo -e "${GREEN}Compression complete${NC}" | tee -a "${LOG_FILE}"
}

encrypt_backup() {
    echo "Encrypting backup" | tee -a "${LOG_FILE}"
    gpg --batch --yes --passphrase="${GPG_PASSPHRASE}" --symmetric "${BACKUP_FILE}"
    rm -rf "${BACKUP_FILE}"  # Remove the uncompressed or compressed file
    BACKUP_FILE="${BACKUP_FILE}.gpg"
    echo -e "${GREEN}Encryption complete${NC}" | tee -a "${LOG_FILE}"
}

create_backup() {
    echo "Creating backup" | tee -a "${LOG_FILE}"

    # Convert array to rsync exclude format
    for dir in "${EXCLUDE_DIRS[@]}"; do
        rsync_exclude_params+=" --exclude=$(expand_tilde "$dir")"
    done

    for file in "${EXCLUDE_FILES[@]}"; do
        relative_file=$(realpath --relative-to="$SOURCE_DIR" "$(expand_tilde "$file")")
        rsync_exclude_params+=" --exclude=$relative_file"
    done

    for ext in "${EXCLUDE_EXTENSIONS[@]}"; do
        rsync_exclude_params+=" --exclude=*$ext"
    done

    BACKUP_FILE="backup_$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    if [ "${REMOTE_BACKUP}" = true ]; then
        echo -e "${GREEN}Rsync command: rsync -av $rsync_exclude_params ${SOURCE_DIR} ${REMOTE_DIR}/${BACKUP_FILE}${NC}" | tee -a "${LOG_FILE}"
        if ! eval rsync -av $rsync_exclude_params "${SOURCE_DIR}" "${REMOTE_DIR}/${BACKUP_FILE}"; then
            echo -e "${RED}Error during rsync. Aborting.${NC}" | tee -a "${LOG_FILE}"
            exit 1
        fi
    else
        mkdir -p "${BACKUP_DIR}"
        check_disk_space
        echo -e "${GREEN}Rsync command: rsync -av $rsync_exclude_params ${SOURCE_DIR} ${BACKUP_DIR}/${BACKUP_FILE}${NC}" | tee -a "${LOG_FILE}"
        if ! eval rsync -av $rsync_exclude_params "${SOURCE_DIR}" "${BACKUP_DIR}/${BACKUP_FILE}"; then
            echo -e "${RED}Error during rsync. Aborting.${NC}" | tee -a "${LOG_FILE}"
            exit 1
        fi

        if [ "${WITH_COMPRESSION}" = true ]; then
            compress_backup
        fi

        if [ "${WITH_ENCRYPTION}" = true ]; then
            encrypt_backup
        fi
    fi

    echo -e "${GREEN}Backup created: ${BACKUP_FILE}${NC}" | tee -a "${LOG_FILE}"
    print_backup_size
}

print_backup_size() {
    backup_size=$(du -sh "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)
    echo -e "${GREEN}Backup size: ${backup_size}${NC}" | tee -a "${LOG_FILE}"
}

main() {
    check_dependencies
    prompt_user_inputs
    validate_inputs
    create_backup
}

main "$@"
