$PROBLEM PK-PD indirect response

$INPUT ID TIME DV AMT CMT MDV EVID

$DATA 

$SUBROUTINES ADVAN6 TRANS1 TOL=5

$MODEL 
  COMP=(PK) 
  COMP=(PD)

$PK
  CL   = THETA(1) * EXP(ETA(1))
  V    = THETA(2) * EXP(ETA(2))
  S1   = V
  BASE = THETA(3) * EXP(ETA(3))
  IF (A_0FLG.EQ.1) THEN
    A_0(1) = BASE
  ENDIF
  KIN  = THETA(4)                
  EMAX = THETA(5) * EXP(ETA(4))   
  IC50 = THETA(6)
  KOUT = KIN/BASE
  
$DES 
  DADT(1) = -CL/V * A(1)
  DADT(2) = KIN - KOUT * (1+ (EMAX*DLEV)/(ED50+DLEV)) * A(1)
  
$ERROR
IPRED = F
IF (CMT.EQ.1) THEN
  Y = IPRED + EPS(1) 
ELSE
  Y = IPRED + EPS(2)
ENDIF
W = 1
RES = DV-IPRED
IWRES = RES/W

$THETA
(1, 5, 50)    ; CL
(1, 50, 150)  ; V
(0.1, 0.5, 2) ; KA

$OMEGA BLOCK(2)
(0.2) ; IIV CL
(0.1) ; CL~V
(0.2) ; IIV V
$OMEGA 
(0.2) ; KA

$SIGMA
(0.2) ; Additional error PK
(0.2) ; Additinoal error PD

$EST METHOD=1 INTER MAXEVAL=2000 NOABORT SIG=3 PRINT=1 POSTHOC
$COV 

$TABLE ID TIME DV MDV EVID IPRED IWRES FILE=sdtab004
$TABLE CL V KA Q V3 FIRSTONLY FILE=patab001
  
