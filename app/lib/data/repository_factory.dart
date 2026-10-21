import 'repository.dart';
import 'repository_factory_stub.dart'
    if (dart.library.io) 'repository_factory_io.dart'
    as impl;

Future<Repository> createRepository() => impl.createRepository();
