
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	SetOptionAtServer();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure FirstOption(Command)
	
	SetOptionAtServer(1);
	
EndProcedure

&AtClient
Procedure SecondOption(Command)
	
	SetOptionAtServer(2);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetOptionAtServer(Option = 0)
	
	Reports.PeriodClosingDates.SetOption(ThisObject, Option);
	
EndProcedure

#EndRegion
