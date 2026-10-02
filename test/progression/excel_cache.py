"""Recalculate the arithmetic-only level workbook formulas without dropping formulas."""
import ast, math, re, zipfile, io
from xml.etree import ElementTree as ET

def recache_level(path, sheet, original_bytes=None):
    cache = {}; busy = set()
    def excel_round(x, n=0):
        scale=10.0**int(n)
        return math.copysign(math.floor(abs(x)*scale+.5)/scale,x)
    funcs={'ROUND':excel_round,'INT':math.floor,'LOG10':math.log10,'ABS':abs}
    def value(ref):
        ref=ref.replace('$','')
        if ref in cache:return cache[ref]
        if ref in busy:raise ValueError('Circular formula '+ref)
        busy.add(ref); val=sheet[ref].value
        if isinstance(val,str) and val.startswith('='):
            expression=re.sub(r'\$?[A-Z]{1,3}\$?\d+(?![0-9(])',lambda m:repr(value(m.group())),val[1:]).replace('^','**')
            tree=ast.parse(expression,mode='eval')
            allowed=(ast.Expression,ast.Constant,ast.BinOp,ast.UnaryOp,ast.Add,ast.Sub,ast.Mult,ast.Div,ast.Pow,ast.USub,ast.UAdd,ast.Call,ast.Name,ast.Load)
            for node in ast.walk(tree):
                if not isinstance(node,allowed):raise ValueError('Unsupported formula '+val)
                if isinstance(node,ast.Name) and node.id not in funcs:raise ValueError('Unsupported function '+node.id)
            val=eval(compile(tree,'<level-formula>','eval'),{'__builtins__':{}},funcs)
        if not isinstance(val,(int,float)) or not math.isfinite(val):raise ValueError('Invalid numeric cell '+ref)
        cache[ref]=val;busy.remove(ref);return val
    computed={c.coordinate:value(c.coordinate) for row in sheet for c in row if c.data_type=='f'}
    ns={'m':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    with zipfile.ZipFile(path) as z:files={n:z.read(n) for n in z.namelist()}
    root=ET.fromstring(files['xl/worksheets/sheet1.xml'])
    for cell in root.findall('.//m:c',ns):
        if cell.attrib['r'] in computed:
            v=cell.find('m:v',ns)
            if v is None:v=ET.SubElement(cell,'{'+ns['m']+'}v')
            v.text=repr(computed[cell.attrib['r']])
    if original_bytes is not None:
        with zipfile.ZipFile(io.BytesIO(original_bytes)) as z: old=ET.fromstring(z.read('xl/worksheets/sheet1.xml'))
        prior={c.attrib['r']:c.find('m:v',ns).text for c in old.findall('.//m:c',ns) if c.find('m:f',ns) is not None and c.find('m:v',ns) is not None}
        for cell in root.findall('.//m:c',ns):
            ref=cell.attrib['r']
            # Stage20 is a literal anchor; formulas from21 onward do not depend on1–10.
            if int(re.search(r'\d+',ref).group())>=24 and ref in prior and cell.find('m:f',ns) is not None:
                cell.find('m:v',ns).text=prior[ref]
    files['xl/worksheets/sheet1.xml']=ET.tostring(root,encoding='utf-8',xml_declaration=True)
    with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_DEFLATED) as z:
        for n,content in files.items():z.writestr(n,content)
    return computed
