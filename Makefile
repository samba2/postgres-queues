services:
	docker-compose up -d

functions: services
	docker-compose exec postgres psql --set=ON_ERROR_STOP=1 --username postgres --file=/data/functions.sql

python3_tests:
	docker-compose run python3 python -m unittest /data/hello_world_test.py

clean:
	docker-compose down --remove-orphans


# VENV_DIR=/tmp/postgres-queue-example-venv

# python_venv:
# 	python3 -m venv $(VENV_DIR)
# 	. $(VENV_DIR)/bin/activate && \
# 	pip install -r requirements.txt

# clean:
# 	rm -rf $(VENV_DIR)