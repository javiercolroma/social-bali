# Gym Swipe iOS

App movil de entrenamiento construida con React, Vite y TypeScript. La experiencia principal es una sesion de entrenamiento con tarjetas tipo swipe, seguimiento por series, cronometro, sonidos, mascota, perfil, ranking, mapa y busqueda de partner.

## Desarrollo

```bash
npm install
npm run dev
```

## Validacion

```bash
npm run lint
npm run build
```

## Xcode / iOS

El proyecto iOS esta en `ios/GymSwipeIOS.xcodeproj`. Empaqueta la app web en un `WKWebView` nativo.

```bash
npm run ios:sync
npm run ios:generate
open ios/GymSwipeIOS.xcodeproj
```

Para compilar o ejecutar en simulador hace falta Xcode completo, no solo Command Line Tools.

## Memoria del proyecto

La memoria viva del producto, decisiones tecnicas, evolucion y siguientes pasos esta en:

```txt
MEMORIA_PROYECTO.md
```

## Produccion

```txt
https://gym-swipe-ios.vercel.app
```
