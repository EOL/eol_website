#!/bin/sh
grep Author: config/locales/*.yml | cut -d ' ' -f3 | sort | uniq | xargs -n1 -I{} printf "%s\thttps://translatewiki.net/wiki/User:%s\n" {} {}
