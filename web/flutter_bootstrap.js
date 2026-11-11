{{flutter_js}}
{{flutter_build_config}}

// ZERO network calls at runtime: by default Flutter web downloads its
// CanvasKit renderer from Google's CDN. We point it at the local copy that
// `flutter build web` already puts in the build/canvaskit/ folder instead.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
