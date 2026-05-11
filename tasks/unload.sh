#!/bin/bash

ALLOWED_MODULES="esp4 esp6 rxrpc"
module="${PT_module}"

if [ -z "${module}" ]; then
  echo '{"_error": {"msg": "No module specified", "kind": "dirty_frag/invalid-module", "details": {"module": null}}}'
  exit 1
fi

allowed=false
for m in ${ALLOWED_MODULES}; do
  if [ "${module}" = "${m}" ]; then
    allowed=true
    break
  fi
done

if [ "${allowed}" = "false" ]; then
  echo "{\"_error\": {\"msg\": \"Module '${module}' is not in the allow-list (esp4, esp6, rxrpc)\", \"kind\": \"dirty_frag/invalid-module\", \"details\": {\"module\": \"${module}\"}}}"
  exit 1
fi

if ! grep -q "^${module} " /proc/modules 2>/dev/null; then
  echo "{\"module\": \"${module}\", \"_error\": {\"msg\": \"Module '${module}' is not currently loaded\", \"kind\": \"dirty_frag/module-not-loaded\", \"details\": {\"module\": \"${module}\"}}}"
  exit 1
fi

stderr=$(modprobe -r "${module}" 2>&1)
rc=$?

if [ ${rc} -eq 0 ]; then
  echo "{\"module\": \"${module}\", \"status\": \"unloaded\", \"message\": \"Successfully unloaded module '${module}'\"}"
  exit 0
else
  if echo "${stderr}" | grep -qi "in use\|is in use\|Resource temporarily unavailable"; then
    echo "{\"_error\": {\"msg\": \"Module '${module}' is in use and cannot be unloaded\", \"kind\": \"dirty_frag/module-in-use\", \"details\": {\"module\": \"${module}\", \"stderr\": \"${stderr}\"}}}"
    exit 1
  else
    echo "{\"_error\": {\"msg\": \"Failed to unload module '${module}': ${stderr}\", \"kind\": \"dirty_frag/module-in-use\", \"details\": {\"module\": \"${module}\", \"stderr\": \"${stderr}\"}}}"
    exit 1
  fi
fi
