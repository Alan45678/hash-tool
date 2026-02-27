#!/usr/bin/env bash

if [ -t 1 ] && [ -c /dev/tty ] && [ -w /dev/tty ]; then
  _TTY_OUT=/dev/tty
else
  _TTY_OUT=/dev/stdout
fi

die() {
  echo "ERREUR : $*" >&2
  exit 1
}

say() {
  (( QUIET )) || echo "$@"
}

ui_progress_callback() {
  (( QUIET )) && return 0
  local i="$1" total_files="$2" bytes_done="$3" total_bytes="$4" eta_seconds="$5"
  local prefix=""
  [ "$_TTY_OUT" = "/dev/tty" ] && prefix="\r"

  if (( bytes_done > 0 && eta_seconds > 0 )); then
    printf "${prefix}[%d/%d] ETA : %dm %02ds   " \
      "$i" "$total_files" $(( eta_seconds / 60 )) $(( eta_seconds % 60 )) > "$_TTY_OUT"
  elif (( bytes_done > 0 )); then
    printf "${prefix}[%d/%d] calcul en cours...   " \
      "$i" "$total_files" > "$_TTY_OUT"
  fi
  
  if [ "$_TTY_OUT" = "/dev/stdout" ] && (( i % 50 == 0 )); then
    echo "" > "$_TTY_OUT"
  fi
}

ui_progress_clear() {
  (( QUIET )) && return 0
  if [ "$_TTY_OUT" = "/dev/tty" ]; then
    printf "\r%*s\r" 40 "" > "$_TTY_OUT"
  else
    echo "" > "$_TTY_OUT"
  fi
}

ui_show_verify_result() {
  local statut="$1" nb_ok="$2" nb_fail="$3" lines_fail="$4" lines_err="$5" outdir="$6"

  if [ "$statut" = "OK" ]; then
    say "Vérification OK - $nb_ok fichiers intègres."
  else
    say ""
    say "████████████████████████████████████████"
    if [ "$statut" = "ERREUR" ]; then
      say "  ERREUR lors de la vérification"
    else
      say "  ECHEC : $nb_fail fichier(s) corrompu(s) ou manquant(s)"
    fi
    say "████████████████████████████████████████"
    say ""
    [ -n "$lines_fail" ] && say "$lines_fail"
    [ -n "$lines_err"  ] && say "$lines_err"
    say ""
  fi

  say "Résultats dans : $outdir"
  say "  recap.txt"
  if (( nb_fail > 0 )) || [ -n "$lines_err" ]; then
    say "  failed.txt"
  fi
}

ui_show_compare_result() {
  local nb_mod="$1" nb_dis="$2" nb_nou="$3" outdir="$4"
  
  # L'ordre et le contenu de ces lignes sont CRITIQUES pour le TP10
  say "Résultats dans : $outdir"
  say "  recap.txt"
  say "  modifies.b3"
  say "  disparus.txt"
  say "  nouveaux.txt"
  
  # On ajoute les détails sur la ligne du recap pour l'utilisateur
  # mais sans casser la détection des fichiers au dessus
  say ""
  say "Bilan : modifiés: $nb_mod, disparus: $nb_dis, nouveaux: $nb_nou"
}