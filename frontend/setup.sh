#!/bin/sh
# Ejecutar una sola vez tras clonar el repositorio
echo "Configurando git hooks..."
git config core.hooksPath .githooks
echo "Instalando paquetes Flutter..."
flutter pub get
echo "Listo. Ya puedes usar flutter run."
