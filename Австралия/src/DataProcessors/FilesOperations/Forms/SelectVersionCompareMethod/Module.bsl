
#Region FormCommandHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	ClearMessages();
	If NOT CheckFilling() Then
		Return;
	EndIf;
	
	StructuresArray = New Array;
	
	Item = New Structure;
	Item.Insert("Object", "FileComparisonSettings");
	Item.Insert("Settings", "FileVersionsComparisonMethod");
	Item.Insert("Value", FileVersionsComparisonMethod);
	StructuresArray.Add(Item);
	
	CommonServerCall.CommonSettingsStorageSaveArray(StructuresArray, True);
	
	SelectionResult = DialogReturnCode.OK;
	NotifyChoice(SelectionResult);
	
EndProcedure

#EndRegion
