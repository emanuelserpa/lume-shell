#!/bin/sh
printf '%s\n' '{"ok":true,"version":1,"data":{"text":"false success"}}'
printf '%s\n' 'deliberate failure' >&2
exit 7
