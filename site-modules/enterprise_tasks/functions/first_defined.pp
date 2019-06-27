# Return the first non-empty element of the given list of args.
function enterprise_tasks::first_defined(
  Array *$args,
) {
  $defined = $args.filter |$i| {
    !empty($i)
  }[0]
}
