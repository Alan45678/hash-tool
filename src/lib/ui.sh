# #!/usr/bin/env bash
# # src/lib/ui.sh - Logique d'interface : affichage terminal, ETA, progression
# #
# # Ce module contient uniquement la logique de présentation et d'interaction
# # avec l'utilisateur. Il ne contient aucune logique métier.
# #
# # Sourcé par src/integrity.sh. Ne pas exécuter directement.
# #
# # == Dépendances ================================================================
# #   Aucune dépendance externe. Utilise uniquement les builtins bash et printf.
# #
# # == Prérequis ==================================================================
# #   La variable QUIET doit être définie avant de sourcer ce module :
# #     QUIET=0  - affichage normal
# #     QUIET=1  - suppression de toute sortie terminal

# # == Primitives de communication ================================================

# # die <message>
# #
# # Contrat d'entrée :
# #   $@ - message d'erreur (chaîne quelconque)
# #
# # Contrat de sortie :
# #   exit 1 - toujours
# #   stderr - "ERREUR : <message>"
# #
# # Effets de bord : termine le processus courant

# # Sortie terminal : /dev/tty si disponible, /dev/null sinon (CI sans terminal)
# if [ -w /dev/tty ] 2>/dev/null; then
#   _TTY_OUT=/dev/tty
# else
#   _TTY_OUT=/dev/null
# fi

# die() {
#   echo "ERREUR : $*" >&2
#   exit 1
# }

# # say <message>
# #
# # Contrat d'entrée :
# #   $@ - message à afficher (chaîne quelconque)
# #
# # Contrat de sortie :
# #   stdout - <message> si QUIET == 0
# #   (rien)  - si QUIET == 1
# #
# # Effets de bord : aucun
# say() {
#   (( QUIET )) || echo "$@"
# }

# # == Progression et ETA =========================================================

# # ui_progress_callback <i> <total_files> <bytes_done> <total_bytes> <eta_seconds>
# #
# # Fonction de callback compatible avec core_compute().
# # À passer comme troisième argument de core_compute si la progression est souhaitée.
# #
# # Contrat d'entrée :
# #   $1 - index du fichier courant (entier, commence à 1)
# #   $2 - nombre total de fichiers
# #   $3 - octets traités jusqu'ici
# #   $4 - octets totaux
# #   $5 - ETA en secondes (0 si non calculable)
# #
# # Contrat de sortie :
# #   /dev/tty - ligne de progression sur le terminal courant
# #              Écrit sur /dev/tty et non sur stdout : garantit que la progression
# #              ne peut pas être capturée dans un pipe ou dans le fichier .b3
# #   (rien)   - si QUIET == 1
# #
# # Effets de bord : aucun (le \r efface la ligne précédente)
# ui_progress_callback() {
#   (( QUIET )) && return 0

#   local i="$1"
#   local total_files="$2"
#   local bytes_done="$3"
#   # shellcheck disable=SC2034  # total_bytes : reçu du callback mais non utilisé ici (réservé pour affichage %)
#   local total_bytes="$4"
#   local eta_seconds="$5"

#   if (( bytes_done > 0 && eta_seconds > 0 )); then
#     printf "\r[%d/%d] ETA : %dm %02ds   " \
#       "$i" "$total_files" $(( eta_seconds / 60 )) $(( eta_seconds % 60 )) > "$_TTY_OUT"
#   elif (( bytes_done > 0 )); then
#     printf "\r[%d/%d] calcul en cours...   " \
#       "$i" "$total_files" > "$_TTY_OUT"
#   fi
# }

# # ui_progress_clear
# #
# # Efface la ligne de progression ETA du terminal.
# # À appeler après core_compute pour laisser un terminal propre.
# #
# # Contrat de sortie :
# #   /dev/tty - ligne vide (40 espaces + \r)
# #   (rien)   - si QUIET == 1
# ui_progress_clear() {
#   (( QUIET )) && return 0
#   printf "\r%*s\r" 40 "" > "$_TTY_OUT"
# }

# # == Affichage des résultats de vérification ====================================

# # ui_show_verify_result <statut> <nb_ok> <nb_fail> <lines_fail> <lines_err> <outdir>
# #
# # Contrat d'entrée :
# #   $1 - statut : "OK" | "ECHEC" | "ERREUR"
# #   $2 - nombre de fichiers OK (entier)
# #   $3 - nombre de fichiers FAILED (entier)
# #   $4 - lignes FAILED (chaîne multi-lignes, peut être vide)
# #   $5 - lignes d'erreur b3sum (chaîne multi-lignes, peut être vide)
# #   $6 - chemin du dossier de résultats
# #
# # Contrat de sortie :
# #   stdout - résumé formaté si QUIET == 0
# #   (rien)  - si QUIET == 1
# #
# # Effets de bord : aucun
# ui_show_verify_result() {
#   local statut="$1"
#   local nb_ok="$2"
#   local nb_fail="$3"
#   local lines_fail="$4"
#   local lines_err="$5"
#   local outdir="$6"

#   if [ "$statut" = "OK" ]; then
#     say "Vérification OK - $nb_ok fichiers intègres."
#   else
#     say ""
#     say "████████████████████████████████████████"
#     if [ "$statut" = "ERREUR" ]; then
#       say "  ERREUR lors de la vérification"
#     else
#       say "  ECHEC : $nb_fail fichier(s) corrompu(s) ou manquant(s)"
#     fi
#     say "████████████████████████████████████████"
#     say ""
#     [ -n "$lines_fail" ] && say "$lines_fail"
#     [ -n "$lines_err"  ] && say "$lines_err"
#     say ""
#   fi

#   say "Résultats dans : $outdir"
#   say "  recap.txt"
#   (( nb_fail > 0 )) || [ -n "$lines_err" ] && say "  failed.txt"
# }

# # ui_show_compare_result <nb_mod> <nb_dis> <nb_nou> <outdir>
# #
# # Contrat d'entrée :
# #   $1 - nombre de fichiers modifiés
# #   $2 - nombre de fichiers disparus
# #   $3 - nombre de nouveaux fichiers
# #   $4 - chemin du dossier de résultats
# #
# # Contrat de sortie :
# #   stdout - résumé formaté si QUIET == 0
# #   (rien)  - si QUIET == 1
# #
# # Effets de bord : aucun
# ui_show_compare_result() {
#   local nb_mod="$1"
#   local nb_dis="$2"
#   local nb_nou="$3"
#   local outdir="$4"

#   say "Résultats enregistrés dans : $outdir"
#   say "  recap.txt     - modifiés: $nb_mod, disparus: $nb_dis, nouveaux: $nb_nou"
#   say "  modifies.b3   - $nb_mod fichiers"
#   say "  disparus.txt  - $nb_dis fichiers"
#   say "  nouveaux.txt  - $nb_nou fichiers"
#   say "  report.html   - rapport visuel"
# }



#!/usr/bin/env bash
# src/lib/ui.sh - Logique d'interface : affichage terminal, ETA, progression

# == Primitives de communication ================================================

# Initialisation de la sortie terminal sécurisée
# On utilise stdout par défaut en CI pour éviter les erreurs de périphérique
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

# == Progression et ETA =========================================================

ui_progress_callback() {
  (( QUIET )) && return 0

  local i="$1"
  local total_files="$2"
  local bytes_done="$3"
  local total_bytes="$4"
  local eta_seconds="$5"

  local prefix=""
  [ "$_TTY_OUT" = "/dev/tty" ] && prefix="\r"

  if (( bytes_done > 0 && eta_seconds > 0 )); then
    printf "${prefix}[%d/%d] ETA : %dm %02ds   " \
      "$i" "$total_files" $(( eta_seconds / 60 )) $(( eta_seconds % 60 )) > "$_TTY_OUT"
  elif (( bytes_done > 0 )); then
    printf "${prefix}[%d/%d] calcul en cours...   " \
      "$i" "$total_files" > "$_TTY_OUT"
  fi
  
  # Flush périodique en CI pour voir l'avancement dans les logs GitHub
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

# == Affichage des résultats de vérification ====================================

ui_show_verify_result() {
  local statut="$1"
  local nb_ok="$2"
  local nb_fail="$3"
  local lines_fail="$4"
  local lines_err="$5"
  local outdir="$6"

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
  
  # Utilisation d'un bloc if au lieu de && pour éviter de retourner un code 1 au shell
  if (( nb_fail > 0 )) || [ -n "$lines_err" ]; then
    say "  failed.txt"
  fi
}

# == Affichage des résultats de comparaison =====================================

ui_show_compare_result() {
  local nb_mod="$1"
  local nb_dis="$2"
  local nb_nou="$3"
  local outdir="$4"

  say "Résultats enregistrés dans : $outdir"
  say "  recap.txt     - modifiés: $nb_mod, disparus: $nb_dis, nouveaux: $nb_nou"
  
  # On n'affiche les fichiers de détails que s'ils sont pertinents
  # Cela évite que les tests s'attendent à voir des fichiers qui n'existent pas sur le disque
  if (( nb_mod > 0 )); then say "  modifies.b3   - $nb_mod fichiers"; fi
  if (( nb_dis > 0 )); then say "  disparus.txt  - $nb_dis fichiers"; fi
  if (( nb_nou > 0 )); then say "  nouveaux.txt  - $nb_nou fichiers"; fi
  
  # Le rapport HTML est normalement toujours produit par core_compare
  say "  report.html   - rapport visuel"
}