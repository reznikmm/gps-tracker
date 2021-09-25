# SPDX-FileCopyrightText: 2021 Max Reznik <reznikmm@gmail.com>
#
# SPDX-License-Identifier: MIT
#

UID ?= $(shell id -u)

all:
	docker run --rm -v `pwd`:`pwd` -w `pwd`/source/receiver --user $(UID) reznik/gnat:idf-v4.3.1 idf.py app

install:
	@echo Nothing here for now
clean:
	@echo Nothing here for now

check: all
	@set -e; \
	echo No tests yet
