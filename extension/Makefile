MODULE_big = elephant_worker

EXTENSION = elephant_worker
OBJS = worker.o launcher.o jobs.o

DATA = elephant_worker--unstable.sql
PGFILEDESC = "elephant_worker - execute periodic tasks from the database"

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
