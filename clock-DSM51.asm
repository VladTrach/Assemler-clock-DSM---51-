CSDS16	EQU	0FF30H	;adres zatrzasku wyboru wskaznika/wyswietlacza
CSDB16	EQU	0FF38H	;adres zatrzasku wyboru segmentуw/wzorkуw

ADRES 	EQU 	7AH    	;7A - 7F
CZAS	EQU 	79H     ;79 - 77

KeyCount EQU	76h	;zlicza powturzenia klawisza
AgrKey	EQU	75h	;agregowany stan klawiatury sekwencyjnej
PrvKey	EQU	74h	;poprzedni stan klawiatury sekwencyjnej

CountLow EQU 	73H
CountHig EQU    72H

UNITS	 EQU    71H

T0IB	BIT	7FH
ESC	BIT	7EH

SEGOFF	BIT	P1.6	
SEQKEY	EQU	P3.5	

;=======================================

;	RESET
;
	ORG	00H	;reset
	LJMP	START	

;=======================================
;        	TIMER 0 INTERRUPT
	ORG	0BH

	LJMP	TI0MAIN	


;=======================================
;	TIMER 0 INTERRUPT MAIN
	ORG	0B0H			

TI0MAIN:
	PUSH	ACC			
	PUSH	PSW			

	MOV	TH0, #255 - 3	

	MOV	A, #256 - 154 + 1	
	ADD	A, TL0		
	MOV	TL0, A		

	JNC	TI0MAIN_TH0_OK	
	INC	TH0			

TI0MAIN_TH0_OK:			

	POP	PSW			
	POP	ACC			

	SETB	T0IB			

	RETI				

;=======================================
;	PROGRAM

	ORG	100H
START:
	CLR 	ESC

	MOV 	UNITS,#0

	MOV 	CountLow, #0
      	MOV	CountHig, #0

      	MOV	IE,	#00h	;blokada wszystkich przerwan

	MOV	TMOD,	#71h	;T1.GATE=0 T1.C/T=C T1.MODE=3 T0.GATE=0 T1.C/T=T T0.MODE=1
	MOV	TCON,	#10h	
	SETB	ET0		
	SETB	EA		

	MOV CZAS,#0H
	MOV CZAS-1,#0H
    	MOV CZAS-2,#0H
    	
	;LCALL	UpdateTime

LoopIniKey:
	MOV	PrvKey, AgrKey
	MOV 	AgrKey,#0
	MOV	KeyCount,#35

LoopIni:

	MOV	R0, #ADRES		
				
	MOV	R6, #1		

LoopRun:
	JNB	T0IB, LoopRun	;czeka na przerwanie
	
	CLR	T0IB

	JB	ESC,ISESC
	SJMP	INCTIME 
ISESC:
        LCALL   UpdateTime
	SJMP	ESCEND

INCTIME:
        INC 	CountLow
	MOV 	A, CountLow
	CJNE	A,#0FFH,NEXTC
	MOV 	CountLow,#0
	INC 	CountHig
NEXTC:

     	MOV     A, CountHig
     	CJNE    A, #03H, NO
	MOV	A, CountLow
     	CJNE	A, #0E8H, NO
     	MOV	CountHig, #0
     	MOV	CountLow, #0
	LCALL	IncRealTime
	LCALL   UpdateTime

NO:
ESCEND:

        MOV  	A,@R0
	MOV	DPTR, #WZORY	;adres wzorkуw do DPTR
	MOVC	A, @A+DPTR	

        CJNE R0, #ADRES+4, bez_kropkih
	ORL A, #10000000B
bez_kropkih:

        CJNE R0, #ADRES+2, bez_kropkim
	ORL A, #10000000B
bez_kropkim:

	MOV	DPTR, #CSDB16	

	SETB	SEGOFF

	MOVX	@DPTR, A	

 	MOV	DPTR, #CSDS16

	MOV	A, R6
			
	MOVX	@DPTR, A	
	CLR	SEGOFF

	JNB	SEQKEY, LoopRunNoKey	
						
	ORL	AgrKey, A		

LoopRunNoKey:

	RL	A		
	MOV	R6, A		
        INC	R0

	CJNE	R0, #ADRES+6, LoopRun	

	MOV	A,AgrKey
	CJNE	A,PrvKey,LoopIniKey

	DJNZ	KeyCount,LoopIni


      	JNB	ESC,NoEdit

        MOV	A,#00000100B
        ANL	A,AgrKey
        JZ	NoRight
        LCALL   ToRight
NoRight:

	MOV	A,#00100000B
        ANL	A,AgrKey
        JZ	NoLeft
        LCALL   ToLeft
NoLeft:

        MOV	A,#00001000B
        ANL	A,AgrKey
        JZ	NoIncEditTime
	LCALL   IncEditTime
NoIncEditTime:

        MOV	A,#00010000B
        ANL	A,AgrKey
        JZ	NoDecEditTime
        LCALL   DecEditTime
NoDecEditTime:

        MOV	A,#00000001B
        ANL	A,AgrKey
        JZ	NoEnter
        CLR	ESC
NoEnter:

NoEdit:

       	MOV	A,#00000010B
	ANL	A,AgrKey
	JZ	NoEsc
      	SETB	ESC
NoEsc:

	LJMP	LoopIniKey		

;============================================
IncRealTime:
	INC CZAS
	MOV A,CZAS
	CJNE A, #60,NEXT
	     MOV CZAS,#0

	INC CZAS-1
	MOV A,CZAS-1
	CJNE A, #60H,NEXT
	     MOV CZAS-1,#0

	INC CZAS-2
	MOV A,CZAS-2
	CJNE A, #24H,NEXT
 	     MOV CZAS-2,#0
NEXT:
      	RET
      	

;============================================
UpdateTime:
	MOV A,CZAS
	MOV B,#10
	DIV AB
	MOV ADRES,B
	MOV ADRES+1,A

        MOV A,CZAS-1
	MOV B,#10
	DIV AB
	MOV ADRES+2,B
	MOV ADRES+3,A

        MOV A,CZAS-2
	MOV B,#10
	DIV AB
	MOV ADRES+4,B
	MOV ADRES+5,A
RET

;============================================
ToRight:
	MOV 	A,UNITS
	CJNE	A,#0,DECUNITS
	MOV	UNITS,#2
	RET

DECUNITS:
	 DEC	UNITS
	 RET


;============================================
ToLeft:
	MOV 	A,UNITS
	CJNE	A,#2,INCUNITS
	MOV	UNITS,#0
	RET

INCUNITS:
	 INC	UNITS
	 RET


;============================================
DecEditTime:
        MOV	A,#CZAS
        SUBB	A,UNITS
        MOV	R1,A
        DEC	@R1

	MOV	A,UNITS
        CJNE A,#2,NOHOURS

	CJNE	@R1,#255,RetDec
	MOV	@R1,#23
	RET
NOHOURS:
	CJNE	@R1,#255,RetDec
        MOV 	@R1,#59
RetDec:
       	RET


;============================================
IncEditTime:
	MOV	A,#CZAS
        SUBB	A,UNITS
        MOV	R1,A
        INC	@R1

	MOV	A,UNITS
	CJNE A,#2, INCNOHOURS

	CJNE @R1, #24,IncEditTimeRet
 	MOV @R1,#0
 	RET
INCNOHOURS:
        CJNE    @R1,#60,IncEditTimeRet
        MOV	@R1,#0

IncEditTimeRet:
       	RET

WZORY:
	DB	00111111B, 00000110B, 01011011B, 01001111B	;0123
	DB	01100110B, 01101101B, 01111101B, 00000111B	;4567
	DB	01111111B, 01101111B, 01110111B, 01111100B	;89Ab
	DB	01011000B, 01011110B, 01111001B, 01110001B	;cdEF
end
