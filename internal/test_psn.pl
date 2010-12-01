foreach(@INC) {
  $lib = $_;
  chdir($lib);
  @dir = <*>;
  foreach(@dir) {
    if($_ =~ m/PsN_/ && !($_=~ m/.pm/) ) {print $lib."/".$_."\n"};
  }
}
