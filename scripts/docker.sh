#!/usr/bin/env bash
#
# Docker utilities.
#
# This should only be sourced, not executed directly
[[ -n "$BASH_VERSION" ]] || fatal "This file must be sourced from bash."
[[ "$(caller 2>/dev/null | awk '{print $1}')" != "0" ]] || fatal "This file must be sourced, not executed."

# -----------------------------------------------------------------------------

# waits for the container to be in a healthy condition.
# https://github.com/docker/compose/issues/8351#issuecomment-851115217
docker_wait_for_healthy_service() {
  local service_name="$1"
  local container_id=$(docker compose ps $service_name -q)
  info "waiting for ${service_name} service$(log_key container_id $container_id)"
  local wait=1
  while [[ $wait -eq 1 ]]; do
    local container_state="$(docker inspect "${container_id}" --format '{{ .State.Status }}')"
    if [[ "$container_state" == "running" ]]; then
      local health_status="$(docker inspect "${container_id}" --format '{{ .State.Health.Status }}')"
      info "${service_name}$(log_key container_state $container_state)$(log_key health_status $health_status)"
      if [[ ${health_status} == "healthy" ]]; then
        wait=0
      fi
    else
      info "${service_name}$(log_key container_state $container_state)"
      wait=0
    fi
    sleep 2;
  done;
}

function docker_compose() {
  docker compose -f docker-compose.yml "$@"
}
