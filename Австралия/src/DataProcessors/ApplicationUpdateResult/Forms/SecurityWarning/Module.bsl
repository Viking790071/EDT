
#Region FormCommandHandlers

&AtClient
Procedure ContinueOpening(Command)
	Close(True);
EndProcedure

&AtClient
Procedure Cancel(Command)
	Close(False);
EndProcedure

#EndRegion
