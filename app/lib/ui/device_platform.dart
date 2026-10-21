import 'device_platform_stub.dart'
    if (dart.library.io) 'device_platform_io.dart'
    as impl;

bool get notificationsSupported => impl.notificationsSupported;

bool get biometricsSupported => impl.biometricsSupported;
