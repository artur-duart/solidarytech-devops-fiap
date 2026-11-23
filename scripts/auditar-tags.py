import json
import subprocess
import sys
from collections import Counter

OBRIGATORIAS = ("Project", "Environment", "CostCenter", "Owner", "ManagedBy", "Stack")
REGIAO = sys.argv[1] if len(sys.argv) > 1 else "us-east-1"


def recursos():
    token = ""
    while True:
        cmd = ["aws", "resourcegroupstaggingapi", "get-resources", "--region", REGIAO, "--output", "json"]
        if token:
            cmd += ["--pagination-token", token]
        pagina = json.loads(subprocess.run(cmd, capture_output=True, text=True, check=True).stdout)
        yield from pagina["ResourceTagMappingList"]
        token = pagina.get("PaginationToken")
        if not token:
            break


def tipo(arn):
    partes = arn.split(":")
    servico, resto = partes[2], partes[5]
    return f"{servico}:{resto.split('/')[0]}"


def main():
    conformes, faltando = Counter(), []
    for recurso in recursos():
        tags = {t["Key"]: t["Value"] for t in recurso.get("Tags", [])}
        do_projeto = tags.get("Project") == "SolidaryTech"
        do_cluster = any("solidarytech" in f"{k}={v}".lower() for k, v in tags.items())
        if not (do_projeto or do_cluster):
            continue
        ausentes = [k for k in OBRIGATORIAS if k not in tags]
        if ausentes:
            faltando.append((recurso["ResourceARN"], ausentes))
        else:
            conformes[tipo(recurso["ResourceARN"])] += 1

    total = sum(conformes.values()) + len(faltando)
    print(f"Recursos avaliados: {total}")
    print(f"Com todas as tags obrigatórias: {sum(conformes.values())}")
    for t, n in sorted(conformes.items()):
        print(f"  {n:3}  {t}")
    if faltando:
        print(f"\nSem alguma tag obrigatória: {len(faltando)}")
        for arn, ausentes in faltando:
            print(f"  {arn}\n       faltam: {', '.join(ausentes)}")
    cobertura = 100 * sum(conformes.values()) / total if total else 100
    print(f"\nCobertura de tags: {cobertura:.1f}%")
    sys.exit(0 if not faltando else 1)


if __name__ == "__main__":
    main()
