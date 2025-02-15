enum FFiFunctions {
  createDb('create_db'),
  pushData('push_data'),
  getById('get_by_id'),
  getAll('get_all'),
  updateData('update_data'),
  delete('delete_by_id');

  final String cName;
  const FFiFunctions(this.cName);
}
