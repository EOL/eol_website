#!/bin/sh
rm -f rm -f /tmp/*.pid /tmp/*.sock
rake assets:precompile
bundle install
bundle update eol_terms
exec "$@"
