# Base image: Rocky Linux 8
FROM rockylinux:8

# Install Ansible, Python, and other dependencies
RUN dnf update -y && \
    dnf install -y \
        ansible-core \
        python3-pip \
        sudo \
        iproute \
        mariadb-server \
        mariadb \
        php \
        httpd && \
    dnf clean all

# Install Python dependencies for Ansible modules if any (assuming community.mysql is needed)
RUN ansible-galaxy collection install community.mysql

# Copy Ansible playbook content into the image
COPY ../../ansible /ansible

# Set up a basic MariaDB instance for the test
# The playbook expects DB variables; we'll set them up here.
RUN /usr/sbin/mysqld --user=mysql --datadir=/var/lib/mysql & \
    sleep 5 && \
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS test_db;" && \
    mysql -u root -e "CREATE USER IF NOT EXISTS 'test_user'@'localhost' IDENTIFIED BY 'test_password';" && \
    mysql -u root -e "GRANT ALL PRIVILEGES ON test_db.* TO 'test_user'@'localhost';" && \
    mysql -u root -e "FLUSH PRIVILEGES;" && \
    killall mysqld && \
    sleep 5

# Set working directory
WORKDIR /ansible

# Expose port 80 for HTTP access (optional, for manual checking if needed)
EXPOSE 80

# Define the entrypoint for the test script
ENTRYPOINT ["/ansible/tests/playbook_test/test.sh"]
