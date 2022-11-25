
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	OwnerFormUUID 	= Parameters.OwnerFormUUID;
	ConnectionKey 	= Parameters.ConnectionKey;
	DocumentType 	= Parameters.DocumentType;
	DataSource 		= Parameters.DataSource;
	
	If ValueIsFilled(Parameters.AddressInTemporaryStorage) Then
		
		AddressInTemporaryStorage = Parameters.AddressInTemporaryStorage;		
		
		SavedEntriesFilters = GetFromTempStorage(AddressInTemporaryStorage);

		EntriesFilters.Load(SavedEntriesFilters);
		
	EndIf; 	
	
	If Parameters.Property("ReadOnly") And TypeOf(Parameters.ReadOnly) = Type("Boolean") Then
		ThisObject.Enabled 	 = Not Parameters.ReadOnly;
		Items.Header.Visible = Not Parameters.ReadOnly;
	EndIf;
	
	If Parameters.Property("ParameterSynonymTitle") Then
		Items.EntriesFiltersParameterSynonym.Title = Parameters.ParameterSynonymTitle;
	EndIf;
	
EndProcedure

&AtClient
Procedure Confirm(Command)
	
	If Not CheckFiltersFilling() Then
		Return;
	EndIf;
	
	SavedSuccess = SaveFiltersInput();
	If SavedSuccess Then
	
		ReturnStructure = New Structure("RowKey, AddressInTemporaryStorage", ConnectionKey, AddressInTemporaryStorage);
		Notify("EntiesFiltersEdit", 
			ReturnStructure, 
			?(OwnerFormUUID = New UUID("00000000-0000-0000-0000-000000000000"), Undefined, OwnerFormUUID));
		Close();
	
	EndIf; 
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersEntriesFilters

&AtClient
Procedure EntriesFiltersParameterSynonymStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
		
	FieldsArray = New Array;
	FieldsArray.Add(New Structure("Name, Synonym, ObjectName", "DocumentType", NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"), "Object"));
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(ThisObject, FieldsArray) Then
		Return;
	EndIf;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("DocumentType"  , DocumentType);
	ChoiceFormParameters.Insert("DataSource"	, DataSource);
	ChoiceFormParameters.Insert("AttributeName" , NStr("en = 'parameter'; ru = 'параметр';pl = 'parametr';es_ES = 'parámetro';es_CO = 'parámetro';tr = 'parametre';it = 'parametro';de = 'Parameter'"));
	ChoiceFormParameters.Insert("AttributeID"	, "Parameter");
	ChoiceFormParameters.Insert("CurrentValue"  , Items.EntriesFilters.CurrentData.ParameterName);
	
	ParametersChoiceNotification = New NotifyDescription("ParametersParameterChoiceEnding", ThisObject);
	
	OpenForm("CommonForm.ArbitraryParametersChoiceForm",
		ChoiceFormParameters,
		ThisObject,
		,
		,
		,
		ParametersChoiceNotification,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ParametersParameterChoiceEnding(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) <> Type("Structure") Then
		Return;
	EndIf;

	CurrentData = Items.EntriesFilters.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OwnerObject = ThisObject.FormOwner.Object;
	
	CurrentData.ParameterName 		= ClosingResult.Field;	
	CurrentData.ParameterSynonym 	= ClosingResult.Synonym;	
	CurrentData.ValueType 			= ClosingResult.ValueType;
	CurrentData.ValuePresentation   = ClosingResult.ValueType.AdjustValue(CurrentData.ValuePresentation);
	CurrentData.MultipleValuesMode  = WorkWithArbitraryParametersClient.ListSelectionIsAvailable(CurrentData.ConditionPresentation);

	If CurrentData.ValuesConnectionKey = 0 Then
		DriveClientServer.FillConnectionKey(OwnerObject.EntriesFilters, CurrentData, "ValuesConnectionKey", ValuesConnectionKey);
	EndIf;
	
	ValueListOneValue = New ValueList;
	ValueListOneValue.Add(CurrentData.ValuePresentation, , True);
	
	
	WorkWithArbitraryParametersClient.SaveValueListByConnectionKey(
		OwnerObject.ParametersValues, 
		ValueListOneValue, 
		"EntriesFilters", 
		CurrentData.ValuesConnectionKey, 
		"ConnectionKey");

	NewConditionList = Undefined;
	WorkWithArbitraryParametersClient.SetAvailableComparasingTypesList(CurrentData, NewConditionList, True);
	
	If NewConditionList.FindByValue(CurrentData.ConditionPresentation) = Undefined Then
		CurrentData.ConditionPresentation = NewConditionList[0].Value;
		EntriesFiltersConditionPresentationOnChange("");
	EndIf;
	
EndProcedure

&AtClient
Procedure EntriesFiltersValueOnChange(Item)
	
	CurrentData = Items.EntriesFilters.CurrentData;
	If CurrentData = Undefined Or CurrentData.MultipleValuesMode Then
		Return;
	EndIf;

	ValueListOneValue = New ValueList;
	ValueListOneValue.Add(CurrentData.ValuePresentation, , True);
	
	OwnerObject = ThisObject.FormOwner.Object;
	
	If CurrentData.ValuesConnectionKey = 0 Then
		DriveClientServer.FillConnectionKey(OwnerObject.EntriesFilters, CurrentData, "ValuesConnectionKey", ValuesConnectionKey);
	EndIf;

	WorkWithArbitraryParametersClient.SaveValueListByConnectionKey(
		OwnerObject.ParametersValues,
		ValueListOneValue, 
		"EntriesFilters",
		CurrentData.ValuesConnectionKey,
		"ConnectionKey");
	
EndProcedure

&AtClient
Procedure EntriesFiltersValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.EntriesFilters.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.MultipleValuesMode Then
		OpenInputValuesInListForm();
		StandardProcessing = False;	
	EndIf; 	
	
	ParameterNameArray = StrSplit(CurrentData.ParameterName, ".");
	
	If ParameterNameArray.Count() < 3 Or ParameterNameArray[1] <> "AdditionalAttribute" Then
		Return;
	EndIf; 	
	
	SelectionFormOwner = WorkWithArbitraryParametersClient.GetAdditionalParameterType(ParameterNameArray[2]);
	
	FormFilter = New Structure("Owner", SelectionFormOwner);
	
	FormParameters = New Structure("Filter", FormFilter);
	FormParameters.Insert("ChoiceMode", True);
	
	OpenForm("Catalog.ObjectsPropertiesValues.ChoiceForm", FormParameters, ThisObject);

EndProcedure

&AtClient
Procedure EntriesFiltersConditionPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.EntriesFilters.CurrentData;
	
	FieldsArray = New Array;
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Name"		, "ParameterSynonym");
	FieldStructure.Insert("Synonym"		, NStr("en = 'Parameter'; ru = 'Параметр';pl = 'Parametr';es_ES = 'Parámetro';es_CO = 'Parámetro';tr = 'Parametre';it = 'Parametro';de = 'Parameter'"));
	FieldStructure.Insert("ObjectName"	, "EntriesFilters");
	FieldStructure.Insert("RowCount"	, EntriesFilters.IndexOf(CurrentData));
	
	If Not WorkWithArbitraryParametersClient.FieldsArrayFillCheckProcessing(CurrentData, FieldsArray) Then
		
		StandardProcessing = False;
		Return;
		
	EndIf;
	
	WorkWithArbitraryParametersClient.SetAvailableComparasingTypesList(CurrentData, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure EntriesFiltersConditionPresentationOnChange(Item)
	
	CurrentData = Items.EntriesFilters.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	CurrentMultipleValuesMode = CurrentData.MultipleValuesMode;
	
	CurrentData.MultipleValuesMode = WorkWithArbitraryParametersClient.ListSelectionIsAvailable(CurrentData.ConditionPresentation);
	
	If CurrentData.MultipleValuesMode <> CurrentMultipleValuesMode And CurrentMultipleValuesMode Then		
		OwnerObject = ThisObject.FormOwner.Object;

		WorkWithArbitraryParametersClient.ProcessMultipleToSingleValue(
			OwnerObject.ParametersValues, 
			"EntriesFilters", 
			CurrentData);		
	EndIf;	

EndProcedure

&AtClient
Procedure OpenInputValuesInListForm()
	
	OwnerObject = ThisObject.FormOwner.Object;

	ChoiceFormParameters = WorkWithArbitraryParametersClient.FilterSelectionParameters(
		Items.EntriesFilters.CurrentData, 
		OwnerObject.ParametersValues);
																		
	Handler = New NotifyDescription("ListCompleteChoice", ThisObject);
		
	OpenForm("CommonForm.InputValuesInListWithCheckBoxes", ChoiceFormParameters, ThisObject, , , , Handler, FormWindowOpeningMode.LockOwnerWindow); 	

EndProcedure 

&AtClient
Procedure ListCompleteChoice(SelectionResult, HandlerParameters) Export
	
	If TypeOf(SelectionResult) <> Type("ValueList") Then
		Return;
	EndIf;
	
	CurrentData = Items.EntriesFilters.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OwnerObject = ThisObject.FormOwner.Object;
	
	If CurrentData.ValuesConnectionKey = 0 Then
		DriveClientServer.FillConnectionKey(OwnerObject.EntriesFilters, CurrentData, "ValuesConnectionKey", ValuesConnectionKey);
	EndIf;
	
	WorkWithArbitraryParametersClient.SaveValueListByConnectionKey(
		OwnerObject.ParametersValues, 
		SelectionResult, 
		"EntriesFilters", 
		CurrentData.ValuesConnectionKey, 
		"ConnectionKey");
		
	CurrentData.ValuePresentation = WorkWithArbitraryParametersClient.ValueArrayPresentation(SelectionResult);
	
EndProcedure

&AtClient
Procedure EntriesFiltersOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		
		OwnerObject = ThisObject.FormOwner.Object;
		
		Item.CurrentData.ValuesConnectionKey = 0;
		DriveClientServer.FillConnectionKey(OwnerObject.EntriesFilters, Item.CurrentData, "ValuesConnectionKey", ValuesConnectionKey);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function SaveFiltersInput()
		
	AddressInTemporaryStorage = PutToTempStorage(EntriesFilters.Unload());
	Modified = False;
	
	Return True;

EndFunction

&AtClient
Function CheckFiltersFilling()

	EmptyParamFilter = New Structure("ParameterName", "");
	EmptyParamRows	 = EntriesFilters.FindRows(EmptyParamFilter);
	
	For Each EmptyParam In EmptyParamRows Do
		
		MessageText = NStr("en = '""Parameter"" is required'; ru = 'Укажите параметр';pl = '""Parametr"" jest wymagany';es_ES = '""Parámetro"" es requerido';es_CO = '""Parámetro"" es requerido';tr = '""Parametre"" gereklidir';it = '""Parametro"" è richiesto';de = '""Parameter"" ist ein Pflichtfeld'");
		MessageField = StrTemplate("EntriesFilters[%1].ParameterSynonym", EntriesFilters.IndexOf(EmptyParam));
		CommonClientServer.MessageToUser(MessageText, , MessageField);
		
	EndDo;

	Return (EmptyParamRows.Count() = 0)
	
EndFunction 

#EndRegion
