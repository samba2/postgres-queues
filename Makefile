# really slow on Windows mount
VENV_DIR=/tmp/postgres-queue-example-venv

functions:
ifeq (,$(wildcard psql_conf.sh))
	$(error Create file psql_conf.sh and set envvars PGDATABASE and PGUSER to your local Postgres DB)
endif
	. ./psql_conf.sh && \
	psql --file=queue/functions.sql --set=ON_ERROR_STOP=1 && \
	psql --file=log/functions.sql --set=ON_ERROR_STOP=1

python_venv:
	python3 -m venv $(VENV_DIR)
	. $(VENV_DIR)/bin/activate && \
	pip install -r requirements.txt

clean:
	rm -rf $(VENV_DIR)