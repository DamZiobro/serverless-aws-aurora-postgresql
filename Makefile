#
# Makefile
#

#set default ENV based on your username and hostname
APP_DIR=api
TEST_DIR=tests
#get name of GIT branchse => remove 'feature/' if exists and limit to max 20 characters
GIT_BRANCH_TAG=$(shell git rev-parse --abbrev-ref HEAD | sed -E 's/[\/]+/-/g' | sed -E 's/feature-//g' | cut -c 1-9)
ENV ?= $(GIT_BRANCH_TAG)
AWS_DEFAULT_REGION ?= eu-west-1

#==========================================================================
# Test and verify quality of the app
serverless:
	#install serverless framework for Continous Deployment
	npm install -g serverless@1.51.0 || true
	sls plugin install -n serverless-plugin-cloudwatch-dashboard
	sls plugin install -n serverless-python-requirements
	touch $@


requirements: serverless
	pip install -r requirements.txt
	pip install -r tests/test-requirements.txt
	pip install -r load-tests/test-requirements.txt
	touch $@

unittest: requirements
	python -m unittest discover ${TEST_DIR}

coverage: requirements
	python -m coverage --version
	python -m coverage run --source ${APP_DIR} --branch -m unittest discover -v 
	python -m coverage report -m
	python -m coverage html

lint: requirements
	python -m pylint --version
	python -m pylint ${APP_DIR}

security:
	python -m bandit --version
	python -m bandit ${APP_DIR}

code-checks: lint security

deploy:
	@echo "======> Deploying to env $(ENV) <======"

deploy-all: deploy requirements
	@echo "======> Deploying to env $(ENV) <======"
ifeq ($(FUNC),)
	sls deploy --stage $(ENV) --verbose --region $(AWS_DEFAULT_REGION)
else
	sls deploy --stage $(ENV) -f $(FUNC) --verbose --region $(AWS_DEFAULT_REGION)
endif

e2e-tests: run-and-logs

load-tests:
	ENV=$(ENV) python -m locust -f load-tests/locusttest.py --config load-tests/locust.conf

destroy:
	@echo "======> DELETING in env $(ENV) <======"

destroy-all: destroy
	@echo "======> DELETING in env $(ENV) <======"
	sls remove --stage $(ENV) --verbose --region $(AWS_DEFAULT_REGION)

ci: code-checks unittest coverage
cd: ci deploy-all e2e-tests load-tests

.PHONY: e2e-test deploy destroy unittest coverage lint security code-checks smoke-run logs destroy load-tests
