
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	CloseOnOwnerClose = True;
	CloseOnChoice = False;
	
	Object.InfobaseNode = Parameters.InfobaseNode;
	
	SelectionTree = FormAttributeToValue("AvailableObjectKinds");
	SelectionTreeRows = SelectionTree.Rows;
	SelectionTreeRows.Clear();
	
	AllData = DataExchangeCached.ExchangePlanContent(Object.InfobaseNode.Metadata().Name);

	// Hiding items with NotExport set.
	NotExportMode = Enums.ExchangeObjectExportModes.DoNotExport;
	ExportModes   = DataExchangeCached.UserExchangePlanComposition(Object.InfobaseNode);
	Position = AllData.Count() - 1;
	While Position >= 0 Do
		DataString = AllData[Position];
		If ExportModes[DataString.FullMetadataName] = NotExportMode Then
			AllData.Delete(Position);
		EndIf;
		Position = Position - 1;
	EndDo;
	
	// Removing standard metadata picture.
	AllData.FillValues(-1, "PictureIndex");
	
	AddAllObjects(AllData, SelectionTreeRows);
	
	ValueToFormAttribute(SelectionTree, "AvailableObjectKinds");
	
	ColumnsToSelect = "";
	For Each Attribute In GetAttributes("AvailableObjectKinds") Do
		ColumnsToSelect = ColumnsToSelect + "," + Attribute.Name;
	EndDo;
	ColumnsToSelect = Mid(ColumnsToSelect, 2);
	
EndProcedure

#EndRegion

#Region AvailableObjectKindFormTableElementEventHandlers

&AtClient
Procedure AvailableObjectKindSelection(Item, RowSelected, Field, StandardProcessing)
	ExecuteSelection(RowSelected);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure PickAndClose(Command)
	ExecuteSelection();
	Close();
EndProcedure

&AtClient
Procedure Select(Command)
	ExecuteSelection();
EndProcedure

#EndRegion

#Region Private

&AtServer
Function ThisObject(NewObject = Undefined)
	If NewObject=Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(NewObject, "Object");
	Return Undefined;
EndFunction

&AtClient
Procedure ExecuteSelection(SelectedRow = Undefined)
	
	FormTable = Items.AvailableObjectKinds;
	ChoiceData = New Array;
	
	If SelectedRow = Undefined Then
		For Each Row In FormTable.SelectedRows Do
			ChoiceItem = New Structure(ColumnsToSelect);
			FillPropertyValues(ChoiceItem, FormTable.RowData(Row) );
			ChoiceData.Add(ChoiceItem);
		EndDo;
		
	ElsIf TypeOf(SelectedRow) = Type("Array") Then
		For Each Row In SelectedRow Do
			ChoiceItem = New Structure(ColumnsToSelect);
			FillPropertyValues(ChoiceItem, FormTable.RowData(Row) );
			ChoiceData.Add(ChoiceItem);
		EndDo;
		
	Else
		ChoiceItem = New Structure(ColumnsToSelect);
		FillPropertyValues(ChoiceItem, FormTable.RowData(SelectedRow) );
		ChoiceData.Add(ChoiceItem);
	EndIf;
	
	NotifyChoice(ChoiceData);
EndProcedure

&AtServer
Procedure AddAllObjects(AllRefNodeData, DestinationRows)
	
	ThisDataProcessor = ThisObject();
	
	DocumentsGroup = DestinationRows.Add();
	DocumentsGroup.ListPresentation = ThisDataProcessor.AllDocumentsFilterGroupTitle();
	DocumentsGroup.FullMetadataName = ThisDataProcessor.AllDocumentsID();
	DocumentsGroup.PictureIndex = 7;
	
	CatalogGroup = DestinationRows.Add();
	CatalogGroup.ListPresentation = ThisDataProcessor.AllCatalogsFilterGroupTitle();
	CatalogGroup.FullMetadataName = ThisDataProcessor.AllCatalogsID();
	CatalogGroup.PictureIndex = 3;
	
	For Each Row In AllRefNodeData Do
		If Row.SelectPeriod Then
			FillPropertyValues(DocumentsGroup.Rows.Add(), Row);
		Else
			FillPropertyValues(CatalogGroup.Rows.Add(), Row);
		EndIf;
	EndDo;
	
	// Deleting empty items
	If DocumentsGroup.Rows.Count() = 0 Then
		DestinationRows.Delete(DocumentsGroup);
	EndIf;
	If CatalogGroup.Rows.Count() = 0 Then
		DestinationRows.Delete(CatalogGroup);
	EndIf;
	
EndProcedure

#EndRegion
