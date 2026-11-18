#!/usr/bin/env bash
# Verifica que el proyecto cargue sin errores y que pasen las pruebas (headless).
# Uso: tools/verificar.sh   (requiere el binario de Godot 4.7.2 como "godot" o en $GODOT)
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
LOG="$(mktemp)"
fallo=0

echo "== Importando proyecto =="
"$GODOT" --headless --path . --import >"$LOG" 2>&1 || true
if grep -E "SCRIPT ERROR|Parse Error|ERROR:" "$LOG" | grep -v "ObjectDB" ; then
  echo "!! Errores al importar"; fallo=1
fi

echo "== Pruebas de combate =="
if ! "$GODOT" --headless --path . -s res://tests/pruebas.gd >"$LOG" 2>&1; then
  cat "$LOG"; echo "!! Fallan las pruebas"; fallo=1
else
  grep "Resultado" "$LOG"
fi
if grep -E "SCRIPT ERROR|Parse Error|^ERROR" "$LOG"; then fallo=1; fi

echo "== Pruebas del repertorio =="
if ! "$GODOT" --headless --path . -s res://tests/pruebas_repertorio.gd >"$LOG" 2>&1; then
  cat "$LOG"; echo "!! Fallan las pruebas del repertorio"; fallo=1
else
  grep "Resultado" "$LOG"
fi
if grep -E "SCRIPT ERROR|Parse Error|^ERROR" "$LOG"; then fallo=1; fi

echo "== Pruebas de personaje =="
if ! "$GODOT" --headless --path . -s res://tests/pruebas_personaje.gd >"$LOG" 2>&1; then
  cat "$LOG"; echo "!! Fallan las pruebas de personaje"; fallo=1
else
  grep "Resultado" "$LOG"
fi
if grep -E "SCRIPT ERROR|Parse Error|^ERROR" "$LOG"; then fallo=1; fi

echo "== Prueba de red local (servidor + 2 bots por localhost) =="
if ! timeout 120 "$GODOT" --headless --path . -s res://tests/red.gd >"$LOG" 2>&1; then
  cat "$LOG"; echo "!! Falla la prueba de red"; fallo=1
else
  grep "Resultado" "$LOG"
fi
if grep -E "SCRIPT ERROR|Parse Error|^ERROR" "$LOG"; then fallo=1; fi

echo "== Prueba de humo (menú + partida) =="
"$GODOT" --headless --path . -s res://tests/humo.gd >"$LOG" 2>&1
codigo=$?
grep -E "HUMO" "$LOG"
if [ $codigo -ne 0 ] || grep -E "SCRIPT ERROR|Parse Error|^ERROR" "$LOG"; then
  cat "$LOG" | tail -40; echo "!! La prueba de humo falló"; fallo=1
fi

rm -f "$LOG"
if [ $fallo -ne 0 ]; then echo "VERIFICACIÓN FALLIDA"; exit 1; fi
echo "VERIFICACIÓN CORRECTA"
