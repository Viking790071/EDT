#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CalculationStartDate = CurrentSessionDate();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = Items.List.CurrentData;
	
	SelectedData = New Structure;
	SelectedData.Insert("TemplateRef", CurrentData.Ref);
	SelectedData.Insert("CalculationStartDate", CalculationStartDate);
	
	NotifyChoice(SelectedData);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OpenTemplate(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		ShowValue(Undefined, CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectTemplate(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		
		SelectedData = New Structure;
		SelectedData.Insert("TemplateRef", CurrentData.Ref);
		SelectedData.Insert("CalculationStartDate", CalculationStartDate);
		
		NotifyChoice(SelectedData);
		
	Else
		
		Close();
		
	EndIf;
	
EndProcedure

#EndRegion
