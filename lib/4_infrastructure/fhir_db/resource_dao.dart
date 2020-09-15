import 'package:fhir/fhir_r4.dart';
import 'package:sembast/sembast.dart';

import 'fhir_db.dart';
part 'resource_dao_save.dart';

class ResourceDao {
  ResourceDao();

  StoreRef<String, Map<String, dynamic>> _resourceStore;

  void _setStoreType(String resourceType) {
    _addResourceType(resourceType);
    _resourceStore = stringMapStoreFactory.store(resourceType);
  }

  Future<Database> get _db async => FhirDb.instance.database;
  void _addResourceType(String resourceType) =>
      FhirDb.instance.addResourceType(resourceType);
  void _removeResourceType(String resourceType) =>
      FhirDb.instance.removeResourceType(resourceType);
  List<String> _getResourceTypes() => FhirDb.instance.getResourceTypes();

  //checks if the resource already has an id, all resources downloaded should
  //have an id, and all resources already saved will have an id, so only brand
  //spanking new resources won't
  Future<Resource> save(Resource resource) async {
    if (resource != null && resource?.resourceType != null) {
      _setStoreType(resource.resourceType);
      return resource.id == null
          ? await _insert(resource)
          : await _update(resource);
    }
    throw const FormatException('Resource to save cannot be null');
  }

  //if no id, it will call _getIdAndMeta to provide the new (local, temporary
  // id) along with creating a metadata about the resource history
  Future<Resource> _insert(Resource resource) async {
    final _newResource = _getIdAndMeta(resource);
    await _resourceStore
        .record(_newResource.id.toString())
        .put(await _db, _newResource.toJson());
    return _newResource;
  }

  Future<Resource> _update(Resource resource) async {
    final finder = Finder(filter: Filter.byKey(resource.id.toString()));
    final oldResource =
        await _resourceStore.record(resource.id.toString()).get(await _db);
    if (oldResource == null) {
      await _resourceStore
          .record(resource.id.toString())
          .put(await _db, resource.toJson());
      return resource;
    } else {
      _setStoreType('_history');
      await _resourceStore.add(await _db, oldResource);
      _setStoreType(resource.resourceType);
      final oldMeta =
          Meta.fromJson(oldResource['meta'] as Map<String, dynamic>);
      final _newResource = _newVersion(resource, oldMeta: oldMeta);
      await _resourceStore.update(await _db, _newResource.toJson(),
          finder: finder);
      return _newResource;
    }
  }

  Future find({Resource resource, Finder oldFinder}) async {
    final finder =
        oldFinder ?? Finder(filter: Filter.equals('id', '${resource.id}'));
    _setStoreType(resource.resourceType);
    return _search(finder);
  }

  Future delete(Resource resource) async {
    _setStoreType(resource.resourceType);
    final finder = Finder(filter: Filter.equals('id', '${resource.id}'));
    await _resourceStore.delete(await _db, finder: finder);
  }

  Future deleteSingleType({String resourceType, Resource resource}) async {
    final type = resourceType ?? resource?.resourceType ?? '';
    if (type.isNotEmpty) {
      await _deleteType(type);
    }
  }

  Future deleteAllResources() async {
    final resourceTypes = _getResourceTypes();
    print(resourceTypes);
    resourceTypes.forEach(_deleteType);
    // for (var type in resourceTypes) {
    //   await _deleteType(type);
    // }
  }

  Future _deleteType(String resourceType) async {
    _setStoreType(resourceType);
    await _resourceStore.delete(await _db);
    _removeResourceType(resourceType);
  }

  Future<List<Resource>> getAllResources() async {
    final resourceTypes = _getResourceTypes();
    final resourceList = <Resource>[];
    for (final resource in resourceTypes) {
      final partialList = await getAllSortedById(resourceType: resource);
      partialList.forEach(resourceList.add);
    }
    return resourceList;
  }

  Future<List<Resource>> getAllSortedById(
      {String resourceType, Resource resource}) async {
    final type = resourceType ?? resource?.resourceType ?? '';
    if (type.isNotEmpty) {
      _setStoreType(type);
      final finder = Finder(sortOrders: [SortOrder('id')]);
      return _search(finder);
    }
    return [];
  }

  Future<List<Resource>> searchFor(
      String resourceType, String field, String value) async {
    _setStoreType(resourceType);
    final finder = Finder(filter: Filter.equals(field, value));
    return await _search(finder);
  }

  Future<List<Resource>> _search(Finder finder) async {
    final recordSnapshots =
        await _resourceStore.find(await _db, finder: finder);

    return recordSnapshots.map((snapshot) {
      final resource = Resource.fromJson(snapshot.value);
      return resource;
    }).toList();
  }
}