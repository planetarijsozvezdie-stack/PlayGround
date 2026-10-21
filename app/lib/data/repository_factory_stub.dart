import 'memory_repository.dart';
import 'repository.dart';

Future<Repository> createRepository() => MemoryRepository.create();
