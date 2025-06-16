# SRE Technical Test

## Objective

Build a provisioning script that sets up a basic **"Hello World" Rails application** connected to **PostgreSQL** and **Redis**, with **monitoring and alerting** for all services.

---

## Table of Contents

- [Provisioning Overview](#provisioning-overview)
- [Requirements](#requirements)
- [How to Run](#how-to-run)

---

## Provisioning Overview

This project includes a provisioning script (`provision.sh`) that:

- Installs and configures:
  - Ruby, Rails
  - PostgreSQL
  - Redis
  - Node.js & Yarn (Rails dependencies)
- Sets up a sample Rails "Hello World" app
- Connects the app to PostgreSQL and Redis
- Deploys Prometheus and Grafana for monitoring
- Configures Node Exporter and Redis Exporter
- Sets up basic alerting rules in Prometheus

---

## Requirements

- Ubuntu 20.04+ (or equivalent Debian-based system)
- Bash
- Docker & Docker Compose (for monitoring stack)

---

## How to Run

1. **Clone the repository**

   ```bash
   git clone https://github.com/vkubik/hello-app.git
   cd hello-app
