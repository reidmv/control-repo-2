# Ensures that the given message outputs both to the console and to the log.
function enterprise_tasks::message(
  String $plan,
  String $message,
) {
  $output = "${capitalize($plan)}: ${message}"
  notice($output)
  out::message($output)
}
