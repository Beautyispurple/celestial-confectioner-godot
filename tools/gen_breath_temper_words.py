# One-off generator for data/breath_temper_words.json — run from repo root: python tools/gen_breath_temper_words.py
import json
from pathlib import Path

inhale = """
soft gather fill widen open ease gentle drift slow deepen calm still quiet hush
breathe in draw sip swell rise lift bloom tender light mild smooth quiet ease
inward center settle soften widen rest hush pause linger cradle hold mild warm
open widen gather pull draw swell fill rise lift bloom cradle ease drift slow
calm still quiet gentle soft mild smooth tender light ease deepen breathe sip
inward fill open widen gather pull draw swell rise lift bloom ease drift slow
hush quiet still calm gentle soft mild smooth tender light ease deepen breathe
center cradle soften widen rest hush pause linger hold mild warm open ease fill
sip draw swell rise lift bloom tender light mild smooth quiet ease deepen still
inward gather pull breathe open widen fill hush calm gentle drift slow deepen ease
""".split()

hold1 = """
pause settle hush steady rest quiet hold linger suspend anchor still calm soft
wait breathe steady pause settle hush quiet still calm gentle hold linger rest
anchor suspend steady pause settle hush quiet still calm hold linger rest wait
steady pause settle hush quiet still calm gentle hold linger rest anchor wait
pause settle steady hush quiet still calm hold linger rest anchor suspend wait
still calm soft quiet gentle steady pause settle hush hold linger rest anchor
wait steady pause settle hush quiet still calm hold linger rest anchor suspend
hush steady pause settle quiet still calm hold linger rest anchor suspend wait
steady quiet still calm gentle pause settle hush hold linger rest anchor soft
pause hush steady settle quiet still calm hold linger rest anchor suspend wait
""".split()

exhale = """
release soften unclench melt drop ease flow unwind let be let go drain empty
soften release melt drop ease flow unwind let be let go drain empty soften ease
outward flow drain empty release soften unclench melt drop unwind let be let go
ease flow unwind release soften melt drop let be let go drain empty soften ease
release unclench soften melt drop ease flow unwind let be let go drain empty
soften ease flow release melt drop unwind let be let go drain empty soften ease
let go let be release soften unclench melt drop ease flow unwind drain empty
flow unwind ease release soften melt drop let be let go drain empty soften ease
drain empty release soften unclench melt drop ease flow unwind let be let go ease
soften release ease flow unwind melt drop let be let go drain empty unclench ease
""".split()

hold2 = """
held complete sure balanced clear grounded steady enough here done calm sure
complete sure balanced clear grounded steady enough here done calm held complete
sure balanced clear grounded steady enough here done calm held complete sure steady
balanced clear grounded steady enough here done calm held complete sure enough here
steady enough here done calm held complete sure balanced clear grounded steady enough
complete held sure balanced clear grounded steady enough here done calm sure steady
here done calm held complete sure balanced clear grounded steady enough sure steady
enough here done calm held complete sure balanced clear grounded steady enough sure
done calm held complete sure balanced clear grounded steady enough here sure steady
held complete sure balanced clear grounded steady enough here done calm sure enough
""".split()

# Dedupe while preserving order
def uniq(words):
    seen = set()
    out = []
    for w in words:
        w = w.strip().lower()
        if not w or w in seen:
            continue
        seen.add(w)
        out.append(w)
    return out

data = {
    "inhale_calm": uniq(inhale),
    "hold_still": uniq(hold1),
    "exhale_release": uniq(exhale),
    "hold_accomplish": uniq(hold2),
}

root = Path(__file__).resolve().parent.parent
out = root / "data" / "breath_temper_words.json"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(data, indent=2), encoding="utf-8")
for k, v in data.items():
    print(k, len(v))
print("wrote", out)
