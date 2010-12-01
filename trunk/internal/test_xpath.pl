foreach(@INC) {
  $lib = $_;
  chdir($lib);
  @dir = <*>;
  if (-d "XML") {
     chdir "XML";
     @dir2 = <*>;
     foreach(@dir2) {
       if($_ =~ m/XPath/i ) {print $lib."/XML/".$_."\n";};
     }
  } 
}
