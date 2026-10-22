from pathlib import Path
import argparse,decimal,json,math
args=argparse.ArgumentParser();args.add_argument('run',type=Path);options=args.parse_args()
def value(raw):
    return sum(decimal.Decimal(int(raw[key]['c'])).scaleb(int(raw[key]['e'])-8) for key in ('main','residual'))
def original_sum(current,count):
    v=decimal.Decimal(50)*decimal.getcontext().power(decimal.Decimal('1.2'),current)
    total=decimal.Decimal(0)
    for offset in range(count):
        level=current+offset+1
        try:f=50.0*math.pow(1.2,level-1) if level<3890 else math.inf
        except OverflowError:f=math.inf
        if math.isfinite(f):
            if f<100:fee=decimal.Decimal(math.ceil(math.floor(f/10)*10+5))
            else:
                step=math.pow(10,math.floor(math.log10(f)+1e-12)-1)
                fee=decimal.Decimal(math.ceil(math.floor(f/step+.5)*step))
        else:
            exponent=v.adjusted()-1
            fee=v.scaleb(-exponent).to_integral_value(rounding=decimal.ROUND_HALF_UP).scaleb(exponent)
        total+=fee;v*=decimal.Decimal('1.2')
    return total
results=[]
with decimal.localcontext() as context:
    context.prec=60;context.Emax=decimal.MAX_EMAX;context.Emin=decimal.MIN_EMIN
    for line in (options.run/'stdout.log').read_text(encoding='utf-8').splitlines():
        if line.startswith('P2_PRICE_RESULT '):
            row=json.loads(line[len('P2_PRICE_RESULT '):]);start=int(row['current']);count=int(row['count'])
            expected=original_sum(start,count);actual=value(row['amounts']['1']);error=abs(actual/expected-1)
            material=10*((start+count)//20*((start+count)//20+1)//2-start//20*(start//20+1)//2)
            passed=error<=decimal.Decimal('.00001') and row['amounts']['degenerate_matter']==material
            results.append({'kind':'original_rule_refund','start':start,'count':count,'relative_error':str(error),'material_exact':row['amounts']['degenerate_matter']==material,'status':'PASS' if passed else 'FAIL'})
        elif line.startswith('P2_MAX_FINITE_RESULT '):
            row=json.loads(line[len('P2_MAX_FINITE_RESULT '):]);quote=row['quote'];count=int(quote['count']);start=int(row['start'])
            upper=value(quote['bound_certificate']['upper']);lower=value(quote['bound_certificate']['lower'])
            original_upper=value(row['original_upper_prefix'])+decimal.Decimal(row['original_upper_tail']['coefficient']).scaleb(int(row['original_upper_tail']['exponent']))
            error=upper/original_upper-1;expected=original_sum(start,count)
            passed=upper>=original_upper and error<=decimal.Decimal('.00001') and 25*upper<=28*lower+24 and upper/expected<=decimal.Decimal('1.12')
            results.append({'kind':'encoded_MAX_U','start':start,'count':count,'conservative':upper>=original_upper,'representation_relative_error':str(error),'U_over_original_cost':str(upper/expected),'encoded_certificate':25*upper<=28*lower+24,'status':'PASS' if passed else 'FAIL'})
assert results,'missing oracle inputs'
(options.run/'decimal_oracle.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
print(json.dumps(results));raise SystemExit(0 if all(row['status']=='PASS' for row in results) else 1)
