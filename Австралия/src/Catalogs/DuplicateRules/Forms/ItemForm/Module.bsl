
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	TypeOfNewObject = Object.TypeOfNewObject;
	TypeOfExistingObject = Object.TypeOfExistingObject;
	SetExistingObjectProperties();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure TypeOfNewObjectOnChange(Item)
	
	If Object.TypeOfNewObject <> TypeOfNewObject Then
		Object.TypeOfExistingObject = PredefinedValue("Enum.DuplicateObjectsTypes.EmptyRef");
		TypeOfExistingObject = Object.TypeOfExistingObject;
		Object.MatchingCriterias.Clear();
		SetExistingObjectProperties();
	EndIf;
	
	TypeOfNewObject = Object.TypeOfNewObject;
	
EndProcedure

&AtClient
Procedure TypeOfExistingObjectOnChange(Item)
	
	If Object.TypeOfExistingObject <> TypeOfExistingObject Then
		FillMatchingCriteriasTable();
	EndIf;
	
	TypeOfExistingObject = Object.TypeOfExistingObject;

EndProcedure

#EndRegion

#Region MatchingCriteriasFormTableItemsEventHandlers

&AtClient
Procedure MatchingCriteriasBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	Cancel = True;
EndProcedure

&AtClient
Procedure MatchingCriteriasBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CheckAll(Command)
	
	For Each Criteria In Object.MatchingCriterias Do
		Criteria.Use = True;
	EndDo;
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	For Each Criteria In Object.MatchingCriterias Do
		Criteria.Use = False;
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillMatchingCriteriasTable()
	
	CriteriasArray = DuplicatesBlocking.MatchingCriteriasForObjects(
		Object.TypeOfNewObject,
		Object.TypeOfExistingObject);
		
	Object.MatchingCriterias.Clear();
	
	For Each Criteria In CriteriasArray Do
		NewLine = Object.MatchingCriterias.Add();
		FillPropertyValues(NewLine, Criteria);
	EndDo;
	
EndProcedure

&AtServer
Procedure SetExistingObjectProperties()
	
	Items.TypeOfExistingObject.Enabled = ValueIsFilled(Object.TypeOfNewObject);
	CriteriasArray = DuplicatesBlocking.MatchingObjectsForObjects(Object.TypeOfNewObject);
	Items.TypeOfExistingObject.ChoiceList.LoadValues(CriteriasArray);
	
EndProcedure

#EndRegion