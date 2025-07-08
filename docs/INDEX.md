# Documentation Index

This directory contains organized documentation for the ROSA Terraform Infrastructure project.

## 📁 Folder Structure

### `/docs/`
- **`README.md`** - Main documentation for ROSA Terraform IaC solution
- **`INDEX.md`** - This file

### `/docs/summaries/`
- **`rosa_summary_readme.md`** - Original ROSA summary documentation
- **`rosa_summary_readme-2.md`** - Additional ROSA summary documentation

### `/docs/architecture/`
- **`rosa_terraform_starter.txt`** - Initial Terraform template for ROSA
- **`Multi-Agent Document Processing Workflow - Claude.html`** - Workflow documentation

## 🔗 Related Folders

### `/context/`
Contains analysis and context files used to generate this infrastructure:

- **`/context/analysis/`** - IDPP analysis outputs
- **`/context/prompts/`** - Claude prompts used for generation
- **`/context/components/`** - Infrastructure component catalogs

### `/terraform/`
Contains the actual Infrastructure as Code:

- **`/terraform/modules/`** - Terraform modules
- **`/terraform/environments/`** - Environment-specific configurations

### `/scripts/`
Contains automation scripts:

- **`deploy-rosa.sh`** - Main deployment script
- **`validate-rosa.sh`** - Prerequisites validation
- **`cleanup-rosa.sh`** - Safe cluster deletion

## 📖 Getting Started

1. Start with `/docs/README.md` for complete documentation
2. Review `/context/` files to understand the analysis behind the infrastructure
3. Use files in `/terraform/` for actual deployment
4. Use scripts in `/scripts/` for automation

## 🏗️ Architecture Overview

This project implements a comprehensive ROSA (Red Hat OpenShift Service on AWS) deployment using Terraform with ROSA CLI integration, providing:

- Complete infrastructure automation
- Production-ready configurations
- Comprehensive validation and monitoring
- Easy deployment and management scripts