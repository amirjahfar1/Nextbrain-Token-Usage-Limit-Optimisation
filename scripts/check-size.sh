#!/bin/sh
exec sh "$(dirname "$0")/../skill/scripts/check-size.sh" "${@:-$(dirname "$0")/..}"
