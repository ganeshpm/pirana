my $install_path = "c:\\pcluster";  # check this

use Win32::Registry;
my $reg_obj;

system "instsrv PDaemon ".$install_path."\\srvany.exe";
$::HKEY_LOCAL_MACHINE->Open("SYSTEM\\CurrentControlSet\\Services\\PDaemon", $reg_obj)
     or die "Can't open tips: $^E";
$reg_obj->Create("Parameters", $param_reg_obj);
print "Created key: ". $param_reg_obj."\n\n";
$param_reg_obj->SetValueEx("Application", "", REG_SZ, $install_path."\\pdaemon.exe");
print "Created registry value.\n\n";
    
print "If no error messages were shown above, PDaemon was installed correctly.\nYou can start the daemon by typing 'NET START PDaemon' in a console window."
