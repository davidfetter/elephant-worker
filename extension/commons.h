/* ------------------------------------------------------------------------
 * commons.h
 *  	General definition that apply to the extension as a whole
 *
 * Copyright (c) 2014, Zalando SE.
 * Portions Copyright (C) 2013-2014, PostgreSQL Global Development Group
 * ------------------------------------------------------------------------
 */

#ifndef _COMMONS_H
#define _COMMONS_H

#define EXTENSION_NAME  "elephant_worker"
#define JOB_MAGIC 18062015

 typedef struct db_object_data
 {
 	uint32 magic;
 	const char   *schema;
 	const char   *name;
 } db_object_data;

#endif /* _JOBS_H */