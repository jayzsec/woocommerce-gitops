# Ansible Playbook Test using Docker

This directory contains a Docker-based test environment to verify the `ansible/woocommerce-deploy/woocommerce-playbook.yml` playbook.

## Prerequisites

*   Docker installed and running on your system.

## Setup and Execution

1.  **Build the Docker Image:**
    Navigate to the root of this repository. Then, from the repository root, run the following command to build the Docker image:

    ```bash
    docker build -t ansible-playbook-test -f tests/playbook_test/Dockerfile .
    ```

2.  **Run the Test:**
    After the image is successfully built, run the test using the following command:

    ```bash
    docker run --rm ansible-playbook-test
    ```

    This command will:
    *   Start a container from the `ansible-playbook-test` image.
    *   Execute the `tests/playbook_test/test.sh` script inside the container.
    *   The script will set necessary environment variables, start a local MariaDB instance, run the `woocommerce-playbook.yml` playbook against `localhost` within the container, and then perform checks.
    *   The script will output logs from the playbook execution and the tests.
    *   If all checks pass, the script will exit with code 0. Otherwise, it will exit with a non-zero code.
    *   The `--rm` flag ensures the container is removed after the test finishes.

## Test Details

*   **Base Image:** `rockylinux:8`
*   **Playbook Tested:** `ansible/woocommerce-deploy/woocommerce-playbook.yml`
*   **Services Started in Container:**
    *   MariaDB (local instance for WordPress)
    *   Apache (httpd)
*   **Environment Variables for Playbook (set in `test.sh`):**
    *   `DB_NAME`: `test_db`
    *   `DB_USER`: `test_user`
    *   `DB_PASSWORD`: `test_password`
    *   `DB_HOST`: `localhost`
    *   `DOMAIN_NAME`: `localhost`
    *   `CERTBOT_EMAIL`: `test@example.com`
    *   `REMOTE_SYSLOG_SERVER`: `localhost`
*   **Verification Checks:**
    1.  MariaDB service starts successfully.
    2.  Ansible playbook completes without errors.
    3.  `httpd` (Apache) service is active after the playbook run.
    4.  The `health-check.php` script (located at `/wordpress/health-check.php`) is accessible via `curl` and returns "WordPress OK", indicating WordPress can connect to its database.

## Troubleshooting

*   If MariaDB fails to start, the `test.sh` script will attempt to output the MariaDB log.
*   If `httpd` is not running, the script will attempt to output `journalctl -u httpd`.
*   If the health check fails, the script will output `curl` details and the contents of Apache error logs and WordPress debug logs from within the container.
*   Ensure you have sufficient disk space for Docker images and that Docker has enough resources allocated if tests fail unexpectedly.
