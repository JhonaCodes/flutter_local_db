enum DBDirectory {
  localDatabase('local_database', 'local_database'),
  active('/active','/local_database/active'),
  sealed('/sealed','/local_database/sealed'),
  secure('/secure','/local_database/secure'),
  backup('/backup','/local_database/backup'),
  historical('/historical','/local_database/historical'),
  sync('/sync','/local_database/sync');

  final String path;
  final String fullPath;
  const DBDirectory(this.path, this.fullPath);

}