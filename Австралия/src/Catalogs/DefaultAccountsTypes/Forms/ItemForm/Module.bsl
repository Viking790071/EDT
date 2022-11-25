
#Region FormEventHandlers

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	WorkWithArbitraryParameters.SetTableValueStorageAttributesByMap(
		Object.Filters,
		CurrentObject.Filters,
		ValueStorageAttributesMap());
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	WorkWithArbitraryParameters.GetTableValueStorageAttributesByMap(
		Object.Filters,
		CurrentObject.Filters,
		ValueStorageAttributesMap());
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CopyDynamicAttributes(Parameters.CopyingValue);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	WorkWithArbitraryParameters.GetTableValueStorageAttributesByMap(
		Object.Filters,
		CurrentObject.Filters,
		ValueStorageAttributesMap());
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersFilters

&AtClient
Procedure FiltersFilterSynonymStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TempValues = Items.Filters.CurrentData.FilterName;
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("FillCatalogsFilter", True);
	ChoiceFormParameters.Insert("AttributeName"		, NStr("en = 'parameter'; ru = 'параметр';pl = 'parametr';es_ES = 'parámetro';es_CO = 'parámetro';tr = 'parametre';it = 'parametro';de = 'Parameter'"));
	ChoiceFormParameters.Insert("AttributeID"		, "FilterType");
	ChoiceFormParameters.Insert("CurrentValue"		, TempValues);
	

	OpenForm("CommonForm.ArbitraryParametersChoiceForm", 
		ChoiceFormParameters, 
		ThisObject,
		,
		,
		,
		New NotifyDescription("FilterChoiceEnding", ThisObject), 
		FormWindowOpeningMode.LockOwnerWindow);

	
EndProcedure

&AtClient
Procedure FilterChoiceEnding(ClosingResult, AdditionalParameters) Export

	If TypeOf(ClosingResult) <> Type("Structure") Then
		Return;
	EndIf;

	CurrentData = Items.Filters.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentData.FilterName		= ClosingResult.Field;
	CurrentData.FilterSynonym	= ClosingResult.Synonym;
	CurrentData.ValueType		= ClosingResult.ValueType;
	
	Modified = True;

EndProcedure

&AtClient
Procedure FiltersBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	If Object.Filters.Count() = 4 Then
		
		MessageText = NStr("en = 'Maximum 4 filters are allowed!'; ru = 'Допускается не более 4 отборов!';pl = 'Dozwolone są maksymalnie 4 filtry!';es_ES = '¡Se permite un máximo de 4 filtros!';es_CO = '¡Se permite un máximo de 4 filtros!';tr = 'En fazla 4 filtreye izin verilir!';it = 'Sono concessi massimo 4 filtri!';de = 'Maximum 4 Filter sind gestattet!'");
		MessageField = "Object.Filters[3].LineNumber";
		
		CommonClientServer.MessageToUser(MessageText, , MessageField, , Cancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure CopyDynamicAttributes(CopyingRef)
	
	If Not ValueIsFilled(CopyingRef) Then
		Return;
	EndIf;
	
	CopyingObject = CopyingRef.GetObject();
		
	FormTable		= Object.Filters;
	DBObjectTable	= CopyingObject.Filters;
	
	For Each FormTableRow In FormTable Do
		
		DBRowIndex = FormTableRow.LineNumber - 1;
		
		FormTableRow.ValueType = DBObjectTable[DBRowIndex].SavedValueType.Get();
		
	EndDo;
	
EndProcedure

&AtServer
Function ValueStorageAttributesMap()
	
	Map = New Map;
	Map.Insert("SavedValueType", "ValueType");
	
	Return Map;
	
EndFunction

#EndRegion