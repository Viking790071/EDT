#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	List.Parameters.SetParameterValue("CurrentDate", CurrentSessionDate());
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion