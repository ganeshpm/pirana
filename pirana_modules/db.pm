# Subroutines for connecting with the databases (pirana.dir) in the active folder

package pirana_modules::db;

use strict;
use File::stat;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(check_db_file_correct db_rename_model db_get_project_info db_insert_project_info db_create_tables db_log_execution db_insert_model_info db_insert_table_info db_read_exec_runs db_read_model_info db_read_table_info delete_run_results db_add_note db_add_color db_read_all_model_data db_execute db_execute_multiple);

our $db_name = "pirana.dir";
our $dbargs = {AutoCommit => 0, PrintError => 1};

sub check_db_file_correct {
### Purpose : Deletes pirana.dir if size = 0 b.
### Compat  : W+L+
    if (-e $db_name) {
	if (-s $db_name == 0) {
	    unlink ($db_name);
	}
    }
}

sub db_rename_model {
### Purpose : Get project info from database
### Compat  : W+L+
    my ($old, $new) = @_;
    db_execute ("UPDATE model_db SET model_id='".$new."' WHERE model_id='".$old."'");
    return (1);
}

sub db_get_project_info {
### Purpose : Get project info from database
### Compat  : W+L+
  my $sql = "SELECT proj_name, descr, modeler, collaborators, start_date, end_date, notes FROM project_info LIMIT 1;";
  my $dbargs = {AutoCommit => 0, PrintError => 1};
  my $db = DBI->connect("dbi:SQLite:dbname=".$db_name,"","",$dbargs);
  my $db_results = $db -> selectall_arrayref($sql);
    $db -> disconnect ();
  return($db_results);
}

sub db_insert_project_info {
### Purpose : Insert project info into database
### Compat  : W+L+
  my $proj_record_ref = shift;
  my %proj_record = %$proj_record_ref;
  my $keys = join (",", keys(%proj_record));
  my $values;
  foreach my $key (keys(%proj_record)) {
    $values .= "'".$proj_record{$key}."',";
  }
  chop ($values);
  my $sql = "INSERT INTO project_info (".$keys.") VALUES (".$values.")";
  db_execute ($sql);
}

sub db_create_tables {
### Purpose : Create tables in the db(pirana.dir) if they are not already created
### Compat  : W+L+
  my @tables = (
    "CREATE TABLE IF NOT EXISTS model_db (".
      "model_id VARCHAR(20), date_mod INTEGER, date_res INTEGER, ref_mod VARCHAR(20), ".
      "descr VARCHAR(80), method VARCHAR(12), ofv DOUBLE, suc VARCHAR(2), cov VARCHAR(2), bnd VARCHAR(2), sig VARCHAR(4), ".
      "note TEXT, note_small VARCHAR(80), note_color VARCHAR(9), dataset VARCHAR(40)) ",
   # "ALTER TABLE model_db ADD COLUMN dataset VARCHAR(60)",
    "CREATE TABLE IF NOT EXISTS table_db (".
      "table_id VARCHAR(50), date_mod INTEGER, ref_table VARCHAR(50), descr VARCHAR(160), ".
      "creator VARCHAR(40), link_to_script VARCHAR(80), note TEXT, table_color VARCHAR(9)) ",
    "CREATE TABLE IF NOT EXISTS executed_runs (".
      "model_id VARCHAR(20), descr VARCHAR(80), date_executed INTEGER, name_modeler VARCHAR(30), nm_version VARCHAR(20), ".
      "method VARCHAR(12), exec_where VARCHAR(16), command VARCHAR(120)) ",
    "CREATE TABLE IF NOT EXISTS project_info (".
      "proj_name VARCHAR(50), descr VARCHAR(120), modeler VARCHAR(40), collaborators VARCHAR (80), start_date INTEGER, ".
      "end_date INTEGER, notes TEXT, tstamp TIMESTAMP)",
    "INSERT INTO project_info (proj_name, descr, modeler, collaborators, start_date, end_date, notes) VALUES (".
      "('', '', '', '', '', '', '')");
  if (-w "./") {db_execute_multiple(\@tables);}
}

sub db_log_execution {
### Purpose : Log the starting of runs/PsN-commands to a the database
### Compat  : W+L+
  my ($model, $descr, $nm_type, $where, $command, $modeler) = @_;
  my $datetime = gmtime();
  my $SQL = "INSERT INTO executed_runs (model_id, descr, date_executed, name_modeler, method, exec_where, command) VALUES ".
    "('$model', '$descr', '$datetime', '$modeler', '$nm_type', '$where', '$command')";
  db_execute ($SQL);
}

sub delete_run_results {
### Purpose : Delete a NM results file, and delete the results from the database
### Compat  : W+L+
  my $mod = shift;
  status ("Deleting model results for run ".$mod);
  db_execute ("DELETE FROM model_db WHERE model_id='".$mod."'");
}

sub db_add_note {
### Purpose : Add a note for a model to the sqlite database (pirana.dir)
### Compat  : W+L+
  my ($model, $note) = @_;
  if (-w "./") {
    my $db = DBI->connect("dbi:SQLite:dbname=".$db_name,"","",$dbargs);
    $db -> do("UPDATE model_db SET note='".$note."' WHERE model_id='".$model."'");
    $db -> commit();
    $db -> disconnect ();
  }
}

sub db_execute {
### Purpose : Execute an SQL command on the database
### Compat  : W+L+
  my $db_command = shift;
  if (-w "./") {
    my $db = DBI->connect("dbi:SQLite:dbname=".$db_name,"","",$dbargs);
    $db -> do($db_command);
    $db -> commit();
    $db -> disconnect ();
  }
}
sub db_execute_multiple {
### Purpose : Execute several SQL command on the database and commit afterwards (to save speed)
### Compat  : W+L+
  my $db_commands_ref = shift;
  my @db_commands = @$db_commands_ref;
  if (-w "./") {
    our $dbargs = {AutoCommit => 0, PrintError => 0};
    my $db = DBI->connect("dbi:SQLite:dbname=".$db_name,"","",$dbargs);
    foreach(@db_commands) {
      $db -> do($_);
    }
    $db -> commit();
    $db -> disconnect ();
  }
}
sub db_insert_table_info {
### Purpose : Inserts table information into db (notes/creator etc)
### Compat  : W+L+
  my ($file, $descr, $creator, $note, $update) = @_;
  if ($update == 1) {
    db_execute ("UPDATE table_db SET descr='$descr', creator='$creator', note='$note' WHERE table_id='$file'");
  } else {
    db_execute ("INSERT INTO table_db (table_id, descr, creator, note) VALUES ('$file', '$descr', '$creator', '$note')");
  }
}

sub db_insert_model_info {
### Purpose : Inserts model information into db (notes/description etc)
### Compat  : W+L+
  my ($model_id, $descr, $note) = @_;
  db_execute ("UPDATE model_db SET descr='$descr', note='$note' WHERE model_id='$model_id'");
}

sub db_add_color {
### Purpose : Add the color that is chosen for a model/results to the database
### Compat  : W+L+
  if (-w "./") {
    my ($model, $color) = @_;
    if ($color eq "#ffffff") {$color = ""};
    my $db = DBI->connect("dbi:SQLite:dbname=".$db_name,"","",$dbargs);
    $db -> do("UPDATE model_db SET note_color='".$color."' WHERE model_id='".$model."'");
    $db -> commit();
    $db -> disconnect ();
  }
}

sub db_read_exec_runs {
### Purpose : Read executed run list from DB and return array-ref
### Compat  : W+L+
  if (-e $db_name) {
    my $dbargs = {AutoCommit => 0, PrintError => 1};
    my $db = DBI->connect("dbi:SQLite:dbname=".$db_name,"","",$dbargs);
    my $db_results = $db -> selectall_arrayref("SELECT model_id, descr, date_executed, name_modeler, nm_version, ".
       "method, exec_where, command FROM executed_runs ORDER BY date_executed DESC" );
    $db -> disconnect ();
    return($db_results);
  }
}
sub db_read_table_info {
### Purpose : Read table info (notes / creator / etc.)
### Compat  : W+L+
  if (-e $db_name) {
    my $dbargs = {AutoCommit => 0, PrintError => 1};
    my $db = DBI->connect("dbi:SQLite:dbname=".$db_name,"","",$dbargs);
    my $db_results = $db -> selectall_arrayref("SELECT table_id, descr, note, creator FROM table_db" );
    $db -> disconnect ();
    return($db_results)
  }
}
sub db_read_model_info {
### Purpose : Read table info (notes / creator / etc.) of one specific model
### Compat  : W+L+
  if (-e $db_name) {
    my $model = shift;
    my $dbargs = {AutoCommit => 0, PrintError => 1};
    my $db = DBI->connect("dbi:SQLite:dbname=".$db_name,"","",$dbargs);
    my $db_results = $db -> selectall_arrayref("SELECT model_id, ref_mod, descr, note_small, note FROM model_db WHERE model_id='$model'" );
    $db -> disconnect ();
    return($db_results);
  }
}

sub db_read_all_model_data {
### Purpose : Read model info from the sqlite database (pirana.dir)
### Compat  : W+L+
  if (-e $db_name) {
    our %models_db = {}; our %models_notes = {}; our %models_colors = {};
    my $db = DBI->connect("dbi:SQLite:dbname=".$db_name,"","",$dbargs);
    my $all = $db -> selectall_arrayref(
       "SELECT model_id, date_mod, date_res, ref_mod, descr, method, ".
       "ofv, suc, cov, bnd, sig, note, note_color, dataset ".
       "FROM model_db"
    );
    my %models_dates_db; my %models_resdates_db; my %models_refmod; my %models_descr;
    my %models_method; my %models_ofv; my %models_suc; my %models_bnd; my %models_cov;
    my %models_sig; my %models_notes; my %models_colors; my $model; my %models_dataset;
    foreach my $row (@$all) {
      my ($model, $date_mod, $date_res, $ref_mod, $descr, $method,
        $ofv, $suc, $cov, $bnd, $sig, $note, $note_color, $dataset) = @$row;
      $sig =~ s/^\s+//; #remove leading spaces
      $models_dates_db {$model} = $date_mod;
      $models_resdates_db {$model} = $date_res;
      $models_refmod {$model} = $ref_mod;
      $models_descr {$model} = $descr;
      $models_method {$model} = $method;
      $models_ofv {$model} = $ofv;
      $models_suc {$model} = $suc;
      $models_bnd {$model} = $bnd;
      $models_cov {$model} = $cov;
      $models_sig {$model} = $sig;
      $models_notes {$model} = $note;
      $models_colors {$model} = $note_color;
      $models_dataset {$model} = $dataset;
    }
    $db -> commit();
    $db -> disconnect ();
    return ( \%models_dates_db, \%models_resdates_db,  \%models_refmod, \%models_descr,
       \%models_method, \%models_ofv, \%models_suc, \%models_bnd, \%models_cov,
       \%models_sig, \%models_notes, \%models_colors, \%models_dataset)
  }
}
1;
