# Gym Swipe iOS

Proyecto iOS nativo que empaqueta la app React/Vite en un `WKWebView`.

## Regenerar la app web incluida

Desde la raiz del repositorio:

```bash
npm run build
rm -rf ios/WebDist
cp -R dist ios/WebDist
```

## Regenerar el proyecto Xcode

```bash
cd ios
xcodegen generate
open GymSwipeIOS.xcodeproj
```

Para compilar o ejecutar en simulador hace falta Xcode completo instalado y seleccionado con `xcode-select`.
