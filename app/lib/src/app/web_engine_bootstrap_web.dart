import 'dart:js_interop';

@JS('kolkhozEngineReady')
external JSPromise<JSAny?> get _kolkhozEngineReady;

Future<void> initializeKolkhozWebEngine() async {
  await _kolkhozEngineReady.toDart;
}
