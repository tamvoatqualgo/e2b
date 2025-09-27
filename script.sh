#!/bin/bash
touch /tmp/e2b.log
echo "StackName=dm" >> /tmp/e2b.log
BUILD=$(git rev-parse --short HEAD)

while true; do
  STACK_STATUS=$(aws cloudformation describe-stacks --stack-name dm --query "Stacks[0].StackStatus" --output text)
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Stack current state: $STACK_STATUS" >> /tmp/e2b.log

  case $STACK_STATUS in
    CREATE_COMPLETE)
      echo "========================================" >> /tmp/e2b.log
      echo "Start to execute init.sh" >> /tmp/e2b.log
      echo "========================================" >> /tmp/e2b.log
      bash infra-iac/init.sh >> /tmp/e2b.log 2>&1

      echo "========================================" >> /tmp/e2b.log
      echo "Start to execute packer.sh" >> /tmp/e2b.log
      echo "========================================" >> /tmp/e2b.log
      HOME=/root bash -l infra-iac/packer/packer.sh >> /tmp/e2b.log 2>&1

      echo "========================================" >> /tmp/e2b.log
      echo "Start to execute terraform" >> /tmp/e2b.log
      echo "========================================" >> /tmp/e2b.log
      bash infra-iac/terraform/start.sh >> /tmp/e2b.log 2>&1

      echo "========================================" >> /tmp/e2b.log
      echo "Start to execute init-db.sh" >> /tmp/e2b.log
      echo "========================================" >> /tmp/e2b.log
      bash infra-iac/db/init-db.sh >> /tmp/e2b.log 2>&1

      echo "========================================" >> /tmp/e2b.log
      echo "Start to execute build.sh" >> /tmp/e2b.log
      echo "========================================" >> /tmp/e2b.log
      HOME=/root bash packages/build.sh >> /tmp/e2b.log 2>&1

      echo "========================================" >> /tmp/e2b.log
      echo "Start to execute nomad.sh" >> /tmp/e2b.log
      echo "========================================" >> /tmp/e2b.log
      source nomad/nomad.sh >> /tmp/e2b.log 2>&1

      echo "========================================" >> /tmp/e2b.log
      echo "Start to execute prepare.sh" >> /tmp/e2b.log
      echo "========================================" >> /tmp/e2b.log
      bash nomad/prepare.sh >> /tmp/e2b.log 2>&1

      echo "========================================" >> /tmp/e2b.log
      echo "Start to execute deploy.sh" >> /tmp/e2b.log
      echo "========================================" >> /tmp/e2b.log
      bash nomad/deploy.sh >> /tmp/e2b.log 2>&1

      echo "========================================" >> /tmp/e2b.log
      echo "Start to execute create_template.sh" >> /tmp/e2b.log
      echo "========================================" >> /tmp/e2b.log
      bash packages/create_template.sh >> /tmp/e2b.log 2>&1

      echo "========================================" >> /tmp/e2b.log
      echo "E2B Deploy Done!" >> /tmp/e2b.log
      echo "========================================" >> /tmp/e2b.log
      break
      ;;

    CREATE_FAILED|ROLLBACK_COMPLETE|ROLLBACK_FAILED|UPDATE_ROLLBACK_COMPLETE|UPDATE_ROLLBACK_FAILED|DELETE_FAILED)
      echo "exit with error cloudformation state: $STACK_STATUS" >> /tmp/e2b.log
      exit 1
      ;;

    *)
      sleep 10
      ;;
  esac
done