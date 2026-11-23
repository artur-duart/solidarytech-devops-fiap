import re
import sys
from pathlib import Path

INFRA = Path(__file__).resolve().parent.parent / "infra"
CHAVES_OBRIGATORIAS = ("Project", "Environment", "CostCenter", "Owner", "ManagedBy", "Stack")
PROPAGACAO_MAIN = {
    "launch_template_tags = local.tags": "tags nas instâncias e discos dos nós (launch template)",
    "extraVolumeTags = local.tags": "tags nos volumes EBS criados pelo Kubernetes",
    "defaultTags = local.tags": "tags no load balancer e recursos do AWS Load Balancer Controller",
}


def ler_stack(pasta):
    return "\n".join(f.read_text(encoding="utf-8") for f in sorted(pasta.glob("*.tf")))


def blocos_provider_aws(codigo):
    return re.findall(r'provider\s+"aws"\s*\{(.*?)\n\}', codigo, flags=re.S)


def verificar(pasta):
    erros = []
    codigo = ler_stack(pasta)

    if not re.search(r'module\s+"finops_tags"\s*\{[^}]*source\s*=\s*"\.\./modules/finops-tags"', codigo, flags=re.S):
        erros.append("não usa o módulo ../modules/finops-tags")

    providers = blocos_provider_aws(codigo)
    if not providers:
        erros.append("não declara provider aws")
    for bloco in providers:
        if not re.search(r"default_tags\s*\{\s*tags\s*=\s*(module\.finops_tags\.tags|local\.tags)", bloco):
            erros.append("provider aws sem default_tags vindas do módulo de tags")

    for chave in CHAVES_OBRIGATORIAS:
        if re.search(rf"^\s*{chave}\s*=", codigo, flags=re.M):
            erros.append(f"a tag {chave} está escrita à mão, fora do módulo")

    if pasta.name == "main":
        compacto = re.sub(r"\s+", " ", codigo)
        for trecho, descricao in PROPAGACAO_MAIN.items():
            if trecho not in compacto:
                erros.append(f"falta propagar {descricao}")

    return erros


def main():
    stacks = [p for p in sorted(INFRA.iterdir()) if p.is_dir() and p.name != "modules" and not p.name.startswith((".", "_"))]
    falhou = False
    for pasta in stacks:
        erros = verificar(pasta)
        if erros:
            falhou = True
            for erro in erros:
                print(f"REPROVADO infra/{pasta.name}: {erro}")
        else:
            print(f"ok        infra/{pasta.name}")
    sys.exit(1 if falhou else 0)


if __name__ == "__main__":
    main()
