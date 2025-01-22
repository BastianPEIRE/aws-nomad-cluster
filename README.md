# Terraform Nomad Cluster Project

This Terraform project deploys a Nomad cluster with Consul on AWS.

![image](https://github.com/user-attachments/assets/8b1f3a27-fbf7-4cc1-b743-edb9f75f0bea)


Follow the steps below to set up and execute the project.
---

## Prerequisites

1. **AWS Key Pair**:
   - Create a key pair in the AWS EC2 Management Console:
     1. Navigate to the EC2 service.
     2. Go to **Key Pairs** under the "Network & Security" section.
     3. Create a new key pair and download the `.pem` file.
   - Move the `.pem` file to the root directory of this project.

2. **AWS CLI**:
   - Ensure the AWS CLI is installed and configured.
   - Run the following command to configure it:
     ```bash
     aws configure
     ```
   - Provide your AWS Access Key ID, Secret Access Key, default region (e.g., `eu-west-1`), and default output format.

3. **Terraform**:
   - Install Terraform from the [official website](https://www.terraform.io/downloads).
   - Ensure it is available in your system's PATH.

---

## Configuration

1. **Key Pair Configuration**:
   - Replace `"your-key-name"` with the name of your key pair created in AWS.
     
---

## Steps to Deploy

1. **Initialize Terraform**:
   - Run the following command to download the required provider plugins and initialize Terraform:
     ```bash
     terraform init
     ```

2. **Plan the Deployment**:
   - Generate and review an execution plan to see the resources that Terraform will create:
     ```bash
     terraform plan
     ```

3. **Apply the Configuration**:
   - Deploy the infrastructure to AWS:
     ```bash
     terraform apply
     ```
   - Confirm the apply step when prompted by typing `yes`.

---

## Notes

- Ensure the key file has the correct permissions before using it. Run:
  ```bash
  chmod 400 key-nomad.pem
