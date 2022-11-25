
#Region EventHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	DataTableName = Parameters.TableName;
	CurrentObject = ThisObject();
	TableHeader  = "";
	
	// Determining what kind of table is passed to the procedure.
	Details = CurrentObject.MetadataCharacteristics(DataTableName);
	MetaInfo = Details.Metadata;
	Title = MetaInfo.Presentation();
	
	// List and columns
	DataStructure = "";
	If Details.IsReference Then
		TableHeader = MetaInfo.ObjectPresentation;
		If IsBlankString(TableHeader) Then
			TableHeader = Title;
		EndIf;
		
		DataList.CustomQuery = False;
		
		ListProperties = DynamicListPropertiesStructure();
		ListProperties.DynamicDataRead = True;
		ListProperties.MainTable = DataTableName;
		
		SetDynamicListProperties(Items.DataList, ListProperties);
		
		Field = DataList.Filter.FilterAvailableFields.Items.Find(New DataCompositionField("Ref"));
		ColumnsTable = New ValueTable;
		Columns = ColumnsTable.Columns;
		Columns.Add("Ref", Field.ValueType, TableHeader);
		DataStructure = "Ref";
		
		DataFormKey = "Ref";
		
	ElsIf Details.IsSet Then
		Columns = CurrentObject.RecordSetDimensions(MetaInfo);
		For Each CurrentColumnItem In Columns Do
			DataStructure = DataStructure + "," + CurrentColumnItem.Name;
		EndDo;
		DataStructure = Mid(DataStructure, 2);
		
		DataList.CustomQuery = True;
		
		ListProperties = DynamicListPropertiesStructure();
		ListProperties.DynamicDataRead = True;
		ListProperties.QueryText = "SELECT DISTINCT " + DataStructure + " FROM " + DataTableName;
		
		SetDynamicListProperties(Items.DataList, ListProperties);
		
		If Details.IsSequence Then
			DataFormKey = "Recorder";
		Else
			DataFormKey = New Structure(DataStructure);
		EndIf;
			
	Else
		// No columns
		Return;
	EndIf;
	
	CurrentObject.AddColumnsToFormTable(
		Items.DataList, 
		"Order, Filter, Group, StandardPicture, Parameters, ConditionalAppearance",
		Columns);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers
//

&AtClient
Procedure FilterOnChange(Item)
	
	Items.DataList.Refresh();
	
EndProcedure

#EndRegion

#Region DataListFormTableItemEventHandlers
//

&AtClient
Procedure DataListSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	OpenCurrentObjectForm();
EndProcedure

#EndRegion

#Region FormCommandHandlers
//

&AtClient
Procedure OpenCurrentObject(Command)
	OpenCurrentObjectForm();
EndProcedure

&AtClient
Procedure SelectFilteredValues(Command)
	MakeChoice(True);
EndProcedure

&AtClient
Procedure SelectCurrentRow(Command)
	MakeChoice(False);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetDynamicListProperties(List, ParametersStructure)
	
	Form = List.Parent;
	ManagedFormType = Type("ClientApplicationForm");
	
	While TypeOf(Form) <> ManagedFormType Do
		Form = Form.Parent;
	EndDo;
	
	DynamicList = Form[List.DataPath];
	QueryText = ParametersStructure.QueryText;
	
	If Not IsBlankString(QueryText) Then
		DynamicList.QueryText = QueryText;
	EndIf;
	
	MainTable = ParametersStructure.MainTable;
	
	If Not IsBlankString(MainTable) Then
		DynamicList.MainTable = MainTable;
	EndIf;
	
	DynamicDataRead = ParametersStructure.DynamicDataRead;
	
	If TypeOf(DynamicDataRead) = Type("Boolean") Then
		DynamicList.DynamicDataRead = DynamicDataRead;
	EndIf;
	
EndProcedure

&AtServer
Function DynamicListPropertiesStructure()
	
	Return New Structure("QueryText, MainTable, DynamicDataRead");
	
EndFunction

&AtClient
Procedure OpenCurrentObjectForm()
	CurParameters = CurrentObjectFormParameters(Items.DataList.CurrentData);
	If CurParameters <> Undefined Then
		OpenForm(CurParameters.FormName, CurParameters.Key);
	EndIf;
EndProcedure

&AtClient
Procedure MakeChoice(WholeFilterResult = True)
	
	If WholeFilterResult Then
		Data = AllSelectedItems();
	Else
		Data = New Array;
		For Each curRow In Items.DataList.SelectedRows Do
			Item = New Structure(DataStructure);
			FillPropertyValues(Item, Items.DataList.RowData(curRow));
			Data.Add(Item);
		EndDo;
	EndIf;
	ParametersStructure = New Structure();
	ParametersStructure.Insert("TableName", Parameters.TableName);
	ParametersStructure.Insert("ChoiceData", Data);
	ParametersStructure.Insert("ChoiceAction", Parameters.ChoiceAction);
	ParametersStructure.Insert("FieldStructure", DataStructure);
	NotifyChoice(ParametersStructure);
EndProcedure

&AtServer
Function ThisObject(CurrentObject = Undefined) 
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function CurrentObjectFormParameters(Val Data)
	
	If Data = Undefined Then
		Return Undefined;
	EndIf;
	
	If TypeOf(DataFormKey) = Type("String") Then
		Value = Data[DataFormKey];
		CurFormName = ThisObject().GetFormName(Value) + ".ObjectForm";
	Else
		// The structure contains dimension names.
		If Data.Property("Recorder") Then
			Value = Data.Recorder;
			CurFormName = ThisObject().GetFormName(Value) + ".ObjectForm";
		Else
			FillPropertyValues(DataFormKey, Data);
			CurParameters = New Array;
			CurParameters.Add(DataFormKey);
			RecordKeyName = StrReplace(Parameters.TableName, ".", "RecordKey.");
			Value = New(RecordKeyName, CurParameters);
			CurFormName = Parameters.TableName + ".RecordForm";
		EndIf;
		
	EndIf;
	Result = New Structure("FormName", CurFormName);
	Result.Insert("Key", New Structure("Key", Value));
	Return Result;
EndFunction

&AtServer
Function AllSelectedItems()
	
	Data = ThisObject().DynamicListCurrentData(DataList);
	
	Result = New Array();
	For Each curRow In Data Do
		Item = New Structure(DataStructure);
		FillPropertyValues(Item, curRow);
		Result.Add(Item);
	EndDo;
	
	Return Result;
EndFunction	

#EndRegion
