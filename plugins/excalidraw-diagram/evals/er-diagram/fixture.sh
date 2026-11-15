#!/bin/bash
# Writes db/schema.sql with the users, orders, and order_items tables.
set -eu
python3 "$(dirname "${BASH_SOURCE[0]}")/../_fixture.py" schema
