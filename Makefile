REGIONS := us-east-1 us-west-2
TF      := terraform -chdir=platform

.PHONY: up down init validate plan check fmt evidence $(addprefix plan-,$(REGIONS))

up:
	docker compose up -d --wait

down:
	docker compose down

init:
	$(TF) init

validate: init
	$(TF) validate

$(addprefix plan-,$(REGIONS)): plan-%: init
	. ./localstack.env && \
	$(TF) workspace select -or-create $* && \
	$(TF) plan -var-file=envs/$*.tfvars

plan: $(addprefix plan-,$(REGIONS))

check:
	scripts/check-policies.sh

fmt:
	terraform fmt -recursive

evidence: init
	@for r in $(REGIONS); do \
	  . ./localstack.env && \
	  $(TF) workspace select -or-create $$r >/dev/null && \
	  $(TF) plan -no-color -var-file=envs/$$r.tfvars > docs/evidence/plan-$$r.txt && \
	  echo "wrote docs/evidence/plan-$$r.txt"; \
	done
	scripts/check-policies.sh 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > docs/evidence/policy-checks.txt
	@echo "wrote docs/evidence/policy-checks.txt"
