import math
GR=1.0
ST = {  # id: (base, growth, unlock, kind)
 'entrada':(8,1.16,0,'f'),'checkin':(11,1.165,0,'f'),'seguranca':(14,1.17,0,'f'),
 'g0':(15,1.17,0,'g'),'g1':(50,1.17,100,'g'),'g2':(1e3,1.17,2e3,'g'),'g3':(5e4,1.17,1e5,'g'),'g4':(1.5e6,1.17,3e6,'g'),'g5':(4e7,1.17,8e7,'g'),
 'lojas':(80,1.18,600,'f'),'pista':(60,1.2,0,'b'),'torre':(150,1.21,0,'b'),'vip':(5e4,1.2,1e5,'b'),'hangar':(0,0,1e6,'o'),'combustivel':(0,0,3e7,'o')}
MS=[10,25,50,100,150,200,300,400,500]
def mp(l): return sum(1 for m in MS if l>=m)
def pw(l): return 0 if l<=0 else l*2**mp(l)
SEATS=[40,120,260]; TM=[1,1.6,2.4]; LEN=[5.6,8.4,11.2]
GX=[-38,-26,-14,-2,10,22]
def gt(l): return 2 if l>=75 else 1 if l>=25 else 0
def rt(l): return 2 if l>=30 else 1 if l>=10 else 0
STAR=[0]
def rate(lv, city=0):
  sp=min(4,1+0.035*(lv['pista']-1))
  lam=0.5*pw(lv['entrada']); mc=0.6*pw(lv['checkin']); ms=0.55*pw(lv['seguranca'])
  cap=0; wt=0
  for g in range(6):
    l=lv['g%d'%g]
    if l<=0: continue
    t=min(gt(l),rt(lv['pista'])); seats=SEATS[t]*(1+0.02*(l-1))
    tin=abs(-37+20)+abs(38-GX[g])+abs(-20-(-6.4-LEN[t]/2)); tout=abs(GX[g]+46)+11
    cyc=7/sp+tin/(8*sp)+seats/max(4,seats/5)+1+4/sp+tout/(8*sp)+7/sp+2/sp
    c=seats/cyc; cap+=c
    tk=4*(1+0.2*(l-1))*2**mp(l)*TM[t]*(1+0.04*lv['vip'])
    wt+=c*tk
  thr=min(lam,mc,ms,cap); avg=wt/cap if cap else 0
  shop=0.4*lv['lojas']*1.6**mp(lv['lojas']) if lv['lojas']>0 else 0
  mult=2**STAR[0]*6**city*(1+0.06*(lv['torre']-1))*(1.5 if lv['hangar'] else 1)*(1.5 if lv['combustivel'] else 1)
  return thr*(avg+shop)*mult

SREQ={'lojas':1,'g2':1,'vip':2,'g3':2,'hangar':3,'g4':3,'combustivel':4,'g5':4}
TASKS=[[('checkin',10),('entrada',10),('seguranca',10),('g1',1),('F',15)],[('g0',25),('lojas',1),('g2',1),('pista',10)],[('checkin',50),('vip',1),('g3',1),('torre',25),('F',120)],[('hangar',1),('g1',75),('g4',1),('seguranca',75),('lojas',50)],[('combustivel',1),('g5',1),('pista',50),('entrada',100),('F',600)]]
flights=[0]
lv={k:0 for k in ST}
for k in ['entrada','checkin','seguranca','g0','pista','torre']: lv[k]=1
money=60; earned=0; t=0; log=[]
marks={}
while t<4*3600:
  r=rate(lv); money+=r; earned+=r; t+=1
  # compra gulosa: melhor ganho/custo
  for _ in range(5):
    best=None
    for k,(b,gr,un,kd) in ST.items():
      l=lv[k]
      if l==0:
        if kd=='g' and k!='g0' and lv['g%d'%(int(k[1])-1)]==0: continue
        if SREQ.get(k,0)>STAR[0]: continue
        c=un
      elif kd=='o': continue
      else: c=b*gr**(l-1)
      if c>money: continue
      lv2=dict(lv); lv2[k]=l+1; d=rate(lv2)-r
      sc=d/c if d>0 else 1e-12/c
      if best is None or sc>best[0]: best=(sc,k,c)
    if not best: break
    money-=best[2]; lv[best[1]]+=1
    if lv[best[1]]==1 and best[1] not in marks: marks[best[1]]=t
  flights[0]+=sum(1 for g in range(6) if lv['g%d'%g]>0)/40
  if STAR[0]<5 and all((flights[0]>=n if k=='F' else lv[k]>=n) for k,n in TASKS[STAR[0]]):
    STAR[0]+=1; marks['star%d'%STAR[0]]=t
  if t in (60,120,180,300,480,600,900,1200,1800,3600,5400,7200,14400,36000-1): log.append((t//60, round(r,1), {k:v for k,v in lv.items()}))
for k,v in sorted(marks.items(), key=lambda x:x[1]): print(k, round(v/60,1),'min')
for l in log[:8]+log[-2:]: print(l[0],'min rate',l[1], l[2])
