
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure MappingSettings(Command)
	
	If Items.List.CurrentRow <> Undefined Then
		OpenForm("DataProcessor.MappingSettings.Form",
			New Structure("TransformationTemplate", Items.List.CurrentRow));
	EndIf;
	
EndProcedure

#EndRegion
