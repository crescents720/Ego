"""Extract low-rise street buildings; preserve source USDZ and attribution."""
from convert_actor_usdz import convert

for name, scale in [('Filler_Housing',4.5),('group84',5.0),('LM_Laundrette',6.0),('LM_PawnShop1',5.0),('LM_Liquor',4.5)]:
    convert('CCity_Building_Set_1.usdz','assets/third_party/ccity',name+'.glb',
            scene='town',root_filter=name,scale_multiplier=scale)
