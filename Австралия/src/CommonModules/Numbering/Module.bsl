#Region Public

Procedure NumberUniquenessCheckBeforeWrite(Source, Cancel, WriteMode, PostingMode) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	DocMetadata = Source.Metadata();
	If DocMetadata.Numerator = Metadata.DocumentNumerators.CustomizableNumbering
		And Not (Common.HasObjectAttribute("ForOpeningBalancesOnly", DocMetadata)
				And Source.ForOpeningBalancesOnly) Then
		
		CustomizableNumbering = New Structure;
		
		IsNew = Source.IsNew();
		CustomizableNumbering.Insert("IsNew", IsNew);
		If Not IsNew Then
			CustomizableNumbering.Insert("OldNumber", Common.ObjectAttributeValue(Source.Ref, "Number"));
			CustomizableNumbering.Insert("OldDate", Common.ObjectAttributeValue(Source.Ref, "Date"));
		EndIf;
		CustomizableNumbering.Insert("NumberIsBlank", IsBlankString(Source.Number));
		
		Source.AdditionalProperties.Insert("CustomizableNumbering", CustomizableNumbering);
		
	EndIf;
	
EndProcedure

Procedure NumberUniquenessCheckOnWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.AdditionalProperties.Property("CustomizableNumbering") Then
		
		CustomizableNumbering = Source.AdditionalProperties.CustomizableNumbering;
		
		If CustomizableNumbering.IsNew 
			Or CustomizableNumbering.OldNumber <> Source.Number 
			Or CustomizableNumbering.OldDate <> Source.Date Then
			
			ParametersStructure = GetNumberingParameters(Source);
			If Not NumberIsUnique(ParametersStructure) Then
				
				If CustomizableNumbering.NumberIsBlank Then
					MessageText = NStr("en = 'Automatically generated number %1 is not unique.
									|Contact your administrator to fix the automatic numbering
									|or edit number manually.'; 
									|ru = 'Автоматически сгенерированный номер %1 не является уникальным.
									|Обратитесь к администратору для устранения ошибки автоматической нумерации
									|или внесите изменения вручную.';
									|pl = 'Automatycznie wygenerowany numer %1 nie jest unikalny.
									|Skontaktuj się z twoim administratorem w celu naprawienia numeracji automatycznej
									|lub edytuj numer ręcznie.';
									|es_ES = 'El número generado automáticamente %1 no es único.
									|Póngase en contacto con el administrador para corregir la numeración automática
									|o corrija el número manualmente.';
									|es_CO = 'El número generado automáticamente %1 no es único.
									|Póngase en contacto con el administrador para corregir la numeración automática
									|o corrija el número manualmente.';
									|tr = 'Otomatik olarak oluşturulan numara %1 benzersiz değil. 
									|Otomatik numaralandırmayı düzeltmek 
									|veya numarayı el ile düzeltmek için yöneticinize başvurun.';
									|it = 'Il numero generato automaticamente %1 non è unico. 
									|Contattare il proprio amministratore per correggere la numerazione automatica
									|o modificare il numero manualmente.';
									|de = 'Die automatisch generierte Nummer %1 ist nicht eindeutig.
									|Wenden Sie sich an Ihren Administrator, um die automatische Nummerierung zu korrigieren
									|oder die Nummer manuell zu bearbeiten.'");
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						MessageText, Source.Number);
				Else
					MessageText = NStr("en = 'Number is not unique.'; ru = 'Номер не уникален.';pl = 'Numer nie jest unikalny.';es_ES = 'El número no es único.';es_CO = 'El número no es único.';tr = 'Sayı benzersiz değil.';it = 'Il numero non è unico:';de = 'Die Nummer ist nicht eindeutig.'");
				EndIf;
				
				CommonClientServer.MessageToUser(
					MessageText,
					Source,
					"Number",, 
					Cancel);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure OnSetNewNumber(Source, StandardProcessing, Prefix) Export
	
	DocMetadata = Source.Metadata();
	
	If DocMetadata.Numerator = Metadata.DocumentNumerators.CustomizableNumbering Then
		
		StandardProcessing = False;
		SetNewNumber(Source);
		
	ElsIf DocMetadata.NumberType = Metadata.ObjectProperties.DocumentNumberType.String
		And StandardProcessing Then
		
		ObjectsPrefixesEvents.SetInfobaseAndCompanyPrefix(Source, StandardProcessing, Prefix);
		
	EndIf;
	
EndProcedure

Procedure ReleaseDocumentNumberBeforeDelete(Source, Cancel) Export
	
	DocMetadata = Source.Metadata();
	If DocMetadata.Numerator = Metadata.DocumentNumerators.CustomizableNumbering Then
		ReleaseNumber(Source);
	EndIf;
	
EndProcedure

// Generates the Presentation field for the Numbering settings register
Function GeneratePresentationField(Numerator) Export
	
	Presentation = "";
	
	If ValueIsFilled(Numerator) Then 
		
		NumberExample = "";
		ErrorDescription = "";
		
		NumeratorAttributes = GetNumeratorAttributes(Numerator); 
		ExampleGenerated = GenerateNumberExample(
			NumeratorAttributes.NumberFormat,
			NumeratorAttributes.NumericNumberPartLength,
			NumberExample,
			ErrorDescription);
		If Not ExampleGenerated Then 
			Raise ErrorDescription;
		EndIf;
		
		If IsBlankString(NumberExample) Then
			Presentation = String(Numerator);
		Else
			Presentation = String(Numerator) + ", " + NumberExample;
		EndIf;
		
	EndIf;
	
	Return Presentation;
	
EndFunction

// Shows or hides Numbering index based on its use in numerators.
//
// Parameters:
//   Form - a managed form of the object the numbering index is used in.
//
Procedure ShowNumberingIndex(Form, ObjectRef = Undefined) Export
	
	If Not ValueIsFilled(ObjectRef) Then 
		ObjectRef = Form.Object.Ref;
	EndIf;
	
	ObjectType = TypeOf(ObjectRef);
	
	If ObjectType = Type("CatalogRef.Companies") Then 
		FieldPresentation = "CompanyPrefix";
	ElsIf ObjectType = Type("CatalogRef.BusinessUnits") Then 
		FieldPresentation = "BusinessUnitPrefix";
	ElsIf ObjectType = Type("CatalogRef.Counterparties") Then 
		FieldPresentation = "CounterpartyPrefix";
	Else 
		Return;
	EndIf;
	
	NumberingFieldUsed = NumberingFieldUsed(FieldPresentation);
	Form.Items.NumberingIndex.Visible = NumberingFieldUsed;
	
	If NumberingFieldUsed Then 
		Form.NumberingIndex = InformationRegisters.NumberingIndexes.GetNumberingIndex(ObjectRef);
		Form.NumberingIndexOnOpen = Form.NumberingIndex;
		MetadataType = Metadata.FindByType(ObjectType);
		If Not AccessRight("Update", MetadataType) Then
			Form.Items.NumberingIndex.ReadOnly = True;
		EndIf;
		Form.Items.NumberingIndex.ToolTip = NStr("en = 'This prefix can be used on documents numbering as a prefix or suffix'; ru = 'Этот префикс можно использовать при нумерации документов в качестве префикса или суффикса';pl = 'Ten prefiks może być używany w numeracji dokumentów jako prefiks lub sufiks';es_ES = 'Este prefijo se puede utilizar en la numeración de documentos como prefijo o sufijo.';es_CO = 'Este prefijo se puede utilizar en la numeración de documentos como prefijo o sufijo.';tr = 'Bu önek, numaralanan belgelerde önek veya sonek olarak kullanılabilir';it = 'Questo prefisso può essere usato sulla documentazione documenti come un prefisso o suffisso';de = 'Dieses Präfix kann bei der Belegnummerierung als Präfix oder Suffix verwendet werden.'");
	EndIf;
	
EndProcedure

Procedure WriteNumberingIndex(Form, AttributeName = "Object") Export
	
	SetPrivilegedMode(True);
	
	Object = Form[AttributeName];
	Ref = Object.Ref;
	
	If GetFunctionalOption("UseCustomizableNumbering") Then
		Form.NumberingIndex = TrimAll(Form.NumberingIndex);
		If Form.NumberingIndex <> Form.NumberingIndexOnOpen Then 
			If ValueIsFilled(Form.NumberingIndex) Then 
				InformationRegisters.NumberingIndexes.WriteNumberingIndex(Ref, Form.NumberingIndex);
			Else
				InformationRegisters.NumberingIndexes.DeleteNumberingIndex(Ref);
			EndIf;
			Form.NumberingIndexOnOpen = Form.NumberingIndex;
		EndIf;
	ElsIf Object.Property("Prefix") Then
		If Object.Prefix <> Form.PrefixOnOpen Then 
			If ValueIsFilled(Object.Prefix) Then 
				InformationRegisters.NumberingIndexes.WriteNumberingIndex(Ref, Object.Prefix);
			Else
				InformationRegisters.NumberingIndexes.DeleteNumberingIndex(Ref);
			EndIf;
			Form.PrefixOnOpen = Object.Prefix;
		EndIf;
	EndIf;
	
EndProcedure

Procedure FillDocumentsTypesList(List) Export
	
	DocsFullNames = New Array;
	
	For Each MetaDoc In Metadata.Documents Do
		DocsFullNames.Add(MetaDoc.FullName());
	EndDo;
	
	DocIDs = Common.MetadataObjectIDs(DocsFullNames);
	
	For Each MetaDoc In Metadata.Documents Do
		List.Add(DocIDs[MetaDoc.FullName()], MetaDoc.Presentation());
	EndDo;
	
	List.SortByPresentation();
	
EndProcedure

Function GetOperationTypeTypeDescription(DocumentID) Export
	
	If Not ValueIsFilled(DocumentID) Then
		
		Return Undefined;
		
	EndIf;
	
	MetaDoc = Common.MetadataObjectByID(DocumentID);
	
	OperationTypeAttribute = MetaDoc.Attributes.Find("OperationKind");
	
	If OperationTypeAttribute = Undefined Then
		OperationTypeAttribute = MetaDoc.Attributes.Find("OperationType");
	EndIf;
	
	If OperationTypeAttribute = Undefined Then
		
		Return Undefined;
		
	Else
		
		Return OperationTypeAttribute.Type;
		
	EndIf;
	
EndFunction

// Generates a number example
Function GenerateNumberExample(NumberFormat, NumericNumberPartLength, Example, ErrorDescription) Export
	
	CurrentDate = CurrentSessionDate();
	
	Day   = Day(CurrentDate);
	Month = Month(CurrentDate);
	Year4 = Year(CurrentDate);
	Year2 = Right(String(Year4), 2);
	
	If Month <= 3 Then
		Quarter = 1;
	ElsIf Month <= 6 Then
		Quarter = 2;
	ElsIf Month <= 9 Then
		Quarter = 3;
	Else
		Quarter = 4;
	EndIf;
	
	NumberParametersValues = New Structure;
	SupplementedNumber = StringFunctionsClientServer.SupplementString("12345", NumericNumberPartLength, "0", "Left");
	NumberParametersValues.Insert("Number",	 SupplementedNumber);
	NumberParametersValues.Insert("Day",	 Format(Day, "ND=2; NLZ="));
	NumberParametersValues.Insert("Month",	 Format(Month, "ND=2; NLZ="));
	NumberParametersValues.Insert("Year4",	 Year4);
	NumberParametersValues.Insert("Year2",	 Year2);
	NumberParametersValues.Insert("Quarter", Quarter);
	
	DefLangCode = CommonClientServer.DefaultLanguageCode();
	
	NumberParametersValues.Insert("InfobasePrefix",		 NStr("en = '00'; ru = '00';pl = '00';es_ES = '00';es_CO = '00';tr = '00';it = '00';de = '00'",	DefLangCode)); 
	NumberParametersValues.Insert("CompanyPrefix",		 NStr("en = 'COM'; ru = 'COM';pl = 'COM';es_ES = 'COM';es_CO = 'COM';tr = 'SOM';it = 'COM';de = 'Som'",	DefLangCode)); 
	NumberParametersValues.Insert("OperationTypePrefix", NStr("en = 'ACT'; ru = 'АКТ';pl = 'Akt/Protokół';es_ES = 'ACT';es_CO = 'ACT';tr = 'TUTANAK';it = 'ACT';de = 'ACT'",	DefLangCode)); 
	NumberParametersValues.Insert("BusinessUnitPrefix",	 NStr("en = 'CW'; ru = 'CW';pl = 'CW';es_ES = 'CW';es_CO = 'CW';tr = 'CW';it = 'CW';de = 'CW'",	DefLangCode)); 
	NumberParametersValues.Insert("CounterpartyPrefix",	 NStr("en = 'AMD'; ru = 'AMD';pl = 'AMD';es_ES = 'AMD';es_CO = 'AMD';tr = 'AMD';it = 'AMD';de = 'AMD'",	DefLangCode)); 
	
	ErrorDescription = "";
	NumberFormatStructure = ""; 
	
	If Not ParseNumberFormat(NumberFormat, ErrorDescription, NumberFormatStructure) Then
		Example = "";
		Return False;
	EndIf;
	
	Example = GenerateDocumentNumberByFormat(NumberFormatStructure, NumberParametersValues);
	Return True;
	
EndFunction

// Parses a number text format into structure
Function ParseNumberFormat(NumberFormat, ErrorDescription, NumberFormatStructure) Export
	
	NumberFormatStructure = New ValueTable;
	NumberFormatStructure.Columns.Add("Key", New TypeDescription("String")); // separator or Service field
	NumberFormatStructure.Columns.Add("Value", New TypeDescription("String")); // value of a separator or an Service field
	NumberFormatStructure.Columns.Add("IncludedInServiceField", New TypeDescription("Number")); // separator is within the Service field
	
	ErrorDescription = "";
	FieldsList = GetServiceFieldsList();
	
	// checking parenthesis match
	ParenthesisPosition = 0;
	ParenthesisIndicator = 0;
	
	CharacterIsMissingMessage = NStr("en = '""%1"" character is missing'; ru = 'Отсутствует символ ""%1""';pl = '""%1"" znak jest przepuszczony';es_ES = '""%1"" falta el carácter';es_CO = '""%1"" falta el carácter';tr = '""%1"" karakteri eksik';it = 'il carattere ""%1"" è assente';de = '""%1"" Zeichen fehlt'");
	CharacterIsMissingInFragmentMessage = NStr("en = '""%1"" character is missing in the ""%2"" fragment'; ru = 'Во фрагменте ""%2"" отсутствует символ ""%1""';pl = '""%1"" znak jest przepuszczony we fragmencie ""%2""';es_ES = '""%1"" falta el carácter en el ""%2"" fragmento';es_CO = '""%1"" falta el carácter en el ""%2"" fragmento';tr = '""%2"" parçasında ""%1"" karakteri eksik';it = 'il carattere ""%1"" è assente nel frammento ""%2""';de = '""%1"" Zeichen fehlt im Fragment ""%2""'");
	
	vrNumberFormat = TrimAll(NumberFormat);
	For Ind = 1 To StrLen(vrNumberFormat) Do
		
		CurChar = Mid(vrNumberFormat, Ind, 1);
		If (CurChar <> "[") And (CurChar <> "]") Then
			Continue;
		EndIf;
		
		If (CurChar = "[") Then
			ParenthesisIndicator = ParenthesisIndicator + 1;
			If ParenthesisIndicator > 1 Then 
				ErrorFragment = Mid(vrNumberFormat, ParenthesisPosition + 1, Ind - ParenthesisPosition);
				
				If ErrorFragment = "" Then 
					ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
						CharacterIsMissingMessage, "]");
				Else
					ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
						CharacterIsMissingInFragmentMessage, "]", ErrorFragment);
				EndIf;
				
				Return False;
			EndIf;
		EndIf;
		
		If (CurChar = "]") Then
			ParenthesisIndicator = ParenthesisIndicator - 1;
			If ParenthesisIndicator < 0 Then 
				ErrorFragment = Mid(vrNumberFormat, ParenthesisPosition + 1, Ind - ParenthesisPosition);
				
				If ErrorFragment = "" Then 
					ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
						CharacterIsMissingMessage, "[");
				Else
					ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
						CharacterIsMissingInFragmentMessage, "[", ErrorFragment);
				EndIf;
				
				Return False;
			EndIf;
		EndIf;
		
		ParenthesisPosition = Ind;
		
	EndDo;
	
	If ParenthesisIndicator > 0 Then 
		ErrorFragment = Mid(vrNumberFormat, ParenthesisPosition + 1);
		
		If ErrorFragment = "" Then 
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				CharacterIsMissingMessage, "]");
		Else
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				CharacterIsMissingInFragmentMessage, "]", ErrorFragment);
		EndIf;
		
		Return False;
	EndIf;
	
	
	vrNumberFormat = TrimAll(NumberFormat);
	While vrNumberFormat <> "" Do
		
		Pos1 = Find(vrNumberFormat, "["); // Service field beginning
		If Pos1 > 0 Then
			
			Separator = Left(vrNumberFormat, Pos1-1);
			If Separator <> "" Then
				NewRow = NumberFormatStructure.Add();
				NewRow.Key = "Separator";
				NewRow.Value = Separator;
			EndIf;
			
			vrNumberFormat = Mid(vrNumberFormat, Pos1+1);
			Pos2 = Find(vrNumberFormat, "]"); // Service field end
			
			If Pos2 > 0 Then
				ServiceFieldCode = Left(vrNumberFormat, Pos2-1);
				
				ServiceFieldFound = False;
				For Each ServiceField In FieldsList Do
					
					Pos3 = Find(ServiceFieldCode, ServiceField.Presentation);
					If Pos3 = 0 Then 
						Continue;
					EndIf;
					
					If Pos3 > 1 Then 
						Separator = Left(ServiceFieldCode, Pos3 - 1);
						
						NewRow = NumberFormatStructure.Add();
						NewRow.Key = "Separator";
						NewRow.Value = Separator;
						NewRow.IncludedInServiceField = NumberFormatStructure.IndexOf(NewRow) + 2;
					EndIf;
					
					NewRow = NumberFormatStructure.Add();
					NewRow.Key = "ServiceField";
					NewRow.Value = ServiceField.Presentation;
					
					If Pos3 + StrLen(ServiceField.Value) - 1 < StrLen(ServiceFieldCode) Then 
						Separator = Mid(ServiceFieldCode, Pos3 + StrLen(ServiceField.Presentation));
						
						NewRow = NumberFormatStructure.Add();
						NewRow.Key = "Separator";
						NewRow.Value = Separator;
						NewRow.IncludedInServiceField = NumberFormatStructure.IndexOf(NewRow);
					EndIf;
					
					ServiceFieldFound = True;
					Break;
				EndDo;
				
				If Not ServiceFieldFound Then 
					ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Invalid Service ""%1"" field'; ru = 'Недопустимое значение служебного поля ""%1""';pl = 'Nieważne pole usługi ""%1""';es_ES = 'Servicio no válido ""%1"" campo';es_CO = 'Servicio no válido ""%1"" campo';tr = 'Geçersiz Servis ""%1"" alanı';it = 'Campo di servizio ""%1"" non valido';de = 'Ungültiges Service""%1"" -Feld'"),
						ServiceFieldCode);
					Return False;
				EndIf;
				
				vrNumberFormat = Mid(vrNumberFormat, Pos2+1);
			Else
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Service ""%1"" field end is not found'; ru = 'Служебное поле ""%1"" не найдено';pl = 'Nie znaleziono pola usługi ""%1""';es_ES = 'Servicio ""%1"" no se encuentra el final del campo';es_CO = 'Servicio ""%1"" no se encuentra el final del campo';tr = 'Hizmet ""%1"" alan sonu bulunamadı';it = 'Il campo di servizio ""%1"" non è stato trovato';de = 'Service ""%1"" Feldende wird nicht gefunden'"),
					vrNumberFormat);
				Return False;
			EndIf;
			
		Else
			
			Separator = vrNumberFormat;
			If Separator <> "" Then
				NewRow = NumberFormatStructure.Add();
				NewRow.Key = "Separator";
				NewRow.Value = Separator;
			EndIf;
			vrNumberFormat = "";
			
		EndIf;
		
	EndDo;
	
	Return True;
	
EndFunction

Function GetNumeratorAttributes(Numerator) Export
	
	NumeratorAttributes = Common.ObjectAttributesValues(
		Numerator,
		"Periodicity,
		|NumberFormat,
		|NumericNumberPartLength,
		|IndependentNumberingByDocumentTypes,
		|IndependentNumberingByOperationTypes,
		|IndependentNumberingByCompanies,
		|IndependentNumberingByBusinessUnits,
		|IndependentNumberingByCounterparties");
	
	Return NumeratorAttributes;
	
EndFunction

Function GetDateDiff(DocumentRef, NewDocumentDate, InitialDateOfDocument) Export
	
	If Not ValueIsFilled(DocumentRef) Then
		Return 0;
	EndIf;
	
	Numerator = GetDocumentNumerator(DocumentRef.GetObject());
	
	Periodicity = Common.ObjectAttributeValue(Numerator, "Periodicity");
	
	Return NumberingPeriodStart(Periodicity, InitialDateOfDocument) - NumberingPeriodStart(Periodicity, NewDocumentDate);
	
EndFunction

#EndRegion

#Region Private

Procedure ReleaseNumber(Object)
	
	ParametersStructure = GetNumberingParameters(Object);
	
	GeneratedNumber = 0;
	GenerateNumericDocumentNumber(ParametersStructure, GeneratedNumber, 0);
	If GeneratedNumber = 0 Then
		Return;
	EndIf;
	
	ParametersStructure.Insert("NumericNumber", GeneratedNumber);
	
	CurrentNumber = "";
	
	ErrorsDescriptions = New ValueList;
	GenerateDocumentStringNumber(ParametersStructure, CurrentNumber, ErrorsDescriptions);
	
	If ErrorsDescriptions.Count() Then
		Return;
	EndIf;
	
	If Object.Number = CurrentNumber Then
		GenerateNumericDocumentNumber(ParametersStructure, GeneratedNumber, -1);
	EndIf;
	
EndProcedure

Function NumberIsUnique(Object)
	
	SetPrivilegedMode(True);
	
	Numerator = GetDocumentNumerator(Object);
	
	NumeratorAttributes = GetNumeratorAttributes(Numerator);
	
	NumeratorScope = GetNumeratorScope(Numerator,
		NumeratorAttributes.IndependentNumberingByDocumentTypes, Object.DocumentType);
	
	DocumentsMetadata = Catalogs.MetadataObjectIDs.MetadataObjectsByIDs(
		NumeratorScope.UnloadColumn("DocumentType"), True);
	
	Query = New Query;
	QueryText = "";
	
	QueryTextTemplate =
	"SELECT
	|	Doc.Ref AS Ref
	|FROM
	|	&DocTableName AS Doc
	|WHERE
	|	Doc.Number = &Number
	|	AND Doc.Date BETWEEN &NumberingPeriodStart AND &NumberingPeriodEnd
	|	AND Doc.Ref <> &Ref";
	
	UnionTextTemplate = 
	"
	|UNION ALL
	|";
	
	ConditionTextTemplate =
	"
	|	AND Doc.%1 = &%2";
	
	Iterator = 0;
	
	ConditionAttributesMap = New Structure;
	ConditionAttributesMap.Insert("OperationType",	"OperationKind, OperationType");
	ConditionAttributesMap.Insert("Company",		"Company");
	ConditionAttributesMap.Insert("BusinessUnit",	"StructuralUnit, StructuralUnitReserve, Department");
	ConditionAttributesMap.Insert("Counterparty",	"Counterparty");
	
	ConditionNumberingMap = New Map;
	ConditionNumberingMap.Insert("OperationType",	"IndependentNumberingByOperationTypes");
	ConditionNumberingMap.Insert("Company",			"IndependentNumberingByCompanies");
	ConditionNumberingMap.Insert("BusinessUnit",	"IndependentNumberingByBusinessUnits");
	ConditionNumberingMap.Insert("Counterparty",	"IndependentNumberingByCounterparties");
	
	For Each NumeratorScopeItem In NumeratorScope Do
		
		ItemMetadata = DocumentsMetadata[NumeratorScopeItem.DocumentType];
		If ItemMetadata = Null Or ItemMetadata = Undefined Then
			Continue;
		EndIf;
		
		CurrentText = StrReplace(QueryTextTemplate, "&DocTableName", ItemMetadata.FullName());
		
		If Common.HasObjectAttribute("ForOpeningBalancesOnly", ItemMetadata) Then
			CurrentText = CurrentText + "
				|	AND NOT Doc.ForOpeningBalancesOnly";
		EndIf;
		
		Iterator = Iterator + 1;
		
		For Each Condition In ConditionAttributesMap Do
			
			ConditionName = Condition.Key;
			ConditionAttributes = StringFunctionsClientServer.SplitStringIntoSubstringsArray(Condition.Value);
			
			ConditionAttributeName = "";
			For Each ConditionAttribute In ConditionAttributes Do
				If Common.HasObjectAttribute(ConditionAttribute, ItemMetadata) Then
					ConditionAttributeName = ConditionAttribute;
					Break;
				EndIf;
			EndDo;
			
			If Not IsBlankString(ConditionAttributeName) Then
				
				// scope conditions (numbering settings)
				If ValueIsFilled(NumeratorScopeItem[ConditionName]) Then
					ParameterName = StringFunctionsClientServer.SubstituteParametersToString(
						"Settings%1%2",
						ConditionName,
						Iterator);
					CurrentText = CurrentText + StringFunctionsClientServer.SubstituteParametersToString(
						ConditionTextTemplate,
						ConditionAttributeName,
						ParameterName);
					Query.SetParameter(ParameterName, NumeratorScopeItem[ConditionName]);
				EndIf;
				
				// independent numbering conditions
				If NumeratorAttributes[ConditionNumberingMap[ConditionName]] Then
					CurrentText = CurrentText + StringFunctionsClientServer.SubstituteParametersToString(
						ConditionTextTemplate,
						ConditionAttributeName,
						ConditionName);
				EndIf;
				
			EndIf;
			
		EndDo;
		
		If Iterator > 1 Then
			QueryText = QueryText + UnionTextTemplate;
		EndIf;
		
		QueryText = QueryText + CurrentText;
		
	EndDo;
	
	Query.Text = QueryText;
	
	Query.SetParameter("Number", Object.Number);
	Query.SetParameter("NumberingPeriodStart", NumberingPeriodStart(NumeratorAttributes.Periodicity, Object.Date));
	Query.SetParameter("NumberingPeriodEnd", NumberingPeriodEnd(NumeratorAttributes.Periodicity, Object.Date));
	Query.SetParameter("Ref", Object.Ref);
	
	For Each Condition In ConditionAttributesMap Do
		Query.SetParameter(Condition.Key, Object[Condition.Key]);
	EndDo;
	
	Return Query.Execute().IsEmpty();
	
EndFunction

Function GetNumeratorScope(Numerator, IndependentNumberingByDocumentTypes, DocumentType)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	NumberingSettings.DocumentType AS DocumentType,
	|	NumberingSettings.OperationType AS OperationType,
	|	NumberingSettings.Company AS Company,
	|	NumberingSettings.BusinessUnit AS BusinessUnit,
	|	NumberingSettings.Counterparty AS Counterparty
	|FROM
	|	InformationRegister.NumberingSettings AS NumberingSettings
	|WHERE
	|	NumberingSettings.Numerator = &Numerator
	|	AND NumberingSettings.Numerator <> VALUE(Catalog.Numerators.Default)
	|	AND (NOT &IndependentNumberingByDocumentTypes
	|			OR NumberingSettings.DocumentType = &DocumentType)";
	Query.SetParameter("Numerator", Numerator);
	Query.SetParameter("IndependentNumberingByDocumentTypes", IndependentNumberingByDocumentTypes);
	Query.SetParameter("DocumentType", DocumentType);
	
	NumeratorScopeTable = Query.Execute().Unload();
	
	If NumeratorScopeTable.Count() = 0 Then
		NumeratorScopeTable.Add().DocumentType = DocumentType;
	EndIf;
	
	Return NumeratorScopeTable;
	
EndFunction

Procedure SetNewNumber(Object)
	
	ParametersStructure = GetNumberingParameters(Object);
	
	GeneratedNumber = 0;
	GenerateNumericDocumentNumber(ParametersStructure, GeneratedNumber);
	ParametersStructure.Insert("NumericNumber", GeneratedNumber);
	
	ErrorsDescriptions = New ValueList;
	GenerateDocumentStringNumber(ParametersStructure, Object.Number, ErrorsDescriptions);
	
	For Each ErrorDescription In ErrorsDescriptions Do
		CommonClientServer.MessageToUser(
			ErrorDescription.Presentation,
			Object,
			ErrorDescription.Value);
	EndDo;
	
EndProcedure

Function GetNumberingParameters(Object) 
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Date", Object.Date);
	ParametersStructure.Insert("Ref", Object.Ref);
	ParametersStructure.Insert("Number", Object.Number);
	
	ObjectMetadata = Object.Metadata();
	ParametersStructure.Insert("Metadata", ObjectMetadata);
	
	If Common.HasObjectAttribute("Company", ObjectMetadata) Then
		ParametersStructure.Insert("Company", Object.Company);
	Else
		ParametersStructure.Insert("Company", Catalogs.Companies.EmptyRef());
	EndIf;
	
	If Common.HasObjectAttribute("StructuralUnit", ObjectMetadata) Then
		ParametersStructure.Insert("BusinessUnit", Object.StructuralUnit);
	ElsIf Common.HasObjectAttribute("StructuralUnitReserve", ObjectMetadata) Then
		ParametersStructure.Insert("BusinessUnit", Object.StructuralUnitReserve);
	ElsIf Common.HasObjectAttribute("Department", ObjectMetadata) Then
		ParametersStructure.Insert("BusinessUnit", Object.Department);
	Else
		ParametersStructure.Insert("BusinessUnit", Catalogs.BusinessUnits.EmptyRef());
	EndIf;
	
	If Common.HasObjectAttribute("Counterparty", ObjectMetadata) Then
		ParametersStructure.Insert("Counterparty", Object.Counterparty);
	Else
		ParametersStructure.Insert("Counterparty", Catalogs.Counterparties.EmptyRef());
	EndIf;
	
	If Common.HasObjectAttribute("OperationKind", ObjectMetadata) Then
		ParametersStructure.Insert("OperationType", Object.OperationKind);
	ElsIf Common.HasObjectAttribute("OperationType", ObjectMetadata) Then
		ParametersStructure.Insert("OperationType", Object.OperationType);
	Else
		ParametersStructure.Insert("OperationType", Undefined);
	EndIf;
	
	ParametersStructure.Insert("DocumentType", Common.MetadataObjectID(ObjectMetadata));
	
	Return ParametersStructure;
	
EndFunction

// Gets a document numerator
Function GetDocumentNumerator(Object)
	
	SetPrivilegedMode(True);
	
	If TypeOf(Object) = Type("Structure") Then 
		NumberingParameters = Object;
	Else
		NumberingParameters = GetNumberingParameters(Object);
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Settings.Numerator AS Numerator,
	|	CASE
	|		WHEN NOT Settings.OperationType = UNDEFINED
	|				AND Settings.OperationType = &OperationType
	|			THEN 1
	|		ELSE 0
	|	END + CASE
	|		WHEN Settings.Company <> VALUE(Catalog.Companies.EmptyRef)
	|				AND Settings.Company = &Company
	|			THEN 1
	|		ELSE 0
	|	END + CASE
	|		WHEN Settings.BusinessUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|				AND Settings.BusinessUnit = &BusinessUnit
	|			THEN 1
	|		ELSE 0
	|	END + CASE
	|		WHEN Settings.Counterparty <> VALUE(Catalog.Counterparties.EmptyRef)
	|				AND Settings.Counterparty = &Counterparty
	|			THEN 1
	|		ELSE 0
	|	END AS Order
	|FROM
	|	InformationRegister.NumberingSettings AS Settings
	|WHERE
	|	Settings.DocumentType = &DocumentType
	|	AND (Settings.OperationType = UNDEFINED
	|			OR NOT Settings.OperationType = UNDEFINED
	|				AND Settings.OperationType = &OperationType)
	|	AND (Settings.Company = VALUE(Catalog.Companies.EmptyRef)
	|			OR Settings.Company <> VALUE(Catalog.Companies.EmptyRef)
	|				AND Settings.Company = &Company)
	|	AND (Settings.BusinessUnit = VALUE(Catalog.BusinessUnits.EmptyRef)
	|			OR Settings.BusinessUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|				AND Settings.BusinessUnit = &BusinessUnit)
	|	AND (Settings.Counterparty = VALUE(Catalog.Counterparties.EmptyRef)
	|			OR Settings.Counterparty <> VALUE(Catalog.Counterparties.EmptyRef)
	|				AND Settings.Counterparty = &Counterparty)
	|
	|ORDER BY
	|	Order DESC";

	Query.SetParameter("DocumentType",	NumberingParameters.DocumentType);
	Query.SetParameter("OperationType",	NumberingParameters.OperationType);
	Query.SetParameter("Company",		NumberingParameters.Company);
	Query.SetParameter("BusinessUnit",	NumberingParameters.BusinessUnit);
	Query.SetParameter("Counterparty",	NumberingParameters.Counterparty);
	
	Result = Query.Execute().Unload();
	Result.GroupBy("Numerator, Order");
	
	If Result.Count() = 0 Then 
		
		Return Catalogs.Numerators.Default;
		
	ElsIf Result.Count() = 1 Then 
		
		Return Result[0].Numerator;
		
	ElsIf Result[0].Order = Result[1].Order Then 
			
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Ambiguous numbering settings are found for the ""%1"" document. Contact your administrator.'; ru = 'Для документа ""%1"" найдены неоднозначные настройки нумерации. Обратитесь к администратору.';pl = 'Dwuznaczne ustawienia numeracji znaleziono dla dokumentu""%1"". Skontaktuj się z twoim administratorem.';es_ES = 'Las configuraciones de numeración ambigua se encuentran para el documento ""%1"". Póngase en contacto con su administrador.';es_CO = 'Las configuraciones de numeración ambigua se encuentran para el documento ""%1"". Póngase en contacto con su administrador.';tr = 'Belirsiz numaralandırma ayarları ""%1"" belgesi için bulunur. Yöneticinize başvurun.';it = 'Impostazione ambigua della numerazione è stata trovata per il documento ""%1"". Contattate l''amministratore.';de = 'Für das Dokument ""%1"" werden mehrdeutige Nummerierungseinstellungen gefunden. Wenden Sie sich an Ihren Administrator.'"),
			NumberingParameters.Ref);
		
		Raise MessageText;
		
	Else
		
		Return Result[0].Numerator;
		
	EndIf;
	
EndFunction

// Calculates the numbering period beginning
Function NumberingPeriodStart(Periodicity, Date)
	
	If Periodicity = Enums.NumeratorsPeriodicity.Day Then
		NumberingPeriod = BegOfDay(Date);
		
	ElsIf Periodicity = Enums.NumeratorsPeriodicity.Month Then
		NumberingPeriod = BegOfMonth(Date);
		
	ElsIf Periodicity = Enums.NumeratorsPeriodicity.Quarter Then
		NumberingPeriod = BegOfQuarter(Date);
		
	ElsIf Periodicity = Enums.NumeratorsPeriodicity.Year Then
		NumberingPeriod = BegOfYear(Date);
		
	ElsIf Periodicity = Enums.NumeratorsPeriodicity.Nonperiodical Then 
		NumberingPeriod = '00010101';
		
	EndIf;
	
	Return NumberingPeriod;
	
EndFunction

// Calculates the numbering period beginning
Function NumberingPeriodEnd(Periodicity, Date)
	
	If Periodicity = Enums.NumeratorsPeriodicity.Day Then
		NumberingPeriod = EndOfDay(Date);
		
	ElsIf Periodicity = Enums.NumeratorsPeriodicity.Month Then
		NumberingPeriod = EndOfMonth(Date);
		
	ElsIf Periodicity = Enums.NumeratorsPeriodicity.Quarter Then
		NumberingPeriod = EndOfQuarter(Date);
		
	ElsIf Periodicity = Enums.NumeratorsPeriodicity.Year Then
		NumberingPeriod = EndOfYear(Date);
		
	ElsIf Periodicity = Enums.NumeratorsPeriodicity.Nonperiodical Then 
		NumberingPeriod = '39990101';
		
	EndIf;
	
	Return NumberingPeriod;
	
EndFunction

// Returns a generated numeric number
Procedure GenerateNumericDocumentNumber(ParametersStructure, GeneratedNumber, Modifier = 1)
	
	// manual numbering
	Numerator = GetDocumentNumerator(ParametersStructure);
	If Not ValueIsFilled(Numerator) Then
		GeneratedNumber = 0;
		Return;
	EndIf;
	
	NumeratorAttributes = GetNumeratorAttributes(Numerator);
	
	// numbering dimensions
	NumberingPeriod = NumberingPeriodStart(NumeratorAttributes.Periodicity, ParametersStructure.Date);
	
	If NumeratorAttributes.IndependentNumberingByDocumentTypes Then 
		DocumentType = ParametersStructure.DocumentType;
	Else
		DocumentType = Catalogs.MetadataObjectIDs.EmptyRef();
	EndIf;
	
	If NumeratorAttributes.IndependentNumberingByOperationTypes Then 
		OperationType = ParametersStructure.OperationType;
	Else
		OperationType = Undefined;
	EndIf;
	
	If NumeratorAttributes.IndependentNumberingByCompanies Then 
		Company = ParametersStructure.Company;
	Else
		Company = Catalogs.Companies.EmptyRef();
	EndIf;
	
	If NumeratorAttributes.IndependentNumberingByBusinessUnits Then 
		BusinessUnit = ParametersStructure.BusinessUnit;
	Else
		BusinessUnit = Catalogs.BusinessUnits.EmptyRef();
	EndIf;
	
	If NumeratorAttributes.IndependentNumberingByCounterparties Then 
		Counterparty = ParametersStructure.Counterparty;
	Else
		Counterparty = Catalogs.Counterparties.EmptyRef();
	EndIf;
	
	DimensionsStructure = New Structure;
	DimensionsStructure.Insert("Numerator",			Numerator);
	DimensionsStructure.Insert("NumberingPeriod",	NumberingPeriod);
	DimensionsStructure.Insert("DocumentType",		DocumentType);
	DimensionsStructure.Insert("OperationType",		OperationType);
	DimensionsStructure.Insert("Company",			Company);
	DimensionsStructure.Insert("BusinessUnit",		BusinessUnit);
	DimensionsStructure.Insert("Counterparty",		Counterparty);
	
	// auto numbering
	BeginTransaction();
	Try
		Lock = New DataLock;
		LockItem = Lock.Add("InformationRegister.Numbering");
		LockItem.SetValue("Numerator",			Numerator);
		LockItem.SetValue("NumberingPeriod",	NumberingPeriod);
		LockItem.SetValue("DocumentType",		DocumentType);
		LockItem.SetValue("OperationType",		OperationType);
		LockItem.SetValue("Company",			Company);
		LockItem.SetValue("BusinessUnit",		BusinessUnit);
		LockItem.SetValue("Counterparty",		Counterparty);
		LockItem.Mode = DataLockMode.Exclusive;
		Lock.Lock();
		
		CurrentNumber = InformationRegisters.Numbering.Get(DimensionsStructure).CurrentNumber;
		
		If Modifier = 0 Then
			
			GeneratedNumber = CurrentNumber;
			
		Else
			
			GeneratedNumber = CurrentNumber + Modifier;
			
			RecordManager = InformationRegisters.Numbering.CreateRecordManager();
			FillPropertyValues(RecordManager, DimensionsStructure);
			RecordManager.CurrentNumber = GeneratedNumber;
			RecordManager.Write();
			
		EndIf;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Returns a numbering index for the object
Function GetObjectIndex(Object)
	
	Return InformationRegisters.NumberingIndexes.Get(New Structure("Object", Object)).Index;
	
EndFunction

// Calculates values for parameters specified in the number format
Function GetNumberParametersValues(Object, NumberFormatStructure, ErrorsDescriptions)
	
	NumberParameters = New Structure;
	
	For Each FormatItem In NumberFormatStructure Do
		If FormatItem.Key <> "ServiceField" Then
			Continue;
		EndIf;
		
		ServiceField = FormatItem.Value;
		FieldValue = "";
		
		AddDateNotFilledInErrorDescription = False;
		
		If ServiceField = "Number" Then
			FieldValue = StringFunctionsClientServer.SupplementString(
				Format(Object.NumericNumber, "NG="),
				Object.NumericNumberPartLength, "0", "Left");
			
		ElsIf ServiceField = "Day" Then
			If Not ValueIsFilled(Object.Date) Then 
				AddDateNotFilledInErrorDescription = True;
			Else
				FieldValue = Format(Day(Object.Date), "ND=2; NLZ=");
			EndIf;
			
		ElsIf ServiceField = "Month" Then
			If Not ValueIsFilled(Object.Date) Then 
				AddDateNotFilledInErrorDescription = True;
			Else
				FieldValue = Format(Month(Object.Date), "ND=2; NLZ=");
			EndIf;
			
		ElsIf ServiceField = "Quarter" Then
			If Not ValueIsFilled(Object.Date) Then 
				AddDateNotFilledInErrorDescription = True;
			Else
				Month = Month(Object.Date);
				If Month <= 3 Then
					FieldValue = 1;
				ElsIf Month <= 6 Then
					FieldValue = 2;
				ElsIf Month <= 9 Then
					FieldValue = 3;
				Else
					FieldValue = 4;
				EndIf;
			EndIf;
			
		ElsIf ServiceField = "Year4" Then
			If Not ValueIsFilled(Object.Date) Then 
				AddDateNotFilledInErrorDescription = True;
			Else
				FieldValue = Year(Object.Date);
			EndIf;
			
		ElsIf ServiceField = "Year2" Then
			If Not ValueIsFilled(Object.Date) Then 
				AddDateNotFilledInErrorDescription = True;
			Else
				FieldValue = Right(String(Year(Object.Date)), 2);
			EndIf;
			
		ElsIf ServiceField = "InfobasePrefix" Then
			If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
				ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
				FieldValue = ModuleDataExchangeServer.InfobasePrefix();
			Else
				FieldValue = "";
			EndIf;
			FieldValue = StringFunctionsClientServer.SupplementString(FieldValue, 2, "0", "Left");
			
		ElsIf ServiceField = "CompanyPrefix" Then 
			If ValueIsFilled(Object.Company) Then
				FieldValue = GetObjectIndex(Object.Company);
			EndIf;
			FieldValue = StringFunctionsClientServer.SupplementString(FieldValue, 2, "0", "Left");
			
		ElsIf ServiceField = "BusinessUnitPrefix" Then 
			If ValueIsFilled(Object.BusinessUnit) Then
				FieldValue = GetObjectIndex(Object.BusinessUnit);
			EndIf;
			
		ElsIf ServiceField = "CounterpartyPrefix" Then 
			If ValueIsFilled(Object.Counterparty) Then 
				FieldValue = GetObjectIndex(Object.Counterparty);
			EndIf;
			
		ElsIf ServiceField = "OperationTypePrefix" Then 
			If ValueIsFilled(Object.OperationType) Then
				FieldValue = GetObjectIndex(Object.OperationType);
			EndIf;
			
		EndIf;
		
		If AddDateNotFilledInErrorDescription Then
			ErrorsDescriptions.Add("Date", NStr("en = '""Registration date"" field is not filled in'; ru = 'Поле ""Дата регистрации"" не заполнено';pl = 'Pole ""Data rejestracji"" nie jest wypełnione';es_ES = 'El campo ""Fecha de registro"" no está rellenado.';es_CO = 'El campo ""Fecha de registro"" no está rellenado.';tr = '""Kayıt tarihi"" alanı doldurulmadı';it = 'Il campo ""Data di registrazione"" non è compilato';de = 'Das Feld ""Registrierungsdatum"" ist nicht ausgefüllt'"));
		EndIf;
		
		NumberParameters.Insert(ServiceField, FieldValue);
		
	EndDo;
	
	Return NumberParameters;
	
EndFunction

// Returns a generated string number
Procedure GenerateDocumentStringNumber(ParametersStructure, GeneratedNumber, ErrorsDescriptions)
	
	Var NumberFormatStructure, ErrorDescription;
	
	Numerator = GetDocumentNumerator(ParametersStructure); 
	If Not ValueIsFilled(Numerator) Then
		Return;
	EndIf;
	
	NumeratorAttributes = GetNumeratorAttributes(Numerator);
	
	If Not ValueIsFilled(NumeratorAttributes.NumberFormat) Then
		GeneratedNumber = "";
		ErrorsDescriptions.Add("", NStr("en = 'Number format is not specified for the numerator. Contact your administrator.'; ru = 'Для нумератора не указан формат номера. Обратитесь к администратору.';pl = 'Format numeru nie jest określony dla licznika. Skontaktuj się z twoim administratorem.';es_ES = 'El formato del número no se especifica para el numerador. Póngase en contacto con su administrador.';es_CO = 'El formato del número no se especifica para el numerador. Póngase en contacto con su administrador.';tr = 'Sayı biçimi, sayıcı için belirtilmemiş. Yöneticinize başvurun.';it = 'Il formato del numero non è specificato per il numeratore. Contattate il vostro amministratore.';de = 'Für den Zähler wurde kein Zahlenformat eingegeben. Kontaktieren Sie Ihren Administrator.'"));
		Return;
	EndIf;
	
	If Not ParseNumberFormat(NumeratorAttributes.NumberFormat, ErrorDescription, NumberFormatStructure) Then 
		GeneratedNumber = "";
		ErrorsDescriptions.Add("", StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Number format error: %1. Contact your administrator.'; ru = 'Ошибка формата номера: %1. Обратитесь к администратору.';pl = 'Błąd formatu numera: %1. Skontaktuj się z twoim administratorem.';es_ES = 'Error de formato de número: %1. Póngase en contacto con su administrador.';es_CO = 'Error de formato de número: %1. Póngase en contacto con su administrador.';tr = 'Sayı biçimi hatası:%1. Yöneticinize başvurun.';it = 'Errore di formato del numore: %1. Contattate il vostro amministratore.';de = 'Fehler im Nummernformat: %1. Wenden Sie sich an Ihren Administrator.'"), ErrorDescription));
		Return;
	EndIf;
	
	ParametersStructure.Insert("NumericNumberPartLength", NumeratorAttributes.NumericNumberPartLength);
	
	NumberParametersValues = GetNumberParametersValues(ParametersStructure, NumberFormatStructure, ErrorsDescriptions);
	If ErrorsDescriptions.Count() > 0 Then
		GeneratedNumber = "";
		Return;
	EndIf;
	
	GeneratedNumber = GenerateDocumentNumberByFormat(NumberFormatStructure, NumberParametersValues);
	
EndProcedure

Function GetServiceFieldsList()
	
	FieldsList = New ValueList; // value - an Service field in the format string
								// presentation - an Service field presentation
	
	DefLangCode = CommonClientServer.DefaultLanguageCode();
	
	FieldsList.Add(NStr("en = 'Day'; ru = 'День';pl = 'Dzień';es_ES = 'Día';es_CO = 'Día';tr = 'Gün';it = 'Giorno';de = 'Tag'",		DefLangCode), "Day");
	FieldsList.Add(NStr("en = 'Month'; ru = 'Месяц';pl = 'Miesiąc';es_ES = 'Mes';es_CO = 'Mes';tr = 'Ay';it = 'Mese';de = 'Monat'",		DefLangCode), "Month");
	FieldsList.Add(NStr("en = 'Quarter'; ru = 'Квартал';pl = 'Kwartał';es_ES = 'Trimestre';es_CO = 'Trimestre';tr = 'Çeyrek yıl';it = 'Trimestre';de = 'Quartal'",	DefLangCode), "Quarter");
	FieldsList.Add(NStr("en = 'Year4'; ru = 'Year4';pl = 'Year4';es_ES = 'Year4';es_CO = 'Year4';tr = 'Yıl4';it = 'Year4';de = 'Jahr4'",		DefLangCode), "Year4");
	FieldsList.Add(NStr("en = 'Year2'; ru = 'Year2';pl = 'Year2';es_ES = 'Year2';es_CO = 'Year2';tr = 'Yıl2';it = 'Year2';de = 'Jahr2'",		DefLangCode), "Year2");
	
	FieldsList.Add(NStr("en = 'InfobasePrefix'; ru = 'InfobasePrefix';pl = 'InfobasePrefix';es_ES = 'InfobasePrefix';es_CO = 'InfobasePrefix';tr = 'InfobasePrefix';it = 'InfobasePrefix';de = 'InformationsbasisPräfix'",		DefLangCode), "InfobasePrefix");
	FieldsList.Add(NStr("en = 'CompanyPrefix'; ru = 'CompanyPrefix';pl = 'CompanyPrefix';es_ES = 'CompanyPrefix';es_CO = 'CompanyPrefix';tr = 'CompanyPrefix';it = 'CompanyPrefix';de = 'Firmenpräfix'",			DefLangCode), "CompanyPrefix");
	FieldsList.Add(NStr("en = 'BusinessUnitPrefix'; ru = 'BusinessUnitPrefix';pl = 'BusinessUnitPrefix';es_ES = 'BusinessUnitPrefix';es_CO = 'BusinessUnitPrefix';tr = 'BusinessUnitPrefix';it = 'BusinessUnitPrefix';de = 'GeschäftsFeldPräfix'",	DefLangCode), "BusinessUnitPrefix");
	FieldsList.Add(NStr("en = 'CounterpartyPrefix'; ru = 'CounterpartyPrefix';pl = 'CounterpartyPrefix';es_ES = 'CounterpartyPrefix';es_CO = 'CounterpartyPrefix';tr = 'CounterpartyPrefix';it = 'CounterpartyPrefix';de = 'GeschäftspartnerPräfix'",	DefLangCode), "CounterpartyPrefix");
	FieldsList.Add(NStr("en = 'OperationTypePrefix'; ru = 'OperationTypePrefix';pl = 'OperationTypePrefix';es_ES = 'OperationTypePrefix';es_CO = 'OperationTypePrefix';tr = 'OperationTypePrefix';it = 'OperationTypePrefix';de = 'OperationsTypPräfix'",	DefLangCode), "OperationTypePrefix");
	
	FieldsList.Add(NStr("en = 'Number'; ru = 'Номер';pl = 'Numer';es_ES = 'Número';es_CO = 'Número';tr = 'Numara';it = 'Numero';de = 'Nummer'",	DefLangCode), "Number");
	
	Return FieldsList;
	
EndFunction

Function NumberingFieldUsed(ServiceField)
	
	FieldsList = GetServiceFieldsList();
	
	Field = "";
	For Each Row In FieldsList Do
		If Row.Presentation = ServiceField Then 
			Field = Row.Value;
			Break;
		EndIf;
	EndDo;
	
	If Field = "" Then 
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	TRUE
	|FROM
	|	Catalog.Numerators AS Numerators
	|WHERE
	|	Numerators.NumberFormat LIKE &Field";
	
	Query.SetParameter("Field", "%" + Field + "%");
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

// Generates a number from format structure and parameter values
Function GenerateDocumentNumberByFormat(NumberFormatStructure, NumberParametersValues) 
	
	GeneratedNumber = "";
	
	For Each FormatItem In NumberFormatStructure Do
		
		If FormatItem.Key = "Separator" Then
			
			If FormatItem.IncludedInServiceField = 0 Then
				GeneratedNumber = GeneratedNumber + FormatItem.Value;
			Else
				ParameterValue = "";
				ServiceField = NumberFormatStructure.Get(FormatItem.IncludedInServiceField - 1).Value;
				NumberParametersValues.Property(ServiceField, ParameterValue);
				If ValueIsFilled(ParameterValue) Then 
					GeneratedNumber = GeneratedNumber + FormatItem.Value;
				EndIf;
			EndIf;
			
		ElsIf FormatItem.Key = "ServiceField" Then
			
			ParameterValue = "";
			NumberParametersValues.Property(FormatItem.Value, ParameterValue);
			
			If TypeOf(ParameterValue) = Type("Number") Then
				ParameterValue = Format(ParameterValue, "NG=");
			Else
				ParameterValue = String(ParameterValue);
			EndIf;
			
			GeneratedNumber = GeneratedNumber + ParameterValue;
		EndIf;
		
	EndDo;
	
	Return GeneratedNumber;
	
EndFunction

#EndRegion