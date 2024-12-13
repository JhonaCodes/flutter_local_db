enum DBFile {
  globalIndex('global_index.json'),
  activeSubIndex('active_index.json'),
  manifest('manifest.toml');

  final String ext;
  const DBFile(this.ext);
}