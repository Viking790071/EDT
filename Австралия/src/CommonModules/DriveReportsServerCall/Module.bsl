#Region Public

Function ReportVariantSettingsLinker(ReportOptionProperties, DetailsMode = False) Export
	
	DataCompositionSchema = Common.ObjectManagerByFullName(ReportOptionProperties.ObjectKey).GetTemplate("MainDataCompositionSchema");
	DesiredReportOption = DataCompositionSchema.SettingVariants.Find(ReportOptionProperties.VariantKey);
	
	If DesiredReportOption <> Undefined Then
		SettingsComposer = New DataCompositionSettingsComposer;
		SettingsComposer.LoadSettings(DesiredReportOption.Settings);
		Return SettingsComposer;
	ElsIf DetailsMode And DataCompositionSchema.SettingVariants.Count() > 0 Then
		DefaultReportOption = DataCompositionSchema.SettingVariants[0];
		SettingsComposer = New DataCompositionSettingsComposer;
		SettingsComposer.LoadSettings(DefaultReportOption.Settings);
		Return SettingsComposer;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function ReceiveDecryptionValue(Field, Details, ReportDetailsData) Export
	
	DetailsData = GetFromTempStorage(ReportDetailsData);
	DecryptionFieldsArray = GetDecryptionFieldsArray(Details, DetailsData,, True);
	For Each FieldDetailsValue In DecryptionFieldsArray Do
		If FieldDetailsValue.Field = Field Then
			Return FieldDetailsValue.Value;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

// Returns an available field by a layout field
Function GetAvailableFieldByDataLayoutField(DataCompositionField, SearchArea) Export
	
	If TypeOf(DataCompositionField) = Type("String") Then
		AfterSearch = New DataCompositionField(DataCompositionField);
	Else
		AfterSearch = DataCompositionField;
	EndIf;
	
	If TypeOf(SearchArea) = Type("DataCompositionSettingsComposer")
		Or TypeOf(SearchArea) = Type("DataCompositionDetailsData")
		Or TypeOf(SearchArea) = Type("DataCompositionNestedObjectSettings") Then
		Return SearchArea.Settings.SelectionAvailableFields.FindField(AfterSearch);
	Else
		Return SearchArea.FindField(AfterSearch);
	EndIf;
	
EndFunction

Function GetDetailsDataStructure(Details, ReportDetailsData, CheckAvailableFields = True) Export
	
	FilterStructure = New Structure;
	DetailsData = GetFromTempStorage(ReportDetailsData);
	DecryptionFieldsArray = GetDecryptionFieldsArray(Details, DetailsData,, True, CheckAvailableFields);
	For Each FieldDetailsValue In DecryptionFieldsArray Do
		If TypeOf(FieldDetailsValue) = Type("DataCompositionDetailsFieldValue")
			And FieldDetailsValue.Value <> Null
			And StrFind(FieldDetailsValue.Field, ".") = 0 Then
			FilterStructure.Insert(FieldDetailsValue.Field, FieldDetailsValue.Value);
		EndIf;
	EndDo;
	
	Return FilterStructure;
	
EndFunction

Function PossibleDetailReports(Val ReportName, Val DetailsURL, Val Details) Export

	DetailsData = GetFromTempStorage(DetailsURL);
	
	If DetailsData = Undefined Then
		Return New ValueList;
	EndIf;
	
	PossibleDetailReports = New ValueList;
	
	CurrentDetailsItem = DetailsData.Items.Get(Details);
	FieldsOfCurrentDetailsItem = CurrentDetailsItem.GetFields();
	
	For Each Field In FieldsOfCurrentDetailsItem Do
		
		FieldValue = Field.Value;
		If ValueIsFilled(FieldValue) And Common.IsReference(TypeOf(FieldValue)) Then
			PossibleDetailReports.Add(FieldValue, StrTemplate(NStr("en = 'Open ""%1""'; ru = 'Открыть ""%1""';pl = 'Otwórz ""%1""';es_ES = 'Abrir ""%1""';es_CO = 'Abrir ""%1""';tr = '""%1"" aç';it = 'Aprire ""%1""';de = '""%1"" öffnen'"), FieldValue));
		EndIf;
		
	EndDo;
	
	DetailReports = DetailReports(DetailsData, Details, ReportName);
	
	For Each Report In DetailReports Do
		If Report.ReportGenerated Then
			DetailsValue = New Structure();
			DetailsValue.Insert("ReportName", Report.Report);
			DetailsValue.Insert("AttributeValues", Report.AttributeValues);
			
			DetailsPresentation = StringFunctionsClientServer.InsertParametersIntoString(Report.DescriptionTemplate, Report.AttributeValues);
			
			PossibleDetailReports.Add(DetailsValue, DetailsPresentation);
		EndIf;
	EndDo;
	
	Return PossibleDetailReports;
	
EndFunction

#EndRegion

#Region Private

// Returns an array according to which a report should be decrypted
Function GetDecryptionFieldsArray(Details, DetailsData, CurrentReport = Undefined, IncludeResources = False, CheckAvailableFields = True)
	
	DecryptionFieldsArray = New Array;
	
	If TypeOf(Details) <> Type("DataCompositionDetailsID") 
		And TypeOf(Details) <> Type("DataCompositionDetailsData") Then
		Return DecryptionFieldsArray;
	EndIf;
	
	If CurrentReport = Undefined Then
		CurrentReport = DetailsData;
	EndIf;
	
	// Add fields of parent groupings
	AddParents(
		DetailsData.Items[Details],
		CurrentReport,
		DecryptionFieldsArray,
		IncludeResources,
		CheckAvailableFields);
	
	Count = DecryptionFieldsArray.Count();
	For IndexOf = 1 To Count Do
		ReverseIndex = Count - IndexOf;
		For IndexInside = 0 To ReverseIndex - 1 Do
			If DecryptionFieldsArray[ReverseIndex].Field = DecryptionFieldsArray[IndexInside].Field Then
				DecryptionFieldsArray.Delete(ReverseIndex);
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	// Add filter set in the report
	For Each FilterItem In CurrentReport.Settings.Filter.Items Do
		If Not FilterItem.Use Then
			Continue;
		EndIf;
		DecryptionFieldsArray.Add(FilterItem);
	EndDo;
	
	Return DecryptionFieldsArray;
	
EndFunction

Function AddParents( ItemDetails, CurrentReport, DecryptionFieldsArray, IncludeResources = False, CheckAvailableFields = True)
	
	If TypeOf(ItemDetails) = Type("DataCompositionFieldDetailsItem") Then
		For Each Field In ItemDetails.GetFields() Do
			If CheckAvailableFields Then
				AvailableField = GetAvailableFieldByDataLayoutField(New DataCompositionField(Field.Field), CurrentReport);
				If AvailableField = Undefined Then
					Continue;
				EndIf;
				If Not IncludeResources And AvailableField.Resource Then
					Continue;
				EndIf;
			EndIf;
			
			DecryptionFieldsArray.Add(Field);
			
		EndDo;
	EndIf;
	For Each Parent In ItemDetails.GetParents() Do
		AddParents(
			Parent,
			CurrentReport,
			DecryptionFieldsArray,
			IncludeResources,
			CheckAvailableFields);
	EndDo;
	
EndFunction

Function DetailReports(DetailsData, Details, ReportName)
	
	DetailsRules = DetailsRules();
	
	Reports[ReportName].FillDetailsRules(DetailsRules);
	
	DetailItem = DetailsData.Items[Details];
	
	For Each Rule In DetailsRules Do
		
		Rule.ReportGenerated = True;
		
		For Each Attribute In Rule.RequiredAttributes Do
			
			ValueIsFilled = False;
			Sources = StrSplit(Attribute.Sources, ",", False);
			
			AttributeValue = DriveReports.FindFieldInDetailsItem(DetailItem, Sources);
			
			If AttributeValue <> Undefined Then
				Rule.AttributeValues.Insert(Attribute.Attribute, AttributeValue);
				ValueIsFilled = True;
				Continue;
			EndIf;
			
			If Not ValueIsFilled And Attribute.Value <> Undefined Then
				Rule.AttributeValues.Insert(Attribute.Attribute, Attribute.Value);
				ValueIsFilled = True;
				Continue;
			EndIf;
			
			If Not ValueIsFilled Then
				Rule.ReportGenerated = False;
				Break;
			EndIf;
			
		EndDo;
		
		If Rule.ReportGenerated Then
			
			For Each Condition In Rule.Conditions Do
				
				AttributeValue = Undefined;
				If Rule.AttributeValues.Property(Condition.Key, AttributeValue)	
					And AttributeValue <> Condition.Value Then
					
					Rule.ReportGenerated = False;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;

	Return DetailsRules;
	
EndFunction

Function DetailsRules()
	
	Rules = New ValueTable;
	
	StringType = New TypeDescription("String", , New StringQualifiers(255));
	
	StructureType = New TypeDescription("Structure");
	Rules.Columns.Add("Report",				StringType);
	Rules.Columns.Add("RequiredAttributes",	New TypeDescription("ValueTable"));
	Rules.Columns.Add("DescriptionTemplate",New TypeDescription("String"));
	Rules.Columns.Add("Conditions",			StructureType);
	Rules.Columns.Add("AttributeValues",	StructureType);
	Rules.Columns.Add("ReportGenerated",	New TypeDescription("Boolean"));
	
	Return Rules;

EndFunction

#EndRegion