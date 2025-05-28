ENV := $(shell cat ../../.last_used_env || echo "not-set")
-include ../../.env.${ENV}

init:
	packer init -upgrade .

build:
	if [ -n "$(GCP_PROJECT_ID)" ] && [ -n "$(GCP_ZONE)" ]; then \
		packer build -only=googlecompute.orch -var "gcp_project_id=$(GCP_PROJECT_ID)" -var "gcp_zone=$(GCP_ZONE)" .; \
	elif [ -n "$(AWS_REGION)" ]; then \
		PACKER_LOG=1 packer build -only=amazon-ebs.orch -var "aws_region=$(AWS_REGION)" -var "aws_instance_type=$(CLIENT_MACHINE_TYPE)" .; \
	else \
		echo "Error: Either GCP_PROJECT_ID and GCP_ZONE or AWS_REGION must be set"; \
		exit 1; \
	fi

format:
	packer fmt .
