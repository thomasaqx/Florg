from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from xml.sax.saxutils import escape
from zipfile import ZIP_DEFLATED, ZipFile


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "FLORG_pitch_produto.pptx"
SCRIPT_OUT = ROOT / "FLORG_pitch_roteiro.md"

SLIDE_W = 12192000
SLIDE_H = 6858000


def emu(inches: float) -> int:
    return int(inches * 914400)


def rgb(color: str) -> str:
    return color.replace("#", "").upper()


def safe(text: str) -> str:
    return escape(text, {'"': "&quot;"})


def paragraph(
    text: str,
    *,
    size: int = 24,
    color: str = "#134E4A",
    bold: bool = False,
    align: str | None = None,
    bullet: bool = False,
) -> str:
    ppr = []
    if align:
        ppr.append(f'algn="{align}"')
    if bullet:
        ppr.append('marL="280000" indent="-160000"')

    ppr_xml = ""
    if ppr or bullet:
        bullet_xml = '<a:buChar char="•"/>' if bullet else ""
        ppr_xml = f"<a:pPr {' '.join(ppr)}>{bullet_xml}</a:pPr>"

    bold_attr = ' b="1"' if bold else ""
    return (
        "<a:p>"
        f"{ppr_xml}"
        "<a:r>"
        f'<a:rPr lang="pt-BR" sz="{size * 100}"{bold_attr}>'
        f'<a:solidFill><a:srgbClr val="{rgb(color)}"/></a:solidFill>'
        '<a:latin typeface="Arial"/>'
        "</a:rPr>"
        f"<a:t>{safe(text)}</a:t>"
        "</a:r>"
        "</a:p>"
    )


def text_box(
    shape_id: int,
    x: float,
    y: float,
    w: float,
    h: float,
    paragraphs: list[str],
    *,
    fill: str | None = None,
    line: str | None = None,
    radius: bool = False,
    margin: int = 120000,
) -> str:
    fill_xml = (
        f'<a:solidFill><a:srgbClr val="{rgb(fill)}"/></a:solidFill>'
        if fill
        else "<a:noFill/>"
    )
    line_xml = (
        f'<a:ln w="9000"><a:solidFill><a:srgbClr val="{rgb(line)}"/></a:solidFill></a:ln>'
        if line
        else '<a:ln><a:noFill/></a:ln>'
    )
    preset = "roundRect" if radius else "rect"
    return f"""
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id="{shape_id}" name="Text {shape_id}"/>
          <p:cNvSpPr txBox="1"/>
          <p:nvPr/>
        </p:nvSpPr>
        <p:spPr>
          <a:xfrm>
            <a:off x="{emu(x)}" y="{emu(y)}"/>
            <a:ext cx="{emu(w)}" cy="{emu(h)}"/>
          </a:xfrm>
          <a:prstGeom prst="{preset}"><a:avLst/></a:prstGeom>
          {fill_xml}
          {line_xml}
        </p:spPr>
        <p:txBody>
          <a:bodyPr wrap="square" lIns="{margin}" tIns="{margin}" rIns="{margin}" bIns="{margin}"/>
          <a:lstStyle/>
          {''.join(paragraphs)}
        </p:txBody>
      </p:sp>
    """


def shape(
    shape_id: int,
    x: float,
    y: float,
    w: float,
    h: float,
    *,
    fill: str,
    line: str | None = None,
    preset: str = "rect",
) -> str:
    line_xml = (
        f'<a:ln w="9000"><a:solidFill><a:srgbClr val="{rgb(line)}"/></a:solidFill></a:ln>'
        if line
        else '<a:ln><a:noFill/></a:ln>'
    )
    return f"""
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id="{shape_id}" name="Shape {shape_id}"/>
          <p:cNvSpPr/>
          <p:nvPr/>
        </p:nvSpPr>
        <p:spPr>
          <a:xfrm>
            <a:off x="{emu(x)}" y="{emu(y)}"/>
            <a:ext cx="{emu(w)}" cy="{emu(h)}"/>
          </a:xfrm>
          <a:prstGeom prst="{preset}"><a:avLst/></a:prstGeom>
          <a:solidFill><a:srgbClr val="{rgb(fill)}"/></a:solidFill>
          {line_xml}
        </p:spPr>
      </p:sp>
    """


def line(
    shape_id: int,
    x1: float,
    y1: float,
    x2: float,
    y2: float,
    *,
    color: str = "#14B8A6",
    width: int = 24000,
) -> str:
    x = min(x1, x2)
    y = min(y1, y2)
    w = abs(x2 - x1)
    h = abs(y2 - y1)
    flip_h = ' flipH="1"' if x2 < x1 else ""
    flip_v = ' flipV="1"' if y2 < y1 else ""
    return f"""
      <p:cxnSp>
        <p:nvCxnSpPr>
          <p:cNvPr id="{shape_id}" name="Line {shape_id}"/>
          <p:cNvCxnSpPr/>
          <p:nvPr/>
        </p:nvCxnSpPr>
        <p:spPr>
          <a:xfrm{flip_h}{flip_v}>
            <a:off x="{emu(x)}" y="{emu(y)}"/>
            <a:ext cx="{emu(w)}" cy="{emu(h)}"/>
          </a:xfrm>
          <a:prstGeom prst="line"><a:avLst/></a:prstGeom>
          <a:ln w="{width}" cap="round">
            <a:solidFill><a:srgbClr val="{rgb(color)}"/></a:solidFill>
          </a:ln>
        </p:spPr>
      </p:cxnSp>
    """


def footer(slide_no: int) -> str:
    return text_box(
        900 + slide_no,
        0.55,
        7.12,
        12.2,
        0.2,
        [
            paragraph(
                f"FLORG | Pitch de produto | {slide_no}/7",
                size=8,
                color="#5AB9A8",
                align="r",
            )
        ],
    )


def slide_xml(shapes: str) -> str:
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
       xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:bg>
      <p:bgPr>
        <a:solidFill><a:srgbClr val="F8FAFC"/></a:solidFill>
      </p:bgPr>
    </p:bg>
    <p:spTree>
      <p:nvGrpSpPr>
        <p:cNvPr id="1" name=""/>
        <p:cNvGrpSpPr/>
        <p:nvPr/>
      </p:nvGrpSpPr>
      <p:grpSpPr>
        <a:xfrm>
          <a:off x="0" y="0"/>
          <a:ext cx="0" cy="0"/>
          <a:chOff x="0" y="0"/>
          <a:chExt cx="0" cy="0"/>
        </a:xfrm>
      </p:grpSpPr>
      {shapes}
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sld>"""


def title_slide() -> str:
    shapes = [
        shape(2, 0, 0, 13.333, 7.5, fill="#0B1F1C"),
        shape(3, 8.85, -0.55, 5.3, 5.3, fill="#14B8A6", preset="ellipse"),
        shape(4, 9.55, 2.8, 3.2, 3.2, fill="#06B6D4", preset="ellipse"),
        text_box(
            5,
            0.8,
            0.6,
            2.0,
            0.6,
            [paragraph("FLORG", size=24, color="#FFFFFF", bold=True)],
        ),
        text_box(
            6,
            0.8,
            2.05,
            7.3,
            1.45,
            [
                paragraph(
                    "Organizador da Vida Financeira",
                    size=42,
                    color="#FFFFFF",
                    bold=True,
                )
            ],
        ),
        text_box(
            7,
            0.83,
            3.55,
            6.5,
            1.0,
            [
                paragraph(
                    "Transformamos dados financeiros espalhados em decisões simples, claras e acionáveis.",
                    size=20,
                    color="#A7DCD3",
                )
            ],
        ),
        text_box(
            8,
            0.85,
            5.25,
            3.2,
            0.54,
            [paragraph("Pitch de produto | 5 minutos", size=15, color="#FFFFFF")],
            fill="#115E59",
            radius=True,
        ),
        text_box(
            9,
            8.45,
            1.15,
            3.65,
            3.7,
            [
                paragraph("Hoje", size=14, color="#CCFBF1", bold=True),
                paragraph("Contas, cartões e gastos vivem em lugares diferentes.", size=18, color="#FFFFFF", bold=True),
                paragraph("A decisão financeira chega tarde demais.", size=15, color="#CCFBF1"),
            ],
            fill="#102824",
            line="#21443E",
            radius=True,
        ),
    ]
    return slide_xml("".join(shapes))


def problem_slide() -> str:
    cards = [
        ("Informação fragmentada", "Bancos, cartões, planilhas e apps não conversam entre si.", "#14B8A6"),
        ("Gastos invisíveis", "Assinaturas, compras pequenas e hábitos recorrentes somem no dia a dia.", "#F43F5E"),
        ("Pouca orientação", "O usuário sabe quanto gastou, mas não entende o que fazer agora.", "#F59E0B"),
    ]
    shapes = [
        text_box(2, 0.7, 0.5, 11.8, 0.8, [paragraph("O problema", size=34, bold=True)]),
        text_box(
            3,
            0.72,
            1.25,
            9.8,
            0.55,
            [paragraph("Cuidar do dinheiro ainda exige esforço manual demais.", size=19, color="#0F766E")],
        ),
    ]
    for i, (title, body, color) in enumerate(cards):
        x = 0.75 + i * 4.1
        shapes.extend(
            [
                shape(10 + i, x, 2.15, 3.55, 2.55, fill="#FFFFFF", line="#CCFBF1", preset="roundRect"),
                shape(20 + i, x + 0.25, 2.42, 0.42, 0.42, fill=color, preset="ellipse"),
                text_box(30 + i, x + 0.25, 2.95, 3.0, 0.45, [paragraph(title, size=18, color="#134E4A", bold=True)]),
                text_box(40 + i, x + 0.25, 3.52, 2.95, 0.9, [paragraph(body, size=14, color="#0F766E")]),
            ]
        )
    shapes.append(
        text_box(
            60,
            1.35,
            5.35,
            10.6,
            0.72,
            [paragraph("Resultado: ansiedade financeira, decisões reativas e oportunidades de economia perdidas.", size=18, color="#FFFFFF", bold=True, align="ctr")],
            fill="#0F766E",
            radius=True,
        )
    )
    shapes.append(footer(2))
    return slide_xml("".join(shapes))


def impact_slide() -> str:
    shapes = [
        text_box(2, 0.7, 0.5, 11.8, 0.8, [paragraph("Por que isso importa", size=34, bold=True)]),
        text_box(3, 0.72, 1.25, 10.3, 0.55, [paragraph("O problema não é falta de dados. É falta de clareza no momento certo.", size=19, color="#0F766E")]),
        shape(4, 0.85, 2.12, 11.65, 3.65, fill="#FFFFFF", line="#CCFBF1", preset="roundRect"),
        text_box(5, 1.2, 2.45, 3.15, 0.7, [paragraph("Antes", size=23, color="#E11D48", bold=True, align="ctr")]),
        text_box(6, 5.08, 2.45, 3.15, 0.7, [paragraph("Durante", size=23, color="#D97706", bold=True, align="ctr")]),
        text_box(7, 8.98, 2.45, 3.15, 0.7, [paragraph("Depois", size=23, color="#059669", bold=True, align="ctr")]),
        line(8, 3.85, 3.58, 5.0, 3.58, color="#99F6E4", width=36000),
        line(9, 7.75, 3.58, 8.9, 3.58, color="#99F6E4", width=36000),
        text_box(10, 1.2, 3.35, 3.15, 1.25, [paragraph("O usuário tenta lembrar onde gastou e confere vários lugares.", size=15, color="#134E4A", align="ctr")]),
        text_box(11, 5.08, 3.35, 3.15, 1.25, [paragraph("Ele precisa interpretar tudo sozinho e ajustar o orçamento manualmente.", size=15, color="#134E4A", align="ctr")]),
        text_box(12, 8.98, 3.35, 3.15, 1.25, [paragraph("Quando percebe o desvio, a chance de economizar já passou.", size=15, color="#134E4A", align="ctr")]),
        text_box(13, 1.25, 5.95, 10.8, 0.52, [paragraph("Nossa oportunidade: transformar acompanhamento financeiro em orientação diária.", size=18, color="#0F766E", bold=True, align="ctr")]),
        footer(3),
    ]
    return slide_xml("".join(shapes))


def solution_slide() -> str:
    shapes = [
        text_box(2, 0.7, 0.45, 11.6, 0.8, [paragraph("Nossa solução", size=34, bold=True)]),
        text_box(3, 0.72, 1.18, 10.4, 0.6, [paragraph("FLORG centraliza, organiza e explica sua vida financeira em uma experiência simples.", size=19, color="#0F766E")]),
        shape(4, 0.85, 2.0, 5.5, 4.3, fill="#102824", line="#21443E", preset="roundRect"),
        text_box(5, 1.2, 2.28, 2.8, 0.45, [paragraph("Dashboard único", size=18, color="#FFFFFF", bold=True)]),
        shape(6, 1.2, 3.0, 1.3, 0.75, fill="#14B8A6", preset="roundRect"),
        shape(7, 2.8, 3.0, 1.3, 0.75, fill="#10B981", preset="roundRect"),
        shape(8, 4.4, 3.0, 1.3, 0.75, fill="#F43F5E", preset="roundRect"),
        line(9, 1.35, 4.75, 2.2, 4.35, color="#14B8A6", width=26000),
        line(10, 2.2, 4.35, 3.1, 4.65, color="#14B8A6", width=26000),
        line(11, 3.1, 4.65, 4.0, 4.1, color="#14B8A6", width=26000),
        line(12, 4.0, 4.1, 5.35, 4.45, color="#14B8A6", width=26000),
        text_box(13, 1.2, 5.25, 4.75, 0.55, [paragraph("Saldo, receitas, despesas e alertas no mesmo lugar.", size=14, color="#A7DCD3")]),
        text_box(20, 6.95, 2.04, 5.4, 0.75, [paragraph("O que o usuário recebe", size=24, bold=True)]),
        text_box(21, 7.0, 3.0, 5.0, 0.5, [paragraph("Visão consolidada das contas conectadas", size=17, color="#134E4A", bullet=True)]),
        text_box(22, 7.0, 3.75, 5.0, 0.5, [paragraph("Orçamentos vivos por categoria", size=17, color="#134E4A", bullet=True)]),
        text_box(23, 7.0, 4.5, 5.0, 0.5, [paragraph("Insights acionáveis para reduzir gastos", size=17, color="#134E4A", bullet=True)]),
        text_box(24, 7.0, 5.25, 5.0, 0.5, [paragraph("Acompanhamento visual sem planilha", size=17, color="#134E4A", bullet=True)]),
        footer(4),
    ]
    return slide_xml("".join(shapes))


def how_it_works_slide() -> str:
    steps = [
        ("1", "Conectar", "O usuário vincula contas e cartões com segurança."),
        ("2", "Organizar", "Transações são categorizadas e agrupadas automaticamente."),
        ("3", "Entender", "FLORG mostra padrões, riscos e oportunidades."),
        ("4", "Agir", "O usuário ajusta orçamento, metas e hábitos."),
    ]
    shapes = [
        text_box(2, 0.7, 0.5, 11.8, 0.8, [paragraph("Como funciona", size=34, bold=True)]),
        text_box(3, 0.72, 1.25, 10.8, 0.55, [paragraph("Um fluxo simples para sair do extrato passivo e chegar à decisão ativa.", size=19, color="#0F766E")]),
    ]
    for i, (num, title, body) in enumerate(steps):
        x = 0.75 + i * 3.15
        shapes.extend(
            [
                shape(10 + i, x, 2.25, 2.65, 3.2, fill="#FFFFFF", line="#CCFBF1", preset="roundRect"),
                shape(20 + i, x + 0.28, 2.58, 0.62, 0.62, fill="#14B8A6", preset="ellipse"),
                text_box(30 + i, x + 0.28, 2.63, 0.62, 0.35, [paragraph(num, size=15, color="#FFFFFF", bold=True, align="ctr")], margin=0),
                text_box(40 + i, x + 0.28, 3.45, 2.05, 0.45, [paragraph(title, size=19, color="#134E4A", bold=True)]),
                text_box(50 + i, x + 0.28, 4.05, 2.03, 0.9, [paragraph(body, size=14, color="#0F766E")]),
            ]
        )
        if i < len(steps) - 1:
            shapes.append(line(70 + i, x + 2.58, 3.85, x + 3.08, 3.85, color="#99F6E4", width=30000))
    shapes.extend(
        [
            text_box(90, 1.4, 6.0, 10.5, 0.45, [paragraph("A promessa: menos tempo conferindo, mais confiança para decidir.", size=18, color="#FFFFFF", bold=True, align="ctr")], fill="#0F766E", radius=True),
            footer(5),
        ]
    )
    return slide_xml("".join(shapes))


def differentiation_slide() -> str:
    shapes = [
        text_box(2, 0.7, 0.5, 11.8, 0.8, [paragraph("Por que FLORG", size=34, bold=True)]),
        text_box(3, 0.72, 1.25, 10.2, 0.55, [paragraph("Não queremos ser apenas mais um app de extrato. Queremos ser a camada de clareza.", size=19, color="#0F766E")]),
        shape(4, 0.85, 2.05, 3.7, 3.85, fill="#FFFFFF", line="#CCFBF1", preset="roundRect"),
        shape(5, 4.82, 2.05, 3.7, 3.85, fill="#FFFFFF", line="#CCFBF1", preset="roundRect"),
        shape(6, 8.8, 2.05, 3.7, 3.85, fill="#FFFFFF", line="#CCFBF1", preset="roundRect"),
        text_box(7, 1.18, 2.45, 3.05, 0.5, [paragraph("Linguagem humana", size=20, color="#134E4A", bold=True)]),
        text_box(8, 1.18, 3.25, 3.0, 1.25, [paragraph("Insights explicam o que aconteceu e o próximo passo, sem jargão financeiro.", size=15, color="#0F766E")]),
        text_box(9, 5.15, 2.45, 3.05, 0.5, [paragraph("Experiência visual", size=20, color="#134E4A", bold=True)]),
        text_box(10, 5.15, 3.25, 3.0, 1.25, [paragraph("Gráficos, orçamentos e cartões tornam o diagnóstico rápido e fácil de comparar.", size=15, color="#0F766E")]),
        text_box(11, 9.13, 2.45, 3.05, 0.5, [paragraph("Ação no momento certo", size=20, color="#134E4A", bold=True)]),
        text_box(12, 9.13, 3.25, 3.0, 1.25, [paragraph("Alertas e oportunidades aparecem antes que o mês vire um problema.", size=15, color="#0F766E")]),
        text_box(13, 2.0, 6.25, 9.25, 0.48, [paragraph("Tese: dinheiro organizado vira comportamento melhor.", size=20, color="#0F766E", bold=True, align="ctr")]),
        footer(6),
    ]
    return slide_xml("".join(shapes))


def close_slide() -> str:
    shapes = [
        shape(2, 0, 0, 13.333, 7.5, fill="#0B1F1C"),
        shape(3, -0.9, 4.8, 4.0, 4.0, fill="#14B8A6", preset="ellipse"),
        shape(4, 10.4, -0.7, 3.4, 3.4, fill="#06B6D4", preset="ellipse"),
        text_box(5, 0.85, 0.65, 2.2, 0.55, [paragraph("FLORG", size=22, color="#FFFFFF", bold=True)]),
        text_box(6, 0.85, 1.72, 8.2, 1.25, [paragraph("Próximo passo: validar com usuários reais", size=38, color="#FFFFFF", bold=True)]),
        text_box(7, 0.88, 3.05, 6.8, 0.72, [paragraph("Queremos testar se o FLORG reduz tempo de controle financeiro e aumenta a sensação de clareza no fim do mês.", size=18, color="#A7DCD3")]),
        text_box(8, 0.9, 4.35, 3.65, 0.82, [paragraph("Piloto", size=18, color="#FFFFFF", bold=True), paragraph("Usuários acompanhando contas e orçamento", size=13, color="#CCFBF1")], fill="#102824", line="#21443E", radius=True),
        text_box(9, 4.8, 4.35, 3.65, 0.82, [paragraph("Métrica", size=18, color="#FFFFFF", bold=True), paragraph("Clareza, economia percebida e recorrência", size=13, color="#CCFBF1")], fill="#102824", line="#21443E", radius=True),
        text_box(10, 8.7, 4.35, 3.65, 0.82, [paragraph("Convite", size=18, color="#FFFFFF", bold=True), paragraph("Feedback, parceiros e primeiros testes", size=13, color="#CCFBF1")], fill="#102824", line="#21443E", radius=True),
        text_box(11, 3.15, 6.2, 7.0, 0.52, [paragraph("FLORG: menos planilha, mais decisão.", size=24, color="#FFFFFF", bold=True, align="ctr")]),
        text_box(12, 0.55, 7.12, 12.2, 0.2, [paragraph("FLORG | Pitch de produto | 7/7", size=8, color="#5AB9A8", align="r")]),
    ]
    return slide_xml("".join(shapes))


def content_types(slide_count: int) -> str:
    slide_overrides = "\n".join(
        f'<Override PartName="/ppt/slides/slide{i}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>'
        for i in range(1, slide_count + 1)
    )
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
  {slide_overrides}
</Types>"""


def package_rels() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>"""


def presentation_xml(slide_count: int) -> str:
    sld_ids = "\n".join(
        f'<p:sldId id="{255 + i}" r:id="rId{i}"/>' for i in range(1, slide_count + 1)
    )
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
                xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldMasterIdLst>
    <p:sldMasterId id="2147483648" r:id="rId{slide_count + 1}"/>
  </p:sldMasterIdLst>
  <p:sldIdLst>{sld_ids}</p:sldIdLst>
  <p:sldSz cx="{SLIDE_W}" cy="{SLIDE_H}" type="wide"/>
  <p:notesSz cx="6858000" cy="9144000"/>
  <p:defaultTextStyle>
    <a:defPPr><a:defRPr lang="pt-BR"/></a:defPPr>
  </p:defaultTextStyle>
</p:presentation>"""


def presentation_rels(slide_count: int) -> str:
    slide_rels = "\n".join(
        f'<Relationship Id="rId{i}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide{i}.xml"/>'
        for i in range(1, slide_count + 1)
    )
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  {slide_rels}
  <Relationship Id="rId{slide_count + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
  <Relationship Id="rId{slide_count + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>
</Relationships>"""


def slide_rels() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>"""


def slide_master_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
             xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
             xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
    </p:spTree>
  </p:cSld>
  <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
  <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>
  <p:txStyles>
    <p:titleStyle/><p:bodyStyle/><p:otherStyle/>
  </p:txStyles>
</p:sldMaster>"""


def slide_master_rels() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
</Relationships>"""


def slide_layout_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
             xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
             xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
             type="blank" preserve="1">
  <p:cSld name="Blank">
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sldLayout>"""


def slide_layout_rels() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>"""


def theme_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="FLORG">
  <a:themeElements>
    <a:clrScheme name="FLORG">
      <a:dk1><a:srgbClr val="0B1F1C"/></a:dk1>
      <a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>
      <a:dk2><a:srgbClr val="134E4A"/></a:dk2>
      <a:lt2><a:srgbClr val="F8FAFC"/></a:lt2>
      <a:accent1><a:srgbClr val="14B8A6"/></a:accent1>
      <a:accent2><a:srgbClr val="06B6D4"/></a:accent2>
      <a:accent3><a:srgbClr val="10B981"/></a:accent3>
      <a:accent4><a:srgbClr val="F43F5E"/></a:accent4>
      <a:accent5><a:srgbClr val="F59E0B"/></a:accent5>
      <a:accent6><a:srgbClr val="6366F1"/></a:accent6>
      <a:hlink><a:srgbClr val="0D9488"/></a:hlink>
      <a:folHlink><a:srgbClr val="115E59"/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name="Arial">
      <a:majorFont><a:latin typeface="Arial"/></a:majorFont>
      <a:minorFont><a:latin typeface="Arial"/></a:minorFont>
    </a:fontScheme>
    <a:fmtScheme name="FLORG">
      <a:fillStyleLst><a:solidFill><a:schemeClr val="accent1"/></a:solidFill></a:fillStyleLst>
      <a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="accent1"/></a:solidFill></a:ln></a:lnStyleLst>
      <a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>
      <a:bgFillStyleLst><a:solidFill><a:schemeClr val="lt1"/></a:solidFill></a:bgFillStyleLst>
    </a:fmtScheme>
  </a:themeElements>
  <a:objectDefaults/>
  <a:extraClrSchemeLst/>
</a:theme>"""


def app_props(slide_count: int) -> str:
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
            xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Codex</Application>
  <PresentationFormat>Widescreen</PresentationFormat>
  <Slides>{slide_count}</Slides>
  <Company>FLORG</Company>
</Properties>"""


def core_props() -> str:
    now = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
                   xmlns:dc="http://purl.org/dc/elements/1.1/"
                   xmlns:dcterms="http://purl.org/dc/terms/"
                   xmlns:dcmitype="http://purl.org/dc/dcmitype/"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>FLORG - Pitch de Produto</dc:title>
  <dc:creator>Codex</dc:creator>
  <dc:description>Pitch em português brasileiro para apresentar o problema e a solução do FLORG.</dc:description>
  <cp:lastModifiedBy>Codex</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>
</cp:coreProperties>"""


def roteiro() -> str:
    return """# Roteiro de pitch FLORG - até 5 minutos

## 1. Abertura - 30s
Olá, nós somos o FLORG, um organizador da vida financeira. Nossa proposta é transformar dados financeiros espalhados em decisões simples, claras e acionáveis.

## 2. Problema - 45s
Hoje, cuidar do próprio dinheiro ainda dá muito trabalho. As informações ficam em bancos, cartões, aplicativos e planilhas. O usuário até consegue ver o extrato, mas precisa interpretar tudo sozinho. Pequenos gastos, assinaturas e hábitos recorrentes passam despercebidos.

## 3. Impacto - 40s
O problema não é falta de dados. É falta de clareza no momento certo. Quando a pessoa percebe que saiu do orçamento, muitas vezes o mês já passou. Isso gera ansiedade, decisões reativas e oportunidades de economia perdidas.

## 4. Solução - 60s
O FLORG resolve isso centralizando contas, transações, orçamentos e insights em uma única experiência. Em vez de mostrar apenas números, o produto explica o que está acontecendo: onde o dinheiro está indo, quais categorias pedem atenção e onde existe potencial de economia.

## 5. Como funciona - 55s
O fluxo é simples: o usuário conecta contas e cartões, o FLORG organiza as transações, identifica padrões e entrega recomendações práticas. A partir daí, a pessoa acompanha metas, orçamento e evolução sem depender de planilha.

## 6. Diferenciais - 45s
Nosso diferencial é a camada de clareza. A linguagem é humana, a experiência é visual e as recomendações aparecem no momento certo. O objetivo não é só registrar o passado, mas ajudar o usuário a tomar melhores decisões no presente.

## 7. Fechamento - 45s
Nosso próximo passo é validar o FLORG com usuários reais, medindo clareza financeira, economia percebida e recorrência de uso. FLORG é menos planilha e mais decisão.
"""


def build() -> None:
    slides = [
        title_slide(),
        problem_slide(),
        impact_slide(),
        solution_slide(),
        how_it_works_slide(),
        differentiation_slide(),
        close_slide(),
    ]
    with ZipFile(OUT, "w", ZIP_DEFLATED) as pptx:
        pptx.writestr("[Content_Types].xml", content_types(len(slides)))
        pptx.writestr("_rels/.rels", package_rels())
        pptx.writestr("docProps/core.xml", core_props())
        pptx.writestr("docProps/app.xml", app_props(len(slides)))
        pptx.writestr("ppt/presentation.xml", presentation_xml(len(slides)))
        pptx.writestr("ppt/_rels/presentation.xml.rels", presentation_rels(len(slides)))
        pptx.writestr("ppt/theme/theme1.xml", theme_xml())
        pptx.writestr("ppt/slideMasters/slideMaster1.xml", slide_master_xml())
        pptx.writestr("ppt/slideMasters/_rels/slideMaster1.xml.rels", slide_master_rels())
        pptx.writestr("ppt/slideLayouts/slideLayout1.xml", slide_layout_xml())
        pptx.writestr("ppt/slideLayouts/_rels/slideLayout1.xml.rels", slide_layout_rels())
        for index, slide in enumerate(slides, start=1):
            pptx.writestr(f"ppt/slides/slide{index}.xml", slide)
            pptx.writestr(f"ppt/slides/_rels/slide{index}.xml.rels", slide_rels())

    SCRIPT_OUT.write_text(roteiro(), encoding="utf-8")
    print(f"Wrote {OUT}")
    print(f"Wrote {SCRIPT_OUT}")


if __name__ == "__main__":
    build()
