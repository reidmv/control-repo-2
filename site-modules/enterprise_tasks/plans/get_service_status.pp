plan enterprise_tasks::get_service_status(
  TargetSpec $target,
  String $service,
) {
  apply_prep($target)
  $status_hash = Hash(run_task(service::init, $target, action => 'status', name => $service).first().value())
  out::message("${service} resource service found in state: ${status_hash}")

  return $status_hash
  }
