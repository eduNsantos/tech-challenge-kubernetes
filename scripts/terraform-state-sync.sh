#!/usr/bin/env bash
set -euo pipefail

BUCKET="tech-challenge-tfstate-477478162709"
KEY="eks/terraform.tfstate"
REGION="us-east-1"
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="$WORKDIR/terraform.tfstate"
TMP_FILE="$WORKDIR/.terraform.tfstate.tmp"

usage() {
  echo "Uso: $0 {push|pull|sync}"
  echo
  echo "  push   salva o state local no bucket S3"
  echo "  pull   baixa o state do bucket S3 para a máquina local"
  echo "  sync   baixa o state e depois envia o local para o S3"
}

require_aws() {
  command -v aws >/dev/null 2>&1 || {
    echo "Erro: aws CLI não está instalado ou não está no PATH." >&2
    exit 1
  }

  aws sts get-caller-identity >/dev/null 2>&1 || {
    echo "Erro: AWS CLI não está autenticado. Execute 'aws configure' ou configure as variáveis AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY." >&2
    exit 1
  }
}

push_state() {
  require_aws
  cd "$WORKDIR"
  terraform state pull > "$TMP_FILE"
  aws s3 cp "$TMP_FILE" "s3://$BUCKET/$KEY" --region "$REGION" --only-show-errors
  mv "$TMP_FILE" "$STATE_FILE"
  echo "State enviado para s3://$BUCKET/$KEY"
}

pull_state() {
  require_aws
  cd "$WORKDIR"
  mkdir -p "$WORKDIR"
  aws s3 cp "s3://$BUCKET/$KEY" "$STATE_FILE" --region "$REGION" --only-show-errors
  terraform init -reconfigure >/dev/null
  echo "State atualizado localmente em $STATE_FILE"
}

sync_state() {
  pull_state
  push_state
}

case "${1:-}" in
  push)
    push_state
    ;;
  pull)
    pull_state
    ;;
  sync)
    sync_state
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    usage
    exit 1
    ;;
 esac
