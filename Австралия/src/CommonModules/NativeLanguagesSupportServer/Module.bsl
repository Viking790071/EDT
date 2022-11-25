///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

// For calling from the OnInitialItemsFilling handler.
// Fills in columns called AttributeName_<LanguageCode> with text values for the specified language codes.
//
// Parameters:
//  Item        - ValueTableRow - a table row to fill in. With columns AttributeName_LanguageCode.
//  AttributeName   - String -  an attribute name. For example, Description.
//  SourceString - String - a string in the NStr format. For example, "ru" = 'Russian message'; en = 'English message'".
//  LanguagesCodes     - Array - codes of languages ​​in which the rows need to be filled in.
// 
// Example:
//
//  NationalLanguageSupportServer.FillMultilanguageAttribute(Item, "Description", "ru = 'Russian message'; en =
//  'English message'", LanguagesCodes);
//
Procedure FillMultilanguageAttribute(Item, AttributeName, SourceString, LanguagesCodes = Undefined) Export
	
	For each LanguageCode In LanguagesCodes Do
		Item[NameOfAttributeToLocalize(AttributeName, LanguageCode)] = NStr(SourceString, LanguageCode);
	EndDo;
	
EndProcedure

// It is called from the OnCreateAtServer handler of the object form to add an open button in the 
// field of multilanguage attributes. If you click the button, a form for entering attribute values in the used configuration languages opens.
//
// Parameters:
//    Form                - ClientApplicationForm - a form that contains multilanguage attributes.
//    Object               - Arbitrary - an object that contains the attributes.
//
Procedure OnCreateAtServer(Form, Object = Undefined, ListName = "List", ItemName = "") Export
	
	If Object <> Undefined AND NationalLanguageSupportCached.ConfigurationUsesOnlyOneLanguage(Object.Property("Presentations")) Then
		Return;
	EndIf;
	
	FormType = NationalLanguageSupportCached.DefineFormType(Form.FormName);
	
	If Object = Undefined Then
		If FormType = "DefaultListForm" Or FormType = "DefaultChoiceForm" Then
			ChangeListQueryTextForCurrentLanguage(Form, ListName, ItemName);
		EndIf;
		Return;
	EndIf;
	
	FormAttributeList = Form.GetAttributes();
	CreateMultilanguageAttributesParameters = True;
	For Each Attribute In FormAttributeList Do
		If Attribute.Name = "MultilanguageAttributesParameters" Then
			CreateMultilanguageAttributesParameters = False;
		EndIf;
	EndDo;
	
	If CreateMultilanguageAttributesParameters Then
		AttributesToAdd = New Array;
		AttributesToAdd.Add(New FormAttribute("MultilanguageAttributesParameters", New TypeDescription(),,, True));
		Form.ChangeAttributes(AttributesToAdd);
	EndIf;
	
	Form.MultilanguageAttributesParameters = New Structure;
	
	AttributesDescriptions = ObjectAttributesToLocalizeDescriptions(Object.Ref.Metadata(), "Object.");
	
	For each Item In Form.Items Do
		
		If TypeOf(Item) = Type("FormField") AND AttributesDescriptions[Item.DataPath] = True Then
			Item.OpenButton = True;
			Item.SetAction("Opening", "Attachable_Open");
			Form.MultilanguageAttributesParameters.Insert(Item.Name, Item.DataPath);
		EndIf;
		
	EndDo;
	
EndProcedure

// It is called from the OnReadAtServer handler of the object form to fill in values of the 
// multilanguage form attributes in the current user language.
//
// Parameters:
//  Form         - ClientApplicationForm - an object form.
//  CurrentObject - Arbitrary - an object received in the OnReadAtServer form handler.
//
Procedure OnReadAtServer(Form, CurrentObject) Export
	
	If IsMainLanguage() Then
		Return;
	EndIf;
	
	CurrentObject.OnReadPresentationsAtServer();
	Form.ValueToFormAttribute(CurrentObject, "Object");
	
EndProcedure

// It is called from the BeforeWriteAtServer handler of the object form or upon program object 
// writing to write multilanguage attribute values in accordance with the current user language.
//
// Parameters:
//  CurrentObject - Arbitrary - an object to be written.
//
Procedure BeforeWriteAtServer(CurrentObject) Export
	
	If CurrentLanguage().LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode() Then
		Return;
	EndIf;
	
	If MultilanguageStringsInAttributes(CurrentObject.Metadata()) Then
		
		CurrentLanguageSuffix  = "";
		
		If StrCompare(NationalLanguageSupportClientServer.DefaultLanguageCode(), CurrentLanguage().LanguageCode) <> 0 Then
			CurrentLanguageSuffix = CurrentLanguageSuffix();
		EndIf;
		
		MetadataObject = CurrentObject.Ref.Metadata();
		NamesOfAttributesToLocalize = ObjectAttributesToLocalizeDescriptions(MetadataObject);
		
		For Each Attribute In NamesOfAttributesToLocalize Do
			
			If Common.IsCatalog(MetadataObject)
				And Not Common.IsStandardAttribute(MetadataObject.StandardAttributes, Attribute.Key)
				And Not DriveServer.AttributeExistsForObject(CurrentObject, Attribute.Key) Then
				Continue;
			EndIf;
			
			Value = CurrentObject[Attribute.Key];
			
			If Not IsBlankString(CurrentObject[Attribute.Key + CurrentLanguageSuffix]) Then
				CurrentObject[Attribute.Key] = CurrentObject[Attribute.Key + CurrentLanguageSuffix];
			EndIf;
			
			CurrentObject[Attribute.Key + CurrentLanguageSuffix] = Value;
			
		EndDo;
		
		Return;
	EndIf;
	
	Attributes = New Array;
	For each Attribute In CurrentObject.Ref.Metadata().TabularSections.Presentations.Attributes Do
		If StrCompare(Attribute.Name, "LanguageCode") = 0 Then
			Continue;
		EndIf;
		
		Attributes.Add(Attribute.Name);
	EndDo;
	
	Filter = New Structure();
	Filter.Insert("LanguageCode", CurrentLanguage().LanguageCode);
	FoundRows = CurrentObject.Presentations.FindRows(Filter);
	
	If FoundRows.Count() > 0 Then
		Presentation = FoundRows[0];
	Else
		Presentation = CurrentObject.Presentations.Add();
		Presentation.LanguageCode = CurrentLanguage().LanguageCode;
	EndIf;
	
	For each AttributeName In Attributes Do
		Presentation[AttributeName] = CurrentObject[AttributeName];
	EndDo;
	
	Filter.LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
	FoundRows = CurrentObject.Presentations.FindRows(Filter);
	If FoundRows.Count() > 0 Then
		For each AttributeName In Attributes Do
			CurrentObject[AttributeName] = FoundRows[0][AttributeName];
		EndDo;
		CurrentObject.Presentations.Delete(FoundRows[0]);
	EndIf;
	
	CurrentObject.Presentations.GroupBy("LanguageCode", StrConcat(Attributes, ","));
	
EndProcedure

// It is called from the object module to fill in the multilanguage attribute values of the object 
// in the current user language.
//
// Parameters:
//  Object - Arbitrary - a data object.
//
Procedure OnReadPresentationsAtServer(Object) Export
	
	If IsMainLanguage() Then
		Return;
	EndIf;
	
	If MultilanguageStringsInAttributes(Object.Ref.Metadata()) Then
		
		CurrentLanguageSuffix  = "";
		
		If StrCompare(Constants.DefaultLanguage.Get(), CurrentLanguage().LanguageCode) <> 0 Then
			CurrentLanguageSuffix = CurrentLanguageSuffix();
			
		EndIf;
		
		NamesOfAttributesToLocalize = ObjectAttributesToLocalizeDescriptions(Object.Ref.Metadata());
		
		For Each Attribute In NamesOfAttributesToLocalize Do
			
			Value = Object[Attribute.Key];
			Object[Attribute.Key] = Object[Attribute.Key + CurrentLanguageSuffix];
			Object[Attribute.Key + CurrentLanguageSuffix] = Value;
			
			If IsBlankString(Object[Attribute.Key]) Then
				Object[Attribute.Key] = Value;
			EndIf;
			
		EndDo;
		
		Return;
		
	EndIf;
	
	For each Attribute In Object.Metadata().TabularSections.Presentations.Attributes Do
		
		If StrCompare(Attribute.Name, "LanguageCode") = 0 Then
			Continue;
		EndIf;
		
		AttributeName = Attribute.Name;
		
		Filter = New Structure();
		Filter.Insert("LanguageCode", NationalLanguageSupportClientServer.DefaultLanguageCode());
		FoundRows = Object.Presentations.FindRows(Filter);
	
		If FoundRows.Count() > 0 Then
			Presentation = FoundRows[0];
		Else
			Presentation = Object.Presentations.Add();
			Presentation.LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
		EndIf;
		Presentation[AttributeName] = Object[AttributeName];
		
		Filter = New Structure();
		Filter.Insert("LanguageCode", CurrentLanguage().LanguageCode);
		FoundRows = Object.Presentations.FindRows(Filter);
		
		If FoundRows.Count() > 0 AND ValueIsFilled(FoundRows[0][AttributeName]) Then
			Object[AttributeName] = FoundRows[0][AttributeName];
		EndIf;
		
	EndDo;
	
EndProcedure

// It is called from the ProcessGetChoiceData handler to generate a list upon input by string, text 
// auto completion, quick selection, and the GetChoiceData method execution.
// The list contains options in all languages considering the attributes specified in the InputByString property.
//
// Parameters:
//  ChoiceData         - ValueList - data for selection.
//  Parameters            - Structure - contains choice parameters.
//  StandardProcessing - Boolean - a flag indicating whether the standard (system) event processing is executed is passed to this parameter.
//  MetadataObject     - MetadataObject - a metadata object, for which the selection list is being generated.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Val Parameters, StandardProcessing, MetadataObject) Export
	
	If NationalLanguageSupportCached.ConfigurationUsesOnlyOneLanguage(MetadataObject.TabularSections.Find("Presentations") = Undefined)
		Or Not DriveServer.AdditionalLanguagesUsed() Then
		Return;
	EndIf;
	
	If Not Parameters.Property("NativeLanguages") Then
		
		Parameters.Insert("NativeLanguages");
		StandardProcessing = False;
		
		InputByStringFields		= MetadataObject.InputByString;
		Fields					= New Array;
		ParametersFields		= New Array;
		ParametersConditions	= "";
		
		If Parameters.Property("ChoiceFoldersAndItems")
			And MetadataObject.Hierarchical Then
			
			If Parameters.ChoiceFoldersAndItems = FoldersAndItemsUse.Folders Then
				ParametersFields.Add("Table.IsFolder");
			ElsIf Parameters.ChoiceFoldersAndItems = FoldersAndItemsUse.Items Then
				ParametersFields.Add("NOT Table.IsFolder");
			EndIf;
			
		EndIf;
		
		For Each Property In Parameters.Filter Do
			If Common.HasObjectAttribute(Property.Key, MetadataObject)
				Or Common.IsStandardAttribute(MetadataObject.StandardAttributes, Property.Key) Then
				ParametersFields.Add("Table." + Property.Key + " IN  (&" + Property.Key + ")");
			EndIf;
		EndDo;
		
		DescriptionsOfAttributesToLocalize = ObjectAttributesToLocalizeDescriptions(MetadataObject);
		For Each Field In InputByStringFields Do
			If DescriptionsOfAttributesToLocalize.Get(Field.Name) = True Then
				
				Fields.Add("SubString(Table." + Field.Name + ", 1, &SubstringLength) LIKE &SearchString");
				
				If FirstAdditionalLanguageUsed() Then
					Fields.Add("SubString(Table." + Field.Name + "Language1, 1, &SubstringLength) LIKE &SearchString");
				EndIf;
				
				If SecondAdditionalLanguageUsed() Then
					Fields.Add("SubString(Table." + Field.Name + "Language2, 1, &SubstringLength) LIKE &SearchString");
				EndIf;
				
				If ThirdAdditionalLanguageUsed() Then
					Fields.Add("SubString(Table." + Field.Name + "Language3, 1, &SubstringLength) LIKE &SearchString");
				EndIf;
				
				If FourthAdditionalLanguageUsed() Then
					Fields.Add("SubString(Table." + Field.Name + "Language4, 1, &SubstringLength) LIKE &SearchString");
				EndIf;
				
			Else
				Fields.Add("Table." + Field.Name + " LIKE &SearchString");
			EndIf;
		EndDo;
		
		QueryTemplate =
		"SELECT ALLOWED TOP 20
		|	Table.Ref AS Ref
		|FROM
		|	&ObjectName AS Table
		|WHERE
		|	&FilterConditions";
		
		FilterConditions = StrConcat(ParametersFields, " AND ");
		If Not IsBlankString(FilterConditions)
			And Fields.Count() > 0 Then 
			FilterConditions = FilterConditions + " AND (" + StrConcat(Fields, " OR ") + ")";
		Else
			FilterConditions = FilterConditions + StrConcat(Fields, " OR ");
		EndIf;
		
		QueryText = StrReplace(QueryTemplate, "&ObjectName", MetadataObject.FullName());
		QueryText = StrReplace(QueryText, "&FilterConditions", FilterConditions);
		
		LanguageSuffix = NativeLanguagesSupportServer.CurrentLanguageSuffix();
		If DescriptionsOfAttributesToLocalize.Get("Description") <> True
			Or NativeLanguagesSupportServer.IsMainLanguage()
			Or IsBlankString(LanguageSuffix) Then
			
			OrderSectionText = "
			|ORDER BY
			|	Ref.Description";
			
		Else
			
			OrderSectionText = "
			|ORDER BY
			|	CASE
			|		WHEN Ref.Description%1 = """"
			|			THEN Ref.Description
			|		ELSE Ref.Description%1
			|	END";
			OrderSectionText = StringFunctionsClientServer.SubstituteParametersToString(
				OrderSectionText, LanguageSuffix);
			
		EndIf;
		QueryText = QueryText + OrderSectionText;
		
		Query = New Query(QueryText);
		
		Query.SetParameter("SearchString", "%" + Parameters.SearchString +"%");
		Query.SetParameter("SubstringLength", StrLen(Parameters.SearchString));
		
		For Each Property In Parameters.Filter Do
			Query.SetParameter(Property.Key, Property.Value);
		EndDo;
		
		QueryResult = Query.Execute().Select();
		
		ChoiceData = New ValueList;
		While QueryResult.Next() Do
			ChoiceData.Add(QueryResult.Ref, QueryResult.Ref);
		EndDo;
		
		ObjectManager = Common.ObjectManagerByFullName(MetadataObject.FullName());
		StandardList = ObjectManager.GetChoiceData(Parameters);
				
		For Each ValueListItem In StandardList Do
			Value = ?(TypeOf(ValueListItem.Value) = Type("Structure"), ValueListItem.Value.Value, ValueListItem.Value); 
			If ChoiceData.FindByValue(Value) = Undefined Then
				ChoiceData.Add(Value, ValueListItem.Presentation);
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

// Adds a deferred update handler that updates values of multilanguage object attributes.
// Call it if strings filling these attributes were changed in the OnInitialItemsFilling procedures. 
// If the user interactively changed the values ​​of these attributes, these changes will be lost.
// 
//
// Parameters:
//  Version      - String          - see SSLInfobaseUpdate.OnAddUpdateHandlers. 
//  Handlers - ValueTable - see SSLInfobaseUpdate.OnAddUpdateHandlers. 
//
// Returns:
//  ValueTableRow - see SSLInfobaseUpdate.OnAddUpdateHandlers. 
//
// Example:
//	Procedure OnAddUpdateHandlers(Handlers) Export
//		NationalLanguageSupportServer.AddPredefinedItemsPresentationsUpdateHandler("3.1.2.73", Handlers);
//	EndProcedure
//
Function AddPredefinedItemsPresentationsUpdateHandler(Version, Handlers) Export
	
	ObjectsWithPredefinedItems = ObjectsWithPredefinedItemsAsString();
	
	Handler = Handlers.Add();
	Handler.Version = Version;
	Handler.ID = New UUID("d57859ca-1543-4c60-8427-5c2a41832831");
	Handler.Procedure = "NativeLanguagesSupportServer.UpdatePredefinedItemsPresentations";
	Handler.Comment = NStr("ru = 'Обновление наименований предопределенных элементов.
		|До завершения обработки наименования этих элементов в ряде случаев будет отображаться некорректно.'; 
		|en = 'Updates the names of predefined items.
		|While the update is in progress, names of predefined items might be displayed incorrectly.'; 
		|pl = 'Aktualizacje nazw predefiniowanych pozycji.
		|Podczas aktualizacji nazwy predefiniowanych pozycji mogą być wyświetlane niepoprawni.';
		|es_ES = 'Actualiza los nombres de los elementos predefinidos. 
		|Mientras la actualización se está llevando a cabo, es posible que los nombres de los elementos predefinidos se muestren incorrectamente.';
		|es_CO = 'Actualiza los nombres de los elementos predefinidos. 
		|Mientras la actualización se está llevando a cabo, es posible que los nombres de los elementos predefinidos se muestren incorrectamente.';
		|tr = 'Önceden tanımlanmış öğelerin isimlerinin güncellenmesi. 
		| Güncelleme sürerken önceden tanımlanmış öğelerin isimleri yanlış görüntülenebilir.';
		|it = 'Aggiornamento dei nomi degli elementi predefiniti.
		|Fino al completamento dell''elaborazione, in alcuni casi i nomi di questi elementi verranno visualizzati in modo errato.';
		|de = 'Aktualisiert die Namen von vorbestimmten Positionen.
		|Während die Aktualisierung in Bearbeitung ist, können die Namen unkorrekt angezeigt werden.'");
	Handler.ExecutionMode = "Deferred";
	Handler.DeferredProcessingQueue = 2;
	Handler.UpdateDataFillingProcedure = "NativeLanguagesSupportServer.RegisterPredefinedItemsToUpdate";
	Handler.ObjectsToBeRead      = ObjectsWithPredefinedItems;
	Handler.ObjectsToChange    = ObjectsWithPredefinedItems;
	Handler.CheckProcedure    = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ObjectsToLock   = ObjectsWithPredefinedItems;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
		Priority = Handler.ExecutionPriorities.Add();
		Priority.Procedure = "Catalogs.WorldCountries.ProcessDataForMigrationToNewVersion";
		Priority.Order = "Any";
	EndIf;
	
	Return Handler;
	
EndFunction

#EndRegion

#Region Internal

Procedure ChangeListQueryTextForCurrentLanguage(Form,
		ListName = "List",
		ItemName = "",
		MetadataObject = Undefined) Export
	
	LanguageSuffix = CurrentLanguageSuffix();
	
	If IsBlankString(LanguageSuffix) Then
		Return;
	EndIf;
	
	List = Form[ListName];
	
	If IsBlankString(ItemName) Then
		ItemName = ListName;
	EndIf;
	
	ListItem = Form.Items[ItemName];
	QueryText = List.QueryText;
	
	If Not List.CustomQuery
		And Form.Items.Find(ListName) <> Undefined Then
		
		DataSet = ListItem.GetPerformingDataCompositionScheme().DataSets.DynamicListDataSet;
		If TypeOf(DataSet) = Type("DataCompositionSchemaDataSetQuery") Then
			QueryText = DataSet.Query;
		EndIf;
		
	EndIf;	
	
	If IsBlankString(QueryText) Then
		Return;
	EndIf;
	
	AttributesToAdd = New Array;
	
	If MetadataObject = Undefined Then
		MetadataObjectPathPartsSet = StrSplit(Form.FormName, ".");
		MetadataObjectName = MetadataObjectPathPartsSet[0] + "." + MetadataObjectPathPartsSet[1];
		MetadataObject = Metadata.FindByFullName(MetadataObjectName);
	Else
		MetadataObjectName = MetadataObject.FullName(); 	
	EndIf;
	
	AttributesToLocalize = ObjectAttributesToLocalizeForCurrentLanguage(MetadataObject);
	AttributesToAdd = New Array;
	
	SelectionTemplate = "CASE
	|WHEN ISNULL(Substring(%1.%2, 1, 1),"" "") <> "" "" THEN %1.%2
	|ELSE %1.%3
	|END";
	
	QueryModel = New QuerySchema;
	QueryModel.SetQueryText(QueryText);
	
	For Each QueryPackage In QueryModel.QueryBatch Do
		For Each QueryOperator In QueryPackage.Operators Do
			For Each QuerySource In QueryOperator.Sources Do
				If TypeOf(QuerySource.Source) = Type("QuerySchemaTable") Then
					If StrCompare(QuerySource.Source.TableName, MetadataObjectName) = 0 Then
						
						For each AttributeDetails In AttributesToLocalize Do
							
							MainAttributeName = Left(AttributeDetails.Key, StrLen(AttributeDetails.Key) - 9);
							FullName = QuerySource.Source.Alias + "."+ MainAttributeName;
							
							For Index = 0 To QueryOperator.SelectedFields.Count() - 1 Do
								
								FieldToSelect = QueryOperator.SelectedFields.Get(Index);
								Alias = QueryPackage.Columns[Index].Alias + LanguageSuffix;
								Position = StrFind(FieldToSelect, FullName);
								
								If Position = 0 Then
									Continue;
								EndIf;
								
								FieldChoiceText = StringFunctionsClientServer.SubstituteParametersToString(SelectionTemplate,
								QuerySource.Source.Alias, AttributeDetails.Key, MainAttributeName);
								
								If StrCompare(FieldToSelect, FullName) = 0 Then
									
									FieldToSelect = StrReplace(FieldToSelect, FullName, FieldChoiceText);
									
								Else
									
									FieldToSelect = StrReplace(FieldToSelect, FullName + Chars.LF,
										FieldChoiceText + Chars.LF);
									FieldToSelect = StrReplace(FieldToSelect, FullName + " ",
										FieldChoiceText + " " );
									FieldToSelect = StrReplace(FieldToSelect, FullName + ")",
										FieldChoiceText + ")" );
									
								EndIf;
								
								QueryOperator.SelectedFields.Set(Index, New QuerySchemaExpression(FieldToSelect));
							EndDo;
							
						EndDo;
						
					EndIf;
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	ListProperties = Common.DynamicListPropertiesStructure();
	ListProperties.MainTable = List.MainTable;
	ListProperties.DynamicDataRead = True;
	ListProperties.QueryText = QueryModel.GetQueryText();
	
	Common.SetDynamicListProperties(ListItem, ListProperties);
	
EndProcedure

Function CurrentLanguageSuffix() Export
	
	LanguageCodeForPrinting = SessionParameters.LanguageCodeForOutput;
	
	If ValueIsFilled(LanguageCodeForPrinting) Then
		LanguageCode = LanguageCodeForPrinting;
	Else
		LanguageCode = CurrentLanguage().LanguageCode;
	EndIf;
		
	Return LanguageSuffix(LanguageCode);
	
EndFunction

Function NameOfAttributeToLocalize(AttributeName, LanguageCode) Export
	
	Return AttributeName + "_" + LanguageCode;
	
EndFunction

// Returns metadata by the configuration language code.
//
// Parameters:
//   LanguageCode - String - a language code, for example "en" (as it is set in the LanguageCode property of the MetadataObject metadata: Language).
//
// Returns:
//   MetadataObject: Language - if found by the passed language code. Otherwise, Undefined.
//   
Function LanguageByCode(Val LanguageCode) Export
	For each Language In Metadata.Languages Do
		If Language.LanguageCode = LanguageCode Then
			Return Language;
		EndIf;
	EndDo;
	Return Undefined;
EndFunction	

Procedure RegisterPredefinedItemsToUpdate(Parameters) Export
	StandardSubsystemsServer.RegisterPredefinedItemsToUpdate(Parameters);
EndProcedure

Procedure UpdatePredefinedItemsPresentations(Parameters) Export
	StandardSubsystemsServer.UpdatePredefinedItemsPresentations(Parameters);
EndProcedure

Function FirstAdditionalLanguageUsed() Export
	
	Return Constants.UseAdditionalLanguage1.Get() = True;
	
EndFunction

Function SecondAdditionalLanguageUsed() Export
	
	Return Constants.UseAdditionalLanguage2.Get() = True;
	
EndFunction

Function ThirdAdditionalLanguageUsed() Export
	
	Return Constants.UseAdditionalLanguage3.Get() = True;
	
EndFunction

Function FourthAdditionalLanguageUsed() Export
	
	Return Constants.UseAdditionalLanguage4.Get() = True;
	
EndFunction

#EndRegion

#Region Private

// Code of the main infobase language
// 
// Returns:
//  String - a language code. For example, "ru".
//
Function InfobaseLanguageCode()
	
	If ValueIsFilled(Constants.DefaultLanguage.Get()) Then
		Return Constants.DefaultLanguage.Get();
	EndIf;
	
	Return Metadata.DefaultLanguage.LanguageCode;
	
EndFunction

Function DefineFormType(FormName) Export
	
	Result = "";
	
	FormNameParts = StrSplit(Upper(FormName), ".");
	MainListForm = MainListForm(FormNameParts);
	MainChoiceForm = MainFormForChoice(FormNameParts);
	
	FoundForm = Metadata.FindByFullName(FormName);
	
	If MainListForm = FoundForm  Then
		Result =  "DefaultListForm";
	ElsIf MainChoiceForm  = FoundForm Then
		Result = "DefaultChoiceForm";
	EndIf;
	
	Return Result;
	
EndFunction

// See CommonOverridable.OnAddSessionParametersSettingHandlers. 
Procedure SessionParametersSetting(Val SessionParametersNames, SpecifiedParameters) Export
	
	If SessionParametersNames = Undefined
	 Or SessionParametersNames.Find("DefaultLanguage") <> Undefined Then
		
		SessionParameters.DefaultLanguage = InfobaseLanguageCode();
		SpecifiedParameters.Add("DefaultLanguage");
	EndIf;
	
EndProcedure

Function MultilanguageStringsInAttributes(MetadataObject) Export
	Return MetadataObject.TabularSections.Find("Presentations") = Undefined;
EndFunction

Function FirstAdditionalInfobaseLanguageCode() Export
	
	If Not FirstAdditionalLanguageUsed() Then
		Return "";
	EndIf;
	
	Return Constants.AdditionalLanguage1.Get();
	
EndFunction

Function SecondAdditionalInfobaseLanguageCode() Export
	
	If Not SecondAdditionalLanguageUsed() Then
		Return "";
	EndIf;
	
	Return Constants.AdditionalLanguage2.Get();
	
EndFunction

Function ThirdAdditionalInfobaseLanguageCode() Export
	
	If Not ThirdAdditionalLanguageUsed() Then
		Return "";
	EndIf;
	
	Return Constants.AdditionalLanguage3.Get();
	
EndFunction

Function FourthAdditionalInfobaseLanguageCode() Export
	
	If Not FourthAdditionalLanguageUsed() Then
		Return "";
	EndIf;
	
	Return Constants.AdditionalLanguage4.Get();
	
EndFunction

Function ObjectAttributesToLocalizeForCurrentLanguage(MetadataObject, Language = Undefined)
	
	AttributesList = New Map;
	
	LanguagePrefix = CurrentLanguageSuffix();
	
	ObjectAttributesList = New Map;
	
	For Each Attribute In MetadataObject.Attributes Do
		ObjectAttributesList.Insert(Attribute.Name, Attribute);
	EndDo;
	
	For Each Attribute In MetadataObject.StandardAttributes Do
		ObjectAttributesList.Insert(Attribute.Name, Attribute);
	EndDo;
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 0
	|	*
	|FROM
	|	" + MetadataObject.FullName() + " AS Table";
	
	QueryResult = Query.Execute();
	
	AttributesList = New Map;
	For each Column In QueryResult.Columns Do
		If StrEndsWith(Column.Name, LanguagePrefix) Then
			Attribute = ObjectAttributesList.Get(Column.Name);
			If Attribute = Undefined Then
				Attribute = Metadata.CommonAttributes.Find(Column.Name);
			EndIf;
			AttributesList.Insert(Column.Name, Attribute);
			
		EndIf;
	EndDo;
	
	Return AttributesList;
	
EndFunction

Function ObjectAttributesToLocalizeDescriptions(MetadataObject, Prefix = "") Export
	
	ObjectAttributesList = New Map;
	If MultilanguageStringsInAttributes(MetadataObject) Then
	
		LanguageSuffixLength = StrLen("Language1");
		
		Query = New Query;
		Query.Text = 
			"SELECT ALLOWED TOP 0
			|	*
			|FROM
			|	" + MetadataObject.FullName() + " AS Table";
		
		QueryResult = Query.Execute();
		
		AttributesList = New Map;
		For each Column In QueryResult.Columns Do
			If StrEndsWith(Column.Name, "Language1")
				Or StrEndsWith(Column.Name, "Language2")
				Or StrEndsWith(Column.Name, "Language3")
				Or StrEndsWith(Column.Name, "Language4") Then
				ObjectAttributesList.Insert(Prefix + Left(Column.Name, StrLen(Column.Name) - LanguageSuffixLength), True);
			EndIf;
		EndDo;
	Else
		
		For each Attribute In MetadataObject.TabularSections.Presentations.Attributes Do
			If StrCompare(Attribute.Name, "LanguageCode") = 0 Then
				Continue;
			EndIf;
			ObjectAttributesList.Insert(Prefix + Attribute.Name, True);
		EndDo;
		
	EndIf;
	
	Return ObjectAttributesList;
	
EndFunction

Function MainListForm(FormNameParts)
	
	If FormNameParts[0]= "CATALOG"
		Or FormNameParts[0] = "DOCUMENT"
		Or FormNameParts[0] = "ENUM"
		Or FormNameParts[0] = "CHARTOFCHARACTERISTICTYPES"
		Or FormNameParts[0] = "CHARTOFACCOUNTS"
		Or FormNameParts[0] = "CHARTOFCALCULATIONTYPES"
		Or FormNameParts[0] = "BUSINESSPROCESS"
		Or FormNameParts[0] = "TASK"
		Or FormNameParts[0] = "TASK"
		Or FormNameParts[0] = "ACCOUNTINGREGISTERS"
		Or FormNameParts[0] = "ACCUMULATIONREGISTERS"
		Or FormNameParts[0] = "CALCULATIONREGISTERS"
		Or FormNameParts[0] = "INFORMATIONREGISTERS"
		Or FormNameParts[0] = "EXCHANGEPLAN" Then
			Return Metadata.FindByFullName(FormNameParts[0] + "." + FormNameParts[1]).DefaultListForm;
	EndIf;
	
	Return Undefined;
	
EndFunction

Function MainFormForChoice(FormNameParts)
	
	If FormNameParts[0]= "CATALOG"
		Or FormNameParts[0] = "DOCUMENT"
		Or FormNameParts[0] = "ENUM"
		Or FormNameParts[0] = "CHARTOFCHARACTERISTICTYPES"
		Or FormNameParts[0] = "CHARTOFACCOUNTS"
		Or FormNameParts[0] = "BUSINESSPROCESS"
		Or FormNameParts[0] = "TASK"
		Or FormNameParts[0] = "TASK"
		Or FormNameParts[0] = "EXCHANGEPLAN" Then
			Return Metadata.FindByFullName(FormNameParts[0] + "." + FormNameParts[1]).DefaultChoiceForm;
	EndIf;
	
	Return Undefined;
	
EndFunction

Procedure RefillMultilanguageStringsInObjects(Parameters, Address) Export
	StandardSubsystemsServer.FillItemsWithInitialData(True);
EndProcedure

Function IsMainLanguage() Export
	
	Return StrCompare(NationalLanguageSupportClientServer.DefaultLanguageCode(), CurrentLanguage().LanguageCode) = 0;
	
EndFunction

// It returns suffix Language1 or Language2 by the language code.
//
Function LanguageSuffix(Language)
	
	If Language = Constants.AdditionalLanguage1.Get() Then
		Return "Language1";
	EndIf;
	
	If Language = Constants.AdditionalLanguage2.Get() Then
		Return "Language2";
	EndIf;
	
	If Language = Constants.AdditionalLanguage3.Get() Then
		Return "Language3";
	EndIf;
	
	If Language = Constants.AdditionalLanguage4.Get() Then
		Return "Language4";
	EndIf;
	
	Return "";
	
EndFunction

Function ObjectsWithPredefinedItemsAsString()
	
	SubsystemSettings = InfobaseUpdateInternal.SubsystemSettings();
	ObjectsWithInitialFilling = SubsystemSettings.ObjectsWithInitialFilling;
	List = New Array;
	For each ObjectWithPredefinedItems In ObjectsWithInitialFilling Do
		List.Add(ObjectWithPredefinedItems.FullName());
	EndDo;
	
	Return StrConcat(List, ",");
	
EndFunction

#EndRegion