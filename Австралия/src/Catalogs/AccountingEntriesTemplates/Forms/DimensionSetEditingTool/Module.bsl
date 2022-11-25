#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	NameAdding				= Parameters.NameAdding;
	DataSource				= Parameters.DataSource;
	DocumentType			= Parameters.DocumentType;
	AnalyticalDimensionsSet	= Parameters.CurrentAnalyticalDimensionsSetValue;
	
	For Each Item In Parameters.CurrentAnalyticalDimensions Do
		
		NewRow = AnalyticalDimensions.Add();
		FillPropertyValues(NewRow, Item);
		NewRow.AnalyticalDimensionTypeDescription = NewRow.AnalyticalDimensionType.ValueType;
		
	EndDo;
	
	CurrentAnalyticalDimensions.Load(AnalyticalDimensions.Unload());
	
	FormManagment(Parameters.ReadOnly = True);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AnalyticalDimensionsSetOnChange(Item)
	
	GetEntriesDimensionsAtServer(AnalyticalDimensionsSet);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersEntries

&AtClient
Procedure AnalyticalDimensionsAnalyticalDimensionValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.AnalyticalDimensions.CurrentData;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DataSource"			, DataSource);
	ChoiceFormParameters.Insert("ModeSwitchAllowed"		, True);
	ChoiceFormParameters.Insert("ValueModeSwitchAllowed", True);
	ChoiceFormParameters.Insert("ValueMode"				, TypeOf(CurrentData.AnalyticalDimensionValue) <> Type("String"));
	ChoiceFormParameters.Insert("SwitchFormulaMode"		, ?(ChoiceFormParameters.ValueMode, 2, 0));
	ChoiceFormParameters.Insert("DocumentType"			, DocumentType);
	ChoiceFormParameters.Insert("FillByTypeDescription"	, True);
	ChoiceFormParameters.Insert("AttributeName"			, CurrentData.AnalyticalDimensionValueSynonym);
	ChoiceFormParameters.Insert("CurrentValue"			, CurrentData.AnalyticalDimensionValue);
	ChoiceFormParameters.Insert("TypeDescription"		, CurrentData.AnalyticalDimensionTypeDescription);
	ChoiceFormParameters.Insert("ExcludedFields"		, WorkWithArbitraryParametersClient.GetExcludedFields());
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("AttributesChoiceEnding", ThisObject),
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure AnalyticalDimensionsAnalyticalDimensionValueSynonymOnChange(Item)
	
	CurrentData = Items.AnalyticalDimensions.CurrentData;
	
	If Not ValueIsFilled(CurrentData.AnalyticalDimensionValueSynonym) Then
		CurrentData.AnalyticalDimensionValue = "";
	EndIf;
	
EndProcedure

&AtClient
Procedure AnalyticalDimensionsAnalyticalDimensionValueSynonymOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(, Items.AnalyticalDimensions.CurrentData.AnalyticalDimensionValue);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OK(Command)
	
	AnalyticalDimensionsArray = New Array;
	For Each Row In AnalyticalDimensions Do
		
		RowStructure = New Structure("AnalyticalDimensionType, AnalyticalDimensionValue, AnalyticalDimensionValueSynonym");
		FillPropertyValues(RowStructure, Row);
		
		AnalyticalDimensionsArray.Add(RowStructure);
		
	EndDo;
	
	ResultStructure = New Structure();
	ResultStructure.Insert("Field"					, AnalyticalDimensionsSet);
	ResultStructure.Insert("AnalyticalDimensions"	, AnalyticalDimensionsArray);
	ResultStructure.Insert("NameAdding"				, NameAdding);
	ResultStructure.Insert("Synonym"				, FieldSynonym);
	
	NotifyChoice(ResultStructure);
	
EndProcedure

&AtClient
Procedure Fill(Command)
	
	FieldsArray = New Array;
	FieldsArray.Add(New Structure("Name, Synonym, ObjectName", "DocumentType", NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"), "Object"));
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(ThisObject, FieldsArray) Then
		Return;
	EndIf;
	
	FillAtServer();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AttributesChoiceEnding(ClosingResult, AdditionalParameters) Export

	If TypeOf(ClosingResult) <> Type("Structure") Then
		Return;
	EndIf;
	
	CurrentData = Items.AnalyticalDimensions.CurrentData;
	
	CurrentData.AnalyticalDimensionValue 		= ClosingResult.Field;
	CurrentData.AnalyticalDimensionValueSynonym	= ClosingResult.Synonym;
	
EndProcedure

&AtServer
Procedure GetEntriesDimensionsAtServer(DimensionSet)
	
	AnalyticalDimensions.Clear();
	For Each Row In DimensionSet.AnalyticalDimensions Do
		
		NewRow = AnalyticalDimensions.Add();
		NewRow.AnalyticalDimensionType				= Row.AnalyticalDimension;
		NewRow.AnalyticalDimensionTypeDescription	= NewRow.AnalyticalDimensionType.ValueType;
		NewRow.AnalyticalDimensionValue				= "";
		
		SearchStr = New Structure("AnalyticalDimensionType", NewRow.AnalyticalDimensionType);
		FoundRows = CurrentAnalyticalDimensions.FindRows(SearchStr);
		
		If FoundRows.Count() > 0 Then
			FillPropertyValues(NewRow, FoundRows[0]);
		EndIf;
		
	EndDo;
	
	CurrentAnalyticalDimensions.Load(AnalyticalDimensions.Unload());
	
EndProcedure

&AtServer
Function FormManagment(FormReadOnly)

	Items.FormOK.Enabled												= Not FormReadOnly;
	Items.AnalyticalDimensionsFill.Enabled								= Not FormReadOnly;
	Items.AnalyticalDimensionsSet.ReadOnly								= FormReadOnly;
	Items.AnalyticalDimensionsAnalyticalDimensionValueSynonym.ReadOnly	= FormReadOnly;

EndFunction

&AtServer
Procedure FillAtServer()
	
	TempTable = New ValueTable;
	TempTable.Columns.Add("TypeDescription");
	TempTable.Columns.Add("Value");
	TempTable.Columns.Add("ValueSynonym");
	
	For Each Row In AnalyticalDimensions Do
		
		NewRow = TempTable.Add();
		NewRow.TypeDescription	= Row.AnalyticalDimensionTypeDescription;
		NewRow.Value			= Row.AnalyticalDimensionValue;
		NewRow.ValueSynonym		= Row.AnalyticalDimensionValueSynonym;
		
	EndDo;
	
	WorkWithArbitraryParameters.FillDefaultParametersInTable(DataSource, DocumentType, TempTable);
	
	For Count = 0 To TempTable.Count() - 1 Do
		
		RowTemp = TempTable[Count];
		
		Row									= AnalyticalDimensions[Count];
		Row.AnalyticalDimensionValue		= RowTemp.Value;
		Row.AnalyticalDimensionValueSynonym	= RowTemp.ValueSynonym;
		
	EndDo;
	
EndProcedure

#EndRegion