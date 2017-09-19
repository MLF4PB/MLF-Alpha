﻿EnableExplicit

Global EnumHeader.s, EnumDependancies.s, EnumProcedures.s, Finalyse.b

Declare Analyse(ASMFileName.s)
Declare Parse(Buffer.s)

Procedure Analyse(ASMFileName.s)
  Protected ProcedureName.s
  Protected ASMContent.s
  Protected DESCContent.s
  Protected Token
  Protected Buffer.s, CountDependancies, LineStartDependancies = 7, CurrentLine
  Protected HelpFileName.s = "HelpFileName" 
  
  ;-Parse ASM file
  If ReadFile(0, ASMFileName) 
    While Eof(0) = 0
      Buffer = ReadString(0)
      If FindString(Buffer, "; procedure", 0, #PB_String_NoCase) And Not FindString(Buffer, "; procedurereturn", 0, #PB_String_NoCase)
        Token = #True
        ;Normalize 
                
        Repeat 
          Buffer = ReplaceString(Buffer, "  ", " ")
        Until FindString(Buffer, "  ") = 0        
        
        ASMContent + Buffer + #CRLF$
        ;Insert public PB_YourProcedure() and PB_YourProcedure after the comment line ; ProcedureDL Yourprocedure
        
        ;Example
        ; ProcedureDLL Add(x, y)
        ; public PB_Add
        ; PB_Add:
        ProcedureName = StringField(StringField(Buffer, 3, " "), 1, "(")
        
        ASMContent + "public PB_" + ProcedureName + #CRLF$
        ASMContent + "PB_" + ProcedureName + ":"+ #CRLF$ 
      Else
        If Token = #False
          ASMContent + Buffer + #CRLF$
        Else
          Token = #False
        EndIf
      EndIf
    Wend
    CloseFile(0)
  EndIf
    
  ;-Create ASM file
  If CreateFile(0, ASMFileName)
    WriteString(0, ASMContent)
    CloseFile(0)
  EndIf
  
  ;-Compose DESC Header
  EnumHeader = "ASM" + #CRLF$   ; Langage used to code the library: ASM or C
  EnumHeader + "0" + #CRLF$     ; Number of windows DLL than the library need
  EnumHeader + "OBJ" + #CRLF$   ; Library type (Can be OBJ or LIB).  
  
  ;-Extract and count dependancies (Number of PureBasic library needed by the library.)
  If ReadFile(0, ASMFileName) 
    While Eof(0) = 0
      Buffer = ReadString(0)
      If FindString(Buffer, "; :System", 0, #PB_String_NoCase)
        Break
      Else
        If CurrentLine >= LineStartDependancies
          CountDependancies + 1
          EnumDependancies + Mid(Buffer, 3) + #CRLF$
        EndIf
      EndIf
      CurrentLine + 1
    Wend
    CloseFile(0)
  EndIf
  
  ;-Extract procedures (Use the procedure Parse)
  If ReadFile(0, ASMFileName) 
    While Eof(0) = 0
      Buffer = ReadString(0)
      If FindString(Buffer, "; procedure", 0, #PB_String_NoCase)
        Parse(Buffer)
      EndIf
    Wend
    CloseFile(0)
  EndIf
  
  ;-Create DESC content filename
  DESCContent = EnumHeader + Str(CountDependancies) + #CRLF$ + #CRLF$ +
                "; " + Str(CountDependancies) + " Dependancies " + #CRLF$ +
                EnumDependancies + #CRLF$ +
                "; Your help file" + #CRLF$ +
                HelpFileName + #CRLF$ + #CRLF$ +
                "; Procedure summary" + #CRLF$ +
                EnumProcedures
  
  ;-Create DESC file
  If CreateFile(0,  GetFilePart(ASMFileName, #PB_FileSystem_NoExtension) + ".desc")
    WriteString(0, DESCContent)
    CloseFile(0) 
  EndIf
EndProcedure

;
Procedure Parse(Buffer.s)
  Protected Name.s, Parameters.s, Variable.s, DefaultValue.b, ReturnValue.s, n 
  
  Buffer = Trim(Mid(Buffer, 2, Len(Buffer)))
  Debug Buffer
  
  Select LCase(StringField(StringField(Buffer, 1, " "), 1, "."))
    Case "proceduredll", "procedurecdll"
      
      ;-Parse type de procedure
      Select  StringField(StringField(Buffer, 1, " "), 2, ".")
        Case "i", "l"
          ReturnValue =  "Long | StdCall"
          
        Case "s"
          ReturnValue = "String | StdCall"
          
        Default
          ReturnValue = "Long | StdCall"
      EndSelect
      
      ;-Procedure without variable 
      If CountString(Buffer, "()") = 1
        ReturnValue = "None | StdCall"        
      EndIf
      
      ;-Remove "ProcedureDLL"
      Buffer = Trim(Mid(Buffer, Len(Trim(StringField(Buffer, 1, " ")))+1))
      
      ;-Extract procedure name
      EnumProcedures + Trim(StringField(Buffer, 1, "(")) + ", "
      Debug EnumProcedures
      ;Parameter type
      ; (ok) Byte: The parameter will be a byte (1 byte)
      ; (ok) Word: The parameter will be a word (2 bytes)
      ; (ok) Long: The parameter will be a long (4 bytes)
      ; (ok) String: The parameter will be a string (see below For an explaination of string handling)
      ; (ok) Quad: The parameter will be a quad (8 bytes)
      ; (ok) Float: The parameter will be a float (4 bytes)
      ; (ok) Double: The parameter will be a double (8 bytes)
      ; Any: The parameter can be anything (the compiler won't check the type)
      ; (ok) Array: The parameter will be an Array. It will have To be passed like: Array()
      ; LinkedList: The parameter will be an linkedlist. It will have To be passed like: List()
      
      ;Remove first bracket and last bracket
      Parameters =  Mid(Buffer, FindString(Buffer, "("), Len(Buffer) -1)
      Buffer = Mid(Parameters, 2, Len(Parameters) - 2)
      
      ;Parse each variable 
      For n = 1 To CountString(Buffer, ", ") + 1
        Variable = Trim(StringField(Buffer, n, ","))
        
        If FindString(Variable, "=")
          Variable = Trim(StringField(Variable, 1, "="))
          DefaultValue = #True
        EndIf
                
        Select StringField(Variable, 2, ".")
          Case "b"
            If DefaultValue
              EnumProcedures + "[Byte], "
            Else
              EnumProcedures + "Byte, "
            EndIf
            
          Case "i", "l"
            If DefaultValue
              EnumProcedures + "[Long], "
            Else
              EnumProcedures + "Long, "
            EndIf
            
          Case "d"
            If DefaultValue
              EnumProcedures + "[Double], "
            Else
              EnumProcedures + "Double, "
            EndIf
            
          Case "f"
            If DefaultValue
              EnumProcedures + "[Float], "
            Else
              EnumProcedures + "Float, "
            EndIf
            
          Case "q"
            If DefaultValue
              EnumProcedures + "[Quad], "
            Else
              EnumProcedures + "Quad, "
            EndIf
            
          Case "w"
            If DefaultValue
              EnumProcedures + "[Word], "
            Else
              EnumProcedures + "Word, "
            EndIf
            
          Case "s"
            If DefaultValue
              EnumProcedures + "[String], "
            Else
              EnumProcedures + "String, "
            EndIf
            
          Default
            If FindString(Variable, "Array", 0, #PB_String_NoCase)
              EnumProcedures + "Array, "
              
            ElseIf Not FindString(ReturnValue, "none", 0, #PB_String_NoCase)
              EnumProcedures + "Long, "
            EndIf
        EndSelect
      Next
      DefaultValue = #False
      Finalyse = #True
      
    Case "procedurereturn"
      Finalyse = #False
  EndSelect
  
  ;Finalyse
  If Finalyse = #True
    EnumProcedures + Parameters + " - " + #CRLF$  + ReturnValue + #CRLF$ + #CRLF$
  EndIf
EndProcedure
; IDE Options = PureBasic 5.60 (Windows - x86)
; CursorPosition = 211
; FirstLine = 157
; Folding = ----
; EnableXP