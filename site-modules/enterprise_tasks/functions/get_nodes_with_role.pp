function enterprise_tasks::get_nodes_with_role(String $role){
  if $role == 'pe_compiler' {
    $query = "nodes[certname] { facts { name='trusted' and value ~ 'pp_role.*pe_compiler' } and deactivated is null and expired is null }"
  } else {
    $myrole = capitalize($role)
    $query = "nodes[certname] { resources { type = 'Class' and title = 'Puppet_enterprise::Profile::${myrole}' } and deactivated is null and expired is null }"
  }
  puppetdb_query($query).map |$node| { $node['certname'] }
}