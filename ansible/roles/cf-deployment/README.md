# CF Deployment Ansible Role

This role is responsible for orchestrating the deployment of the ConsultingFirm microservices application onto an OpenShift (ROSA) cluster. It handles namespace creation and the deployment of microservices via a Helm chart, relying on the ROSA worker nodes' IAM roles for ECR image authentication.

## Purpose

The `cf-deployment` role automates the following key steps:
1.  **Namespace Creation**: Ensures the target OpenShift namespace (`cf-dev`, `cf-test`, or `cf-prod` based on the environment) exists.
2.  **Microservices Deployment**: Deploys the ConsultingFirm microservices using the `cf-microservices` Helm chart. This deployment is configured to pull images directly from Amazon ECR, leveraging the underlying IAM permissions of the ROSA worker nodes.

This role is designed to be idempotent, meaning it can be run multiple times without causing unintended side effects.

## How to Create a New Ansible Role (Step-by-Step)

To create a new Ansible role from scratch, follow these steps:

1.  **Create the Role Directory Structure**:
    Ansible roles follow a standard directory structure. From your Ansible `roles` directory, create a new directory for your role (e.g., `my-new-role`) and then create the standard subdirectories within it:

    ```bash
    mkdir -p roles/my-new-role/{tasks,handlers,defaults,vars,files,templates,meta}
    ```

    -   `tasks/`: Contains the main playbook files for the role.
    -   `handlers/`: Contains handlers, which are tasks that are only run when explicitly notified.
    -   `defaults/`: Contains default variables for the role. These can be overridden by other variable sources.
    -   `vars/`: Contains other variables for the role. These have higher precedence than `defaults`.
    -   `files/`: Contains static files that can be copied to managed nodes.
    -   `templates/`: Contains Jinja2 templates that can be rendered on managed nodes.
    -   `meta/`: Contains metadata about the role (e.g., dependencies).

2.  **Define Main Tasks (`tasks/main.yml`)**:
    This is the entry point for your role's tasks. It typically includes other task files.

    ```yaml
    # roles/my-new-role/tasks/main.yml
    ---
    - name: My New Role - Start
      debug:
        msg: "Starting my new role"

    - name: Include a specific task file
      include_tasks: another_task.yml

    - name: My New Role - End
      debug:
        msg: "My new role completed"
    ```

3.  **Add Other Task Files (e.g., `tasks/another_task.yml`)**:
    Break down complex logic into smaller, more manageable task files.

    ```yaml
    # roles/my-new-role/tasks/another_task.yml
    ---
    - name: Perform a specific action
      ansible.builtin.command: echo "Hello from another task!"
    ```

4.  **Define Default Variables (`defaults/main.yml`)**:
    Set default values for variables used in your role.

    ```yaml
    # roles/my-new-role/defaults/main.yml
    ---
    my_variable: "default_value"
    ```

5.  **Define Role Variables (`vars/main.yml`)**:
    If you need variables with higher precedence than defaults, define them here.

    ```yaml
    # roles/my-new-role/vars/main.yml
    ---
    another_variable: "role_specific_value"
    ```

6.  **Add Handlers (`handlers/main.yml`)**:
    If your role needs to react to changes (e.g., restart a service after a config file changes), define handlers.

    ```yaml
    # roles/my-new-role/handlers/main.yml
    ---
    - name: restart service
      ansible.builtin.service:
        name: my_service
        state: restarted
    ```

7.  **Add Metadata (`meta/main.yml`)**:
    Define role dependencies or other metadata.

    ```yaml
    # roles/my-new-role/meta/main.yml
    ---
    dependencies:
      # - role: another-role
      #   version: 1.0.0
    ```

## Role Structure and Code Details

The `cf-deployment` role has the following structure:

```
roles/cf-deployment/
├── defaults/
│   └── main.yml
├── tasks/
│   ├── cf-microservices.yml
│   ├── cf-namespace.yml
│   └── main.yml
└── .DS_Store (ignored)
```

### `roles/cf-deployment/tasks/main.yml`

This is the main entry point for the `cf-deployment` role. It orchestrates the execution of other tasks.

```yaml
---
# CF Deployment Role - Main Orchestrator
# Orchestrates ECR access setup, namespace creation, and microservices deployment

- name: CF Deployment - Start orchestration
  debug:
    msg:
      - "Starting CF Deployment orchestration"
      - "Environment: {{ env | default('dev') }}"
      - "Namespace: {{ cf_namespace }}"
      - "Release: {{ cf_release_name }}"
  tags:
    - cf-deployment
    - orchestration

# Step 1: Create CF Namespace (Must be first - required for ECR service account)
- name: Include CF Namespace Creation
  include_tasks: cf-namespace.yml
  tags:
    - cf-deployment
    - namespace
    - cf-namespace

# Step 3: Deploy CF Microservices
- name: Include CF Microservices Deployment
  include_tasks: cf-microservices.yml
  tags:
    - cf-deployment
    - deployment
    - microservices

- name: CF Deployment - Orchestration completed
  debug:
    msg:
      - "CF Deployment orchestration completed successfully"
      - "Environment: {{ env | default('dev') }}"
      - "Namespace: {{ cf_namespace }}"
      - "All components deployed and verified"
  tags:
    - cf-deployment
    - orchestration
    - complete
```

### `roles/cf-deployment/tasks/cf-namespace.yml`

This task is responsible for creating and verifying the OpenShift namespace where the microservices will be deployed. The namespace name is dynamically set based on the `env` variable.

```yaml
---
# CF Namespace Creation Task
# Creates namespace based on environment variable (dev/test/prod)

- name: Set namespace based on environment
  set_fact:
    cf_namespace: "cf-{{ env }}"
  when: env is defined
  tags:
    - cf-deployment
    - namespace
    - cf-namespace

- name: Display namespace creation information
  debug:
    msg:
      - "Creating namespace for environment: {{ env | default('dev') }}"
      - "Namespace: {{ cf_namespace }}"
  tags:
    - cf-deployment
    - namespace
    - cf-namespace

- name: Create CF namespace
  kubernetes.core.k8s:
    name: "{{ cf_namespace }}"
    api_version: v1
    kind: Namespace
    state: present
    definition:
      metadata:
        name: "{{ cf_namespace }}"
        labels:
          name: "{{ cf_namespace }}"
          environment: "{{ env | default('dev') }}"
          app.kubernetes.io/name: consultingfirm
          app.kubernetes.io/component: namespace
          app.kubernetes.io/managed-by: ansible
  tags:
    - cf-deployment
    - namespace
    - cf-namespace

- name: Verify CF namespace exists
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Namespace
    name: "{{ cf_namespace }}"
  register: cf_namespace_info
  tags:
    - cf-deployment
    - namespace
    - cf-namespace
    - verify

- name: Display CF namespace status
  debug:
    msg:
      - "Namespace: {{ cf_namespace }}"
      - "Environment: {{ env | default('dev') }}"
      - "Status: {{ cf_namespace_info.resources[0].status.phase if cf_namespace_info.resources else 'Not Found' }}"
      - "Creation timestamp: {{ cf_namespace_info.resources[0].metadata.creationTimestamp if cf_namespace_info.resources else 'N/A' }}"
  tags:
    - cf-deployment
    - namespace
    - cf-namespace
    - verify

- name: Namespace creation completed
  debug:
    msg: "Namespace {{ cf_namespace }} is ready for deployments"
  tags:
    - cf-deployment
    - namespace
    - cf-namespace
```

### `roles/cf-deployment/tasks/cf-microservices.yml`

This task deploys the ConsultingFirm microservices using the `kubernetes.core.helm` module. It points to the `cf-microservices` Helm chart and uses a dynamic `values_file` based on the environment.

**Important Note on ECR Authentication**: This task does *not* explicitly configure `imagePullSecrets` or `serviceAccountName` in the Helm deployment. It relies on the ROSA worker nodes having the necessary IAM permissions to pull images from the specified ECR registry. The `helm-charts/cf-microservices/values.yaml` and the individual `deployment.yaml` templates within the Helm chart are configured to use the `global.registry` and `imagePullPolicy: Always` without any explicit secret.

```yaml
---
# CF Deployment Role - Helm Integration
# Deploy ConsultingFirm microservices using Helm charts

- name: Deploy CF Microservices using Helm
  kubernetes.core.helm:
    name: "{{ cf_release_name | default('cf-microservices') }}"
    chart_ref: "{{ helm_chart_path }}"
    release_namespace: "{{ cf_namespace }}"
    create_namespace: false
    skip_crds: false
    values_files:
      - "{{ values_file }}"
    values:
      global:
        namespace: "{{ cf_namespace }}"
    state: present
    wait: true
    wait_timeout: 600s
  tags:
    - cf-deployment
    - deployment
    - cf-deploy-all
    - helm-deploy

- name: Verify namespace creation
  kubernetes.core.k8s_info:
    api_version: v1
    kind: Namespace
    name: "{{ cf_namespace }}"
  register: namespace_info
  tags:
    - cf-deployment
    - deployment
    - cf-namespace
    - verify

- name: Display namespace status
  debug:
    msg: "Namespace {{ cf_namespace }} status: {{ namespace_info.resources[0].status.phase if namespace_info.resources else 'Not Found' }}"
  tags:
    - cf-deployment
    - deployment
    - cf-namespace
    - verify

- name: Wait for all deployments to be ready
  kubernetes.core.k8s_info:
    api_version: apps/v1
    kind: Deployment
    namespace: "{{ cf_namespace }}"
    label_selectors:
      - "app.kubernetes.io/instance={{ cf_release_name | default('cf-microservices') }}"
    wait: true
    wait_condition:
      type: Available
      status: "True"
    wait_timeout: 600
  register: deployments_status
  tags:
    - cf-deployment
    - deployment
    - cf-verify
    - verify

- name: Display deployment status
  debug:
    msg: "Found {{ deployments_status.resources | length }} deployments in {{ cf_namespace }} namespace"
  tags:
    - cf-deployment
    - deployment
    - cf-verify
    - verify

# Individual service deployment tasks with specific tags (truncated for brevity, full code in file)
# ... (rest of the file contains tasks for deploying individual services with specific tags)
```

### `roles/cf-deployment/defaults/main.yml`

This file defines the default variables used by the `cf-deployment` role. These values can be overridden by variables defined in inventory files, command-line arguments, or other parts of the playbook.

```yaml
---
# Default variables for CF Deployment Role

# Default environment configuration (can be overridden by environment configs)
env: dev
cf_environment: "{{ env | default('dev') }}"
cf_namespace: "cf-{{ env | default('dev') }}"
cf_release_name: "cf-microservices-{{ env | default('dev') }}"

# Helm chart configuration
helm_chart_path: "{{ playbook_dir }}/../helm-charts/cf-microservices"
values_file: "{{ playbook_dir }}/../environments/{{ cf_environment }}/deployment-values.yaml"

# Service deployment flags
deploy_naming_server_only: false
deploy_api_gateway_only: false
deploy_spring_boot_admin_only: false
deploy_config_service_only: false
deploy_business_services_only: false
deploy_frontend_only: false

# Deployment timeouts (in seconds)
helm_timeout: 600
deployment_wait_timeout: 600

# Verification settings
verify_deployment: true
show_deployment_status: true
```

### Key Variables Explained

-   `env`: (Default: `dev`) Specifies the deployment environment (e.g., `dev`, `test`, `prod`). This variable drives the namespace name and the specific `deployment-values.yaml` file used.
-   `cf_namespace`: (Derived from `env`) The name of the OpenShift namespace (e.g., `cf-dev`).
-   `cf_release_name`: (Derived from `env`) The Helm release name (e.g., `cf-microservices-dev`).
-   `helm_chart_path`: The absolute path to the `cf-microservices` Helm chart.
-   `values_file`: The path to the environment-specific Helm values file (e.g., `environments/dev/deployment-values.yaml`).
-   `deploy_*-only`: Boolean flags (default: `false`) that allow deploying only specific microservices or groups of microservices. These are used with `when` conditions in `cf-microservices.yml`.

## Helm Chart (`helm-charts/cf-microservices/`)

The `cf-microservices` Helm chart is central to the deployment. It defines the Kubernetes manifests for all ConsultingFirm microservices.

### `helm-charts/cf-microservices/values.yaml`

This file contains the default values for the Helm chart. Crucially, the `global.registry` variable specifies the ECR registry from which images are pulled. There are no `dockerconfigjson` or `dockerSecret` entries, as the system relies on the worker node IAM role.

```yaml
# Global configuration
global:
  namespace: cf-dev
  registry: 818140567777.dkr.ecr.us-east-1.amazonaws.com/consultingfirm
  pullPolicy: Always

# Service enablement flags (truncated for brevity)
# ...

# Individual service configurations (truncated for brevity)
# ...
```

### Example Deployment Template (`helm-charts/cf-microservices/charts/api-gateway/templates/deployment.yaml`)

This is an example of how a microservice deployment is defined within the Helm chart. Notice the `image` field directly references the `global.registry` and `imagePullPolicy: Always`. There is no `imagePullSecrets` or `serviceAccountName` specified at the pod level.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apigateway-app
  namespace: {{ .Values.global.namespace }}
  labels:
    app: apigateway-app
    version: {{ .Chart.AppVersion }}
spec:
  replicas: {{ .Values.deployment.replicas }}
  selector:
    matchLabels:
      app: apigateway-app
  template:
    metadata:
      labels:
        app: apigateway-app
        version: {{ .Chart.AppVersion }}
    spec:

      containers:
      - name: apigateway-app
        image: "{{ .Values.global.registry }}/{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - containerPort: {{ .Values.service.targetPort }}
          protocol: TCP
        {{- with .Values.deployment.resources }}
        resources:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: {{ .Values.service.targetPort }}
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: {{ .Values.service.targetPort }}
          initialDelaySeconds: 30
          periodSeconds: 10
```

## Execution Instructions

To execute the `cf-deployment` Ansible role, you will typically run it as part of a larger playbook.

### Prerequisites

1.  **Ansible Installed**: Ensure Ansible is installed on your control machine.
2.  **OpenShift CLI (`oc`)**: Ensure `oc` is installed and configured to connect to your ROSA cluster.
3.  **Kubernetes Python Client**: Ensure the `kubernetes` Python client is installed for Ansible to interact with the cluster:
    ```bash
    pip install openshift kubernetes
    ```
4.  **Helm Installed**: Ensure Helm is installed on your control machine.
5.  **AWS CLI**: Ensure AWS CLI is installed and configured with credentials that can describe ROSA cluster details (though not directly used by this role for ECR auth, it's generally needed for ROSA management).
6.  **ROSA Worker Node IAM Permissions**: **Crucially**, ensure the IAM role attached to your ROSA worker nodes has the necessary permissions to pull images from your ECR repository. This typically includes actions like `ecr:GetDownloadUrlForLayer`, `ecr:BatchGetImage`, and `ecr:BatchCheckLayerAvailability`.

### Running the Role

You can run this role by including it in your main playbook (e.g., `playbooks/main.yml`).

**Example `playbooks/main.yml`:**

```yaml
---
- name: Deploy ConsultingFirm Application to OpenShift
  hosts: localhost
  connection: local
  gather_facts: false
  vars:
    env: dev # Set your target environment (dev, test, prod)

  tasks:
    - name: Include CF Deployment Role
      ansible.builtin.include_role:
        name: cf-deployment
```

**Execution Command:**

Navigate to the root of your Ansible project (where `ansible.cfg` and `playbooks/` are located) and run the playbook:

```bash
ansible-playbook -i localhost, playbooks/main.yml -e "env=dev"
```

-   `-i localhost,`: Specifies the inventory. Since this role interacts with Kubernetes API directly, it runs locally.
-   `playbooks/main.yml`: The main playbook file that includes the `cf-deployment` role.
-   `-e "env=dev"`: Passes the `env` variable to the playbook, setting the target environment to `dev`. Change `dev` to `test` or `prod` as needed.

### Verifying the Deployment

After execution, you can verify the deployment using `oc` commands:

1.  **Check Namespace**:
    ```bash
    oc get project cf-dev # Replace cf-dev with your target namespace
    ```
2.  **Check Pods**:
    ```bash
    oc get pods -n cf-dev
    ```
3.  **Check Deployments**:
    ```bash
    oc get deployments -n cf-dev
    ```
4.  **Check Events for Image Pull Errors**: If you encounter `ImagePullBackOff` errors, check the pod events for details:
    ```bash
    oc describe pod <pod-name> -n cf-dev
    ```
    Look for messages related to image pulling failures, which would indicate an issue with the ECR IAM permissions on the worker nodes.
