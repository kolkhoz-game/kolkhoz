window.kolkhozEngineReady = createKolkhozEngine({
  locateFile(path) {
    return new URL(path, document.baseURI).toString();
  },
}).then((module) => {
  window.kolkhozEngineModule = module;
});

window.kolkhozEngineCall = function kolkhozEngineCall(name, args) {
  const module = window.kolkhozEngineModule;
  if (!module) {
    throw new Error("Kolkhoz WebAssembly engine is not ready");
  }
  return module.ccall(name, "number", args.map(() => "number"), args);
};
