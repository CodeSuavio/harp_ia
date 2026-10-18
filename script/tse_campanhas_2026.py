"""Agrega votos, receitas e despesas contratadas dos candidatos a Deputado Federal 2026.

Baixe em <dir>:
  votacao.zip = https://cdn.tse.jus.br/estatistica/sead/odsele/votacao_candidato_munzona/votacao_candidato_munzona_2026.zip
  contas.zip  = https://cdn.tse.jus.br/estatistica/sead/odsele/prestacao_contas/prestacao_de_contas_eleitorais_candidatos_2026.zip
Uso: python3 -I script/tse_campanhas_2026.py <dir> db/seed_data/campanhas_2026.json.gz
Lê os zips em streaming (o CSV de votação do Brasil tem mais de 3 GB), sem extrair.
"""
import csv
import gzip
import io
import json
import sys
import zipfile
from collections import defaultdict
from datetime import datetime

UFS = "AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS SC SE SP TO".split()
FEDERAL = "6"

src, out = sys.argv[1], sys.argv[2]


def rows(zf, name):
    with zf.open(name) as raw:
        yield from csv.DictReader(io.TextIOWrapper(raw, encoding="latin1"), delimiter=";")


def money(v):
    return float(v.replace(".", "").replace(",", ".")) if v and v not in ("#NULO", "#NE") else 0.0


def date(v):
    try:
        return datetime.strptime(v, "%d/%m/%Y")
    except ValueError:
        return datetime.min


cands = defaultdict(lambda: {"votos_nominais": 0, "votos_validos": 0})
csv.field_size_limit(10**8)

with zipfile.ZipFile(f"{src}/votacao.zip") as zf:
    for uf in UFS:
        for r in rows(zf, f"votacao_candidato_munzona_2026_{uf}.csv"):
            if r["CD_CARGO"] != FEDERAL or r["NR_TURNO"] != "1":
                continue
            c = cands[r["SQ_CANDIDATO"]]
            c["uf"] = r["SG_UF"]
            c["votos_nominais"] += int(r["QT_VOTOS_NOMINAIS"])
            c["votos_validos"] += int(r["QT_VOTOS_NOMINAIS_VALIDOS"])
            c["situacao"] = r["DS_SIT_TOT_TURNO"]
        print("votos", uf, file=sys.stderr)

# Cada candidato pode ter várias prestações (parciais e final) e cada uma repete os
# lançamentos anteriores; fica só a mais recente.
def latest(by_report):
    best = {}
    for (sq, report), info in by_report.items():
        if sq not in best or info["date"] > best[sq]["date"]:
            best[sq] = info
    return best

expenses = {}
revenues = {}
with zipfile.ZipFile(f"{src}/contas.zip") as zf:
    for uf in UFS:
        by_report = {}
        for r in rows(zf, f"despesas_contratadas_candidatos_2026_{uf}.csv"):
            if r["CD_CARGO"] != FEDERAL:
                continue
            key = (r["SQ_CANDIDATO"], r["SQ_PRESTADOR_CONTAS"])
            info = by_report.setdefault(key, {"date": date(r["DT_PRESTACAO_CONTAS"]), "kind": r["TP_PRESTACAO_CONTAS"], "total": 0.0, "count": 0, "origins": defaultdict(float)})
            v = money(r["VR_DESPESA_CONTRATADA"])
            info["total"] += v
            info["count"] += 1
            info["origins"][r["DS_ORIGEM_DESPESA"]] += v
        expenses.update(latest(by_report))

        by_report = {}
        for r in rows(zf, f"receitas_candidatos_2026_{uf}.csv"):
            if r["CD_CARGO"] != FEDERAL:
                continue
            key = (r["SQ_CANDIDATO"], r["SQ_PRESTADOR_CONTAS"])
            info = by_report.setdefault(key, {"date": date(r["DT_PRESTACAO_CONTAS"]), "total": 0.0, "fontes": defaultdict(float), "origens": defaultdict(float)})
            v = money(r["VR_RECEITA"])
            info["total"] += v
            info["fontes"][r["DS_FONTE_RECEITA"].upper()] += v
            info["origens"][r["DS_ORIGEM_RECEITA"]] += v
        revenues.update(latest(by_report))
        print("contas", uf, file=sys.stderr)

result = []
for sq in set(cands) | set(expenses) | set(revenues):
    c = cands.get(sq, {})
    e = expenses.get(sq)
    rv = revenues.get(sq)
    row = {
        "sq_candidato": sq,
        "votos_nominais": c.get("votos_nominais"),
        "votos_validos": c.get("votos_validos"),
        "situacao_turno": c.get("situacao"),
        "despesas_contratadas": round(e["total"], 2) if e else None,
        "qt_despesas": e["count"] if e else None,
        "tipo_prestacao": (e or {}).get("kind"),
        "principais_despesas": [[k, round(v, 2)] for k, v in sorted(e["origins"].items(), key=lambda kv: -kv[1])[:5]] if e else [],
        "receitas_total": round(rv["total"], 2) if rv else None,
        "receitas_por_fonte": {k: round(v, 2) for k, v in rv["fontes"].items()} if rv else {},
        "receitas_por_origem": {k: round(v, 2) for k, v in sorted(rv["origens"].items(), key=lambda kv: -kv[1])} if rv else {},
    }
    result.append(row)

with gzip.open(out, "wt", encoding="utf-8") as f:
    json.dump(sorted(result, key=lambda r: r["sq_candidato"]), f, ensure_ascii=False)
print(len(result), "candidatos", file=sys.stderr)
