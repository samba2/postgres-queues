# really slow on Windows mount
VENV_DIR=/tmp/postgres-queue-example-venv

schema:
	psql --user=samba --file=setup-queue.sql postgres

python_venv:
	python3 -m venv $(VENV_DIR)

python_pip_install:
	. $(VENV_DIR)/bin/activate && \
	pip install -r requirements.txt

clean:
	rm -rf $(VENV_DIR)