#!/bin/bash

if [ "${RUN_DB_MIGRATION}" == "true" ];
then
	echo "DB migration - done"
  exit 0;
fi

if [ "${RUN_DB_ROLLBACK}" == "true" ];
then
	echo "DB rollback - done"
  exit 0;
fi

$@