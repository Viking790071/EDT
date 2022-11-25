// The following parameters must be set:
//
// ObjectToMap   - String - object description of the current application.
// Application1               - String - a name of a correspondent application.
// Application2               - String - a name of the current application.
//
// UsedFieldList - ValueList - fields for mapping.
//     Value      - String - a field name,
//     Presentation - String - field description (title).
//     Mark       - Boolean - a flag showing whether the field is used now.
//
// MaxUserFields - Number - a maximum number of mapping fields.
//
// StartRowSerialNumber - Number - a key of the current input table row.
//
// TempStorageAddress - String - an address of input mapping table. The table contains the following columns
//     PictureIndex   - Number
//     SerialNumber   - Number - a unique string key.
//     SortingField1  - String, the first attribute value from the list of mapping fields.
//     ...
//     SortingFieldNN - String, the NN attribute value from the list of mapping fields.
//
// After the form is opened, data with the TempStorageAddress will be removed from the temporary storage.
//

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ObjectToMap = Parameters.ObjectToMap;
	
	Items.ObjectToMap.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru='Объект в ""%1""'; en = 'Object in ""%1""'; pl = 'Obiekt w ""%1""';es_ES = 'Objeto en ""%1""';es_CO = 'Objeto en ""%1""';tr = '""%1"" ''deki nesne';it = 'Oggetto in ""%1""';de = 'Objekt in ""%1""'"), Parameters.Application1);
		
	Items.Header.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru='Объект в ""%1""'; en = 'Object in ""%1""'; pl = 'Obiekt w ""%1""';es_ES = 'Objeto en ""%1""';es_CO = 'Objeto en ""%1""';tr = '""%1"" ''deki nesne';it = 'Oggetto in ""%1""';de = 'Objekt in ""%1""'"), Parameters.Application2);
	
	// Setting up choise table on the form.
	GenerateChoiceTable(Parameters.MaxUserFields, Parameters.UsedFieldsList, 
		Parameters.TempStorageAddress);
		
	SetChoiceTableCursor(Parameters.StartRowSerialNumber);
EndProcedure

#EndRegion

#Region ChoiceTableFormTableItemEventHandlers

&AtClient
Procedure ChoiceTableChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	MakeChoice(RowSelected);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	MakeChoice(Items.ChoiceTable.CurrentRow);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure MakeChoice(Val SelectionRowID)
	If SelectionRowID=Undefined Then
		Return;
	EndIf;
		
	ChoiceData = ChoiceTable.FindByID(SelectionRowID);
	If ChoiceData<>Undefined Then
		NotifyChoice(ChoiceData.SerialNumber);
	EndIf;
	
EndProcedure

&AtServer
Procedure GenerateChoiceTable(Val FieldsTotal, Val UsedFields, Val DataAddress)
	
	// Adding attribute columns.
	ItemsToAdd = New Array;
	StringType   = New TypeDescription("String");
	For FieldNumber=1 To FieldsTotal Do
		ItemsToAdd.Add(New FormAttribute("SortField" + Format(FieldNumber, "NZ=; NG="), StringType, "ChoiceTable"));
	EndDo;
	ChangeAttributes(ItemsToAdd);
	
	// Adding on form
	Columns_Group = Items.FieldsGroup;
	ItemType   = Type("FormField");
	ListSize  = UsedFields.Count() - 1;
	
	For FieldNumber=0 To FieldsTotal-1 Do
		Attribute = ItemsToAdd[FieldNumber];
		
		NewColumn = Items.Add("ChoiceTable" + Attribute.Name, ItemType, Columns_Group);
		NewColumn.DataPath = Attribute.Path + "." + Attribute.Name;
		If FieldNumber<=ListSize Then
			Field = UsedFields[FieldNumber];
			NewColumn.Visible = Field.Check;
			NewColumn.Title = Field.Presentation;
		Else
			NewColumn.Visible = False;
		EndIf;
	EndDo;
	
	// Filling the selection table and clearing data in the temporary storage.
	If Not IsBlankString(DataAddress) Then
		ChoiceTable.Load( GetFromTempStorage(DataAddress) );
		DeleteFromTempStorage(DataAddress);
	EndIf;
EndProcedure

&AtServer
Procedure SetChoiceTableCursor(Val StartRowSerialNumber)
	
	For Each Row In ChoiceTable Do
		If Row.SerialNumber=StartRowSerialNumber Then
			Items.ChoiceTable.CurrentRow = Row.GetID();
			Break;
			
		ElsIf Row.SerialNumber>StartRowSerialNumber Then
			PreviousRowIndex = ChoiceTable.IndexOf(Row) - 1;
			If PreviousRowIndex>0 Then
				Items.ChoiceTable.CurrentRow = ChoiceTable[PreviousRowIndex].GetID();
			EndIf;
			Break;
			
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion
