#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var Registration Export; // Structure that contains registration parameters.
Var ObjectsRegistrationRules Export; // A value table with object registration rules.
Var ErrorFlag Export; // global error flag

Var StringType;
Var BooleanType;
Var NumberType;
Var DateType;

Var BlankDateValue;
Var FilterByExchangePlanPropertiesTreePattern;  // Registration rule value tree template by exchange plan properties.
                                                // 
Var FilterByObjectPropertiesTreePattern;      // Registration rule value tree template by object properties.
Var BooleanPropertyRootGroupValue; // Boolean value for the root property group.
Var ErrorMessages; // Map. Key - an error code, Value - error details.

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Performs a syntactic analysis of the XML file that contains registration rules. Fills collection values with data from the file.
// Prepares read rules for ORR mechanism (rule compilation).
//
// Parameters:
//  FileName         - String - full name of a rule file with rules in the local file system.
//  InfoOnly - Boolean- a flag showing whether the file title and rule information are the only data to be read.
//                              (the default value is False).
//
Procedure ImportRules(Val FileName, InfoOnly = False) Export
	
	ErrorFlag = False;
	
	If IsBlankString(FileName) Then
		ReportProcessingError(4);
		Return;
	EndIf;
	
	// Initializing collections for rules.
	Registration                             = RecordInitialization();
	ObjectsRegistrationRules              = DataProcessors.ObjectsRegistrationRulesImport.ORRTableInitialization();
	FilterByExchangePlanPropertiesTreePattern = DataProcessors.ObjectsRegistrationRulesImport.FilterByExchangePlanPropertiesTableInitialization();
	FilterByObjectPropertiesTreePattern     = DataProcessors.ObjectsRegistrationRulesImport.FilterByObjectPropertiesTableInitialization();
	
	// LOADING REGISTRATION RULES
	Try
		LoadRecordFromFile(FileName, InfoOnly);
	Except
		
		// Reporting about the error
		ReportProcessingError(2, BriefErrorDescription(ErrorInfo()));
		
	EndTry;
	
	// Error reading rules from the file.
	If ErrorFlag Then
		Return;
	EndIf;
	
	If InfoOnly Then
		Return;
	EndIf;
	
	// PREPARING RULES FOR ORR MECHANISM
	
	For Each ORR In ObjectsRegistrationRules Do
		
		PrepareRecordRuleByExchangePlanProperties(ORR);
		
		PrepareRegistrationRuleByObjectProperties(ORR);
		
	EndDo;
	
	ObjectsRegistrationRules.FillValues(Registration.ExchangePlanName, "ExchangePlanName");
	
EndProcedure

// Prepares a row with information about the rules based on the read data from the XML file.
//
// Parameters:
//  No.
// 
// Returns:
//  InfoString - String - a sring with information on rules.
//
Function RulesInformation() Export
	
	// Function return value.
	InfoString = "";
	
	If ErrorFlag Then
		Return InfoString;
	EndIf;
	
	InfoString = NStr("ru = 'Правила регистрации объектов этой информационной базы (%1) от %2'; en = 'Object registration rules in the current infobase (%1) created at %2'; pl = 'Reguły rejestracji obiektu dla tej bazy informacyjnej (%1) z %2';es_ES = 'Reglas del registro de objetos de esta infobase (%1) de %2';es_CO = 'Reglas del registro de objetos de esta infobase (%1) de %2';tr = '%1''dan veritabanın (%2) nesne kayıt kuralları';it = 'Regole di registrazione dell''oggetto nell''infobase attuale (%1) create in %2';de = 'Objekt-Registrierungsregeln dieser Infobase (%1) aus %2'");
	
	Return StringFunctionsClientServer.SubstituteParametersToString(InfoString,
		GetConfigurationPresentationFromRegistrationRules(),
		Format(Registration.CreationDateTime, "DLF = DD"));
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Importing object registration rules (ORR).

Procedure LoadRecordFromFile(FileName, InfoOnly)
	
	// Opening the file for reading
	Try
		Rules = New XMLReader();
		Rules.OpenFile(FileName);
		Rules.Read();
	Except
		Rules = Undefined;
		ReportProcessingError(1, BriefErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	Try
		LoadRecord(Rules, InfoOnly);
	Except
		ReportProcessingError(2, BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	Rules.Close();
	Rules = Undefined;
	
EndProcedure

// Imports registration rules according to the format.
//
// Parameters:
//  
Procedure LoadRecord(Rules, InfoOnly)
	
	If Not ((Rules.LocalName = "RecordRules") 
		AND (Rules.NodeType = XMLNodeType.StartElement)) Then
		
		// Rule format error
		ReportProcessingError(3);
		
		Return;
		
	EndIf;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		// Registration attributes
		If NodeName = "FormatVersion" Then
			
			Registration.FormatVersion = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "ID" Then
			
			Registration.ID = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "Description" Then
			
			Registration.Description = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "CreationDateTime" Then
			
			Registration.CreationDateTime = deElementValue(Rules, DateType);
			
		ElsIf NodeName = "ExchangePlan" Then
			
			// Exchange plan attributes
			Registration.ExchangePlanName = deAttribute(Rules, StringType, "Name");
			
			Registration.ExchangePlan = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "Comment" Then
			
			Registration.Comment = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "Configuration" Then
			
			// Configuration attributes
			Registration.PlatformVersion     = deAttribute(Rules, StringType, "PlatformVersion");
			Registration.ConfigurationVersion  = deAttribute(Rules, StringType, "ConfigurationVersion");
			Registration.ConfigurationSynonym = deAttribute(Rules, StringType, "ConfigurationSynonym");
			
			// Configuration description
			Registration.Configuration = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "ObjectsRegistrationRules" Then
			
			If InfoOnly Then
				
				Break; // Breaking if only registration information is required.
				
			Else
				
				// Checking whether ORR are imported for the required exchange plan.
				CheckExchangePlanExists();
				
				If ErrorFlag Then
					Break; // Rules contain wrong exchange plan.
				EndIf;
				
				ImportRegistrationRules(Rules);
				
			EndIf;
			
		ElsIf (NodeName = "RecordRules") AND (NodeType = XMLNodeType.EndElement) Then
			
			Break; // exit
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports registration rules according to the exchange rule format.
//
// Parameters:
//  Rules - an object of the XMLReader type.
// 
Procedure ImportRegistrationRules(Rules)
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		
		If NodeName = "Rule" Then
			
			LoadRecordRule(Rules);
			
		ElsIf NodeName = "Group" Then
			
			LoadRecordRuleGroup(Rules);
			
		ElsIf (NodeName = "ObjectsRegistrationRules") AND (Rules.NodeType = XMLNodeType.EndElement) Then
			
			Break;
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports the object registration rule.
//
// Parameters:
//  Rules - an object of the XMLReader type.
// 
Procedure LoadRecordRule(Rules)
	
	// Rules with the Disable flag must not be loaded.
	Disable = deAttribute(Rules, BooleanType, "Disable");
	If Disable Then
		deSkip(Rules);
		Return;
	EndIf;
	
	// Rules with errors must not be loaded.
	Valid = deAttribute(Rules, BooleanType, "Valid");
	If Not Valid Then
		deSkip(Rules);
		Return;
	EndIf;
	
	NewRow = ObjectsRegistrationRules.Add();
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		
		If NodeName = "SettingObject" Then
			
			NewRow.SettingObject = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "MetadataObjectName" Then
			
			NewRow.MetadataObjectName = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "ExportModeAttribute" Then
			
			NewRow.FlagAttributeName = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "FilterByExchangePlanProperties" Then
			
			// Initializing property collection for the current ORR.
			NewRow.FilterByExchangePlanProperties = FilterByExchangePlanPropertiesTreePattern.Copy();
			
			LoadFilterByExchangePlanPropertiesTree(Rules, NewRow.FilterByExchangePlanProperties);
			
		ElsIf NodeName = "FilterByObjectProperties" Then
			
			// Initializing property collection for the current ORR.
			NewRow.FilterByObjectProperties = FilterByObjectPropertiesTreePattern.Copy();
			
			LoadFilterByObjectPropertiesTree(Rules, NewRow.FilterByObjectProperties);
			
		ElsIf NodeName = "BeforeProcess" Then
			
			NewRow.BeforeProcess = deElementValue(Rules, StringType);
			
			NewRow.HasBeforeProcessHandler = Not IsBlankString(NewRow.BeforeProcess);
			
		ElsIf NodeName = "OnProcess" Then
			
			NewRow.OnProcess = deElementValue(Rules, StringType);
			
			NewRow.HasOnProcessHandler = Not IsBlankString(NewRow.OnProcess);
			
		ElsIf NodeName = "OnProcessAdditional" Then
			
			NewRow.OnProcessAdditional = deElementValue(Rules, StringType);
			
			NewRow.HasOnProcessHandlerAdditional = Not IsBlankString(NewRow.OnProcessAdditional);
			
		ElsIf NodeName = "AfterProcess" Then
			
			NewRow.AfterProcess = deElementValue(Rules, StringType);
			
			NewRow.HasAfterProcessHandler = Not IsBlankString(NewRow.AfterProcess);
			
		ElsIf (NodeName = "Rule") AND (Rules.NodeType = XMLNodeType.EndElement) Then
			
			Break;
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure LoadFilterByExchangePlanPropertiesTree(Rules, ValuesTree)
	
	VTRows = ValuesTree.Rows;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "FilterItem" Then
			
			LoadExchangePlanFilterItem(Rules, VTRows.Add());
			
		ElsIf NodeName = "Group" Then
			
			LoadExchangePlanFilterItemGroup(Rules, VTRows.Add());
			
		ElsIf (NodeName = "FilterByExchangePlanProperties") AND (NodeType = XMLNodeType.EndElement) Then
			
			Break; // exit
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure LoadFilterByObjectPropertiesTree(Rules, ValuesTree)
	
	VTRows = ValuesTree.Rows;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "FilterItem" Then
			
			LoadObjectFilterItem(Rules, VTRows.Add());
			
		ElsIf NodeName = "Group" Then
			
			LoadObjectFilterItemGroup(Rules, VTRows.Add());
			
		ElsIf (NodeName = "FilterByObjectProperties") AND (NodeType = XMLNodeType.EndElement) Then
			
			Break; // exit
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports the object registration rule by property.
//
// Parameters:
// 
Procedure LoadExchangePlanFilterItem(Rules, NewRow)
	
	NewRow.IsFolder = False;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "ObjectProperty" Then
			
			If NewRow.IsConstantString Then
				
				NewRow.ConstantValue = deElementValue(Rules, Type(NewRow.ObjectPropertyType));
				
			Else
				
				NewRow.ObjectProperty = deElementValue(Rules, StringType);
				
			EndIf;
			
		ElsIf NodeName = "ExchangePlanProperty" Then
			
			// The property can be a header property or tabular section property. If the property is a tabular 
			// section property, the FullPropertyDescription variable contains the tabular section description 
			// and the property description.
			// The tabular section name is written in square brackets.
			// For example "[Companies].Company".
			FullPropertyDescription = deElementValue(Rules, StringType);
			
			ExchangePlanTabularSectionName = "";
			
			FirstBracketPosition = StrFind(FullPropertyDescription, "[");
			
			If FirstBracketPosition <> 0 Then
				
				SecondBracketPosition = StrFind(FullPropertyDescription, "]");
				
				ExchangePlanTabularSectionName = Mid(FullPropertyDescription, FirstBracketPosition + 1, SecondBracketPosition - FirstBracketPosition - 1);
				
				FullPropertyDescription = Mid(FullPropertyDescription, SecondBracketPosition + 2);
				
			EndIf;
			
			NewRow.NodeParameter                = FullPropertyDescription;
			NewRow.NodeParameterTabularSection = ExchangePlanTabularSectionName;
			
		ElsIf NodeName = "ComparisonType" Then
			
			NewRow.ComparisonType = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "IsConstantString" Then
			
			NewRow.IsConstantString = deElementValue(Rules, BooleanType);
			
		ElsIf NodeName = "ObjectPropertyType" Then
			
			NewRow.ObjectPropertyType = deElementValue(Rules, StringType);
			
		ElsIf (NodeName = "FilterItem") AND (NodeType = XMLNodeType.EndElement) Then
			
			Break; // exit
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports the object registration rule by property.
//
// Parameters:
// 
Procedure LoadObjectFilterItem(Rules, NewRow)
	
	NewRow.IsFolder = False;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "ObjectProperty" Then
			
			NewRow.ObjectProperty = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "ConstantValue" Then
			
			If IsBlankString(NewRow.FilterItemKind) Then
				
				NewRow.FilterItemKind = DataExchangeServer.FilterItemPropertyConstantValue();
				
			EndIf;
			
			If NewRow.FilterItemKind = DataExchangeServer.FilterItemPropertyConstantValue() Then
				
				// primitive types only
				NewRow.ConstantValue = deElementValue(Rules, Type(NewRow.ObjectPropertyType));
				
			ElsIf NewRow.FilterItemKind = DataExchangeServer.FilterItemPropertyValueAlgorithm() Then
				
				NewRow.ConstantValue = deElementValue(Rules, StringType); // row
				
			Else
				
				NewRow.ConstantValue = deElementValue(Rules, StringType); // row
				
			EndIf;
			
		ElsIf NodeName = "ComparisonType" Then
			
			NewRow.ComparisonType = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "ObjectPropertyType" Then
			
			NewRow.ObjectPropertyType = deElementValue(Rules, StringType);
			
		ElsIf NodeName = "Kind" Then
			
			NewRow.FilterItemKind = deElementValue(Rules, StringType);
			
		ElsIf (NodeName = "FilterItem") AND (NodeType = XMLNodeType.EndElement) Then
			
			Break; // exit
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports object registration rule groups by property.
//
// Parameters:
//  Rules - an object of the XMLReader type.
// 
Procedure LoadExchangePlanFilterItemGroup(Rules, NewRow)
	
	NewRow.IsFolder = True;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "FilterItem" Then
			
			LoadExchangePlanFilterItem(Rules, NewRow.Rows.Add());
		
		ElsIf (NodeName = "Group") AND (NodeType = XMLNodeType.StartElement) Then
			
			LoadExchangePlanFilterItemGroup(Rules, NewRow.Rows.Add());
			
		ElsIf NodeName = "BooleanGroupValue" Then
			
			NewRow.BooleanGroupValue = deElementValue(Rules, StringType);
			
		ElsIf (NodeName = "Group") AND (NodeType = XMLNodeType.EndElement) Then
			
			Break; // exit
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;

EndProcedure

// Imports object registration rule groups by property.
//
// Parameters:
//  Rules - an object of the XMLReader type.
// 
Procedure LoadObjectFilterItemGroup(Rules, NewRow)
	
	NewRow.IsFolder = True;
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		NodeType = Rules.NodeType;
		
		If NodeName = "FilterItem" Then
			
			LoadObjectFilterItem(Rules, NewRow.Rows.Add());
		
		ElsIf (NodeName = "Group") AND (NodeType = XMLNodeType.StartElement) Then
			
			LoadObjectFilterItemGroup(Rules, NewRow.Rows.Add());
			
		ElsIf NodeName = "BooleanGroupValue" Then
			
			BooleanGroupValue = deElementValue(Rules, StringType);
			
			NewRow.IsAndOperator = (BooleanGroupValue = "AND");
			
		ElsIf (NodeName = "Group") AND (NodeType = XMLNodeType.EndElement) Then
			
			Break; // exit
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;

EndProcedure

Procedure LoadRecordRuleGroup(Rules)
	
	While Rules.Read() Do
		
		NodeName = Rules.LocalName;
		
		If NodeName = "Rule" Then
			
			LoadRecordRule(Rules);
			
		ElsIf NodeName = "Group" AND Rules.NodeType = XMLNodeType.StartElement Then
			
			LoadRecordRuleGroup(Rules);
			
		ElsIf NodeName = "Group" AND Rules.NodeType = XMLNodeType.EndElement Then
		
			Break;
			
		Else
			
			deSkip(Rules);
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Compiling object registration rules (ORR) by exchange plan properties.

Procedure PrepareRecordRuleByExchangePlanProperties(ORR)
	
	EmptyRule = (ORR.FilterByExchangePlanProperties.Rows.Count() = 0);
	
	ObjectProperties = New Structure;
	
	FieldSelectionText = "SELECT DISTINCT ExchangePlanMainTable.Ref AS Ref";
	
	// Table with data source (exchange plan tabular sections) names.
	DataTable = ORRData(ORR.FilterByExchangePlanProperties.Rows);
	
	TableDataText = GetDataTablesTextForORR(DataTable);
	
	If EmptyRule Then
		
		ConditionText = "True";
		
	Else
		
		ConditionText = GetPropertyGroupConditionText(ORR.FilterByExchangePlanProperties.Rows, BooleanPropertyRootGroupValue, 0, ObjectProperties);
		
	EndIf;
	
	QueryText = FieldSelectionText + Chars.LF 
	             + "FROM"  + Chars.LF + TableDataText + Chars.LF
	             + "WHERE" + Chars.LF + ConditionText
	             + Chars.LF + "[MandatoryConditions]";
	//
	
	// Setting variable values.
	ORR.QueryText    = QueryText;
	ORR.ObjectProperties = ObjectProperties;
	ORR.ObjectPropertiesString = GetObjectPropertyAsString(ObjectProperties);
	
EndProcedure

Function GetPropertyGroupConditionText(GroupProperties, BooleanGroupValue, Val Offset, ObjectProperties)
	
	OffsetString = "";
	
	// Getting the offset string for the property group.
	For IterationNumber = 0 To Offset Do
		OffsetString = OffsetString + " ";
	EndDo;
	
	ConditionText = "";
	
	For Each RecordRuleByProperty In GroupProperties Do
		
		If RecordRuleByProperty.IsFolder Then
			
			ConditionPrefix = ?(IsBlankString(ConditionText), "", Chars.LF + OffsetString + BooleanGroupValue + " ");
			
			ConditionText = ConditionText + ConditionPrefix + GetPropertyGroupConditionText(RecordRuleByProperty.Rows, RecordRuleByProperty.BooleanGroupValue, Offset + 10, ObjectProperties);
			
		Else
			
			ConditionPrefix = ?(IsBlankString(ConditionText), "", Chars.LF + OffsetString + BooleanGroupValue + " ");
			
			ConditionText = ConditionText + ConditionPrefix + GetPropertyConditionText(RecordRuleByProperty, ObjectProperties);
			
		EndIf;
		
	EndDo;
	
	ConditionText = "(" + ConditionText + Chars.LF 
				 + OffsetString + ")";
	
	Return ConditionText;
	
EndFunction

Function GetDataTablesTextForORR(DataTable)
	
	TableDataText = "ExchangePlan." + Registration.ExchangePlanName + " AS ExchangePlanMainTable";
	
	For Each TableRow In DataTable Do
		
		TableSynonym = Registration.ExchangePlanName + TableRow.Name;
		
		TableDataText = TableDataText + Chars.LF + Chars.LF + "LEFT JOIN" + Chars.LF
		                 + "ExchangePlan." + Registration.ExchangePlanName + "." + TableRow.Name + " AS " + TableSynonym + "" + Chars.LF
		                 + "ON ExchangePlanMainTable.Ref = " + TableSynonym + ".Ref";
		
	EndDo;
	
	Return TableDataText;
	
EndFunction

Function ORRData(GroupProperties)
	
	DataTable = New ValueTable;
	DataTable.Columns.Add("Name");
	
	For Each RecordRuleByProperty In GroupProperties Do
		
		If RecordRuleByProperty.IsFolder Then
			
			// Retrieving a data table for the lowest hierarchical level
			GroupDataTable = ORRData(RecordRuleByProperty.Rows);
			
			// Adding received rows to the data table of the top hierarchical level
			For Each GroupTableRow In GroupDataTable Do
				
				FillPropertyValues(DataTable.Add(), GroupTableRow);
				
			EndDo;
			
		Else
			
			TableName = RecordRuleByProperty.NodeParameterTabularSection;
			
			// Skipping the empty table name as it is a node header property.
			If Not IsBlankString(TableName) Then
				
				TableRow = DataTable.Add();
				TableRow.Name = TableName;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Grouping the table
	DataTable.GroupBy("Name");
	
	Return DataTable;
	
EndFunction

Function GetPropertyConditionText(Rule, ObjectProperties)
	
	Var ComparisonType;
	
	ComparisonType = Rule.ComparisonType;
	
	// Comparison kind must be inverted as the exchange plan table and the table of the object to be 
	// registered contain data in inverted order in DC 2.0 configuration on setting ORR and in exchange 
	// plan query in this module.
	InvertComparisonType(ComparisonType);
	
	TextOperator = GetCompareOperatorText(ComparisonType);
	
	TableSynonym = ?(IsBlankString(Rule.NodeParameterTabularSection),
	                              "ExchangePlanMainTable",
	                               Registration.ExchangePlanName + Rule.NodeParameterTabularSection);
	//
	
	// A query parameter or a constant value can be used as a literal
	//
	// Example:
	// ExchangePlanProperty <comparison kind> &ObjectProperty_MyProperty
	// ExchangePlanProperty <comparison kind> DATETIME(1987,10,19,0,0,0).
	
	If Rule.IsConstantString Then
		
		ConstantValueType = TypeOf(Rule.ConstantValue);
		
		If ConstantValueType = BooleanType Then // Boolean
			
			QueryParameterLiteral = Format(Rule.ConstantValue, "BF=Ложь; BT=Истина");
			
		ElsIf ConstantValueType = NumberType Then // Number
			
			QueryParameterLiteral = Format(Rule.ConstantValue, "NDS=.; NZ=0; NG=0; NN=1");
			
		ElsIf ConstantValueType = DateType Then // Date
			
			YearString     = Format(Year(Rule.ConstantValue),     "NZ=0; NG=0");
			MonthString   = Format(Month(Rule.ConstantValue),   "NZ=0; NG=0");
			DayString    = Format(Day(Rule.ConstantValue),    "NZ=0; NG=0");
			HourString     = Format(Hour(Rule.ConstantValue),     "NZ=0; NG=0");
			MinuteString  = Format(Minute(Rule.ConstantValue),  "NZ=0; NG=0");
			SecondString = Format(Second(Rule.ConstantValue), "NZ=0; NG=0");
			
			QueryParameterLiteral = "DATETIME("
			+ YearString + ","
			+ MonthString + ","
			+ DayString + ","
			+ HourString + ","
			+ MinuteString + ","
			+ SecondString
			+ ")";
			
		Else // The Enclosing string in quotation marks string
			
			// 
			QueryParameterLiteral = """" + Rule.ConstantValue + """";
			
		EndIf;
		
	Else
		
		ObjectPropertyKey = StrReplace(Rule.ObjectProperty, ".", "_");
		
		QueryParameterLiteral = "&ObjectProperty_" + ObjectPropertyKey + "";
		
		ObjectProperties.Insert(ObjectPropertyKey, Rule.ObjectProperty);
		
	EndIf;
	
	ConditionText = TableSynonym + "." + Rule.NodeParameter + " " + TextOperator + " " + QueryParameterLiteral;
	
	Return ConditionText;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Compiling object registration rules (ORR) by object properties.

Procedure PrepareRegistrationRuleByObjectProperties(ORR)
	
	ORR.RuleByObjectPropertiesEmpty = (ORR.FilterByObjectProperties.Rows.Count() = 0);
	
	// Skipping the blank rule.
	If ORR.RuleByObjectPropertiesEmpty Then
		Return;
	EndIf;
	
	ObjectProperties = New Structure;
	
	FillObjectPropertyStructure(ORR.FilterByObjectProperties, ObjectProperties);
	
EndProcedure

Procedure FillObjectPropertyStructure(ValuesTree, ObjectProperties)
	
	For Each TreeRow In ValuesTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			FillObjectPropertyStructure(TreeRow, ObjectProperties);
			
		Else
			
			TreeRow.ObjectPropertyKey = StrReplace(TreeRow.ObjectProperty, ".", "_");
			
			ObjectProperties.Insert(TreeRow.ObjectPropertyKey, TreeRow.ObjectProperty);
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal auxiliary procedures and functions.

Procedure ReportProcessingError(Code = -1, ErrorDescription = "")
	
	// Setting the global error flag.
	ErrorFlag = True;
	
	If ErrorMessages = Undefined Then
		ErrorMessages = InitMessages();
	EndIf;
	
	MessageString = ErrorMessages[Code];
	
	MessageString = ?(MessageString = Undefined, "", MessageString);
	
	If Not IsBlankString(ErrorDescription) Then
		
		MessageString = MessageString + Chars.LF + ErrorDescription;
		
	EndIf;
	
	WriteLogEvent(EventLogMessageKey(), EventLogLevel.Error,,, MessageString);
	
EndProcedure

Procedure InvertComparisonType(ComparisonType)
	
	If      ComparisonType = "Greater"         Then ComparisonType = "Less";
	ElsIf ComparisonType = "GreaterOrEqual" Then ComparisonType = "LessOrEqual";
	ElsIf ComparisonType = "Less"         Then ComparisonType = "Greater";
	ElsIf ComparisonType = "LessOrEqual" Then ComparisonType = "GreaterOrEqual";
	EndIf;
	
EndProcedure

Procedure CheckExchangePlanExists()
	
	If TypeOf(Registration) <> Type("Structure") Then
		
		ReportProcessingError(0);
		Return;
		
	EndIf;
	
	If Registration.ExchangePlanName <> ExchangePlanNameForImport Then
		
		ErrorDescription = NStr("ru = 'В правилах регистрации указан план обмена %1, а загрузка выполняется для плана обмена %2'; en = 'The name of the exchange plan specified in the registration rules (%1) does not match with the name of the exchange plan whose data is imported (%2)'; pl = 'W zasadach rejestracji jest określony plan wymiany %1, a pobieranie jest wykonywane dla planu wymiany %2';es_ES = 'Plan de intercambio %1 está especificado en las reglas del registro, y la importación está en progreso para el plan de intercambio %2';es_CO = 'Plan de intercambio %1 está especificado en las reglas del registro, y la importación está en progreso para el plan de intercambio %2';tr = 'Alışveriş planı %1 kayıt kurallarında belirtilmiştir ve devam eden içe aktarma %2 alışveriş planı içindir';it = 'Il nome del piano di scambio specificato nelle regole di registrazione (%1) non corrisponde al nome del piano di scambio i cui dati sono importati (%2)';de = 'Der Austauschplan %1 ist in den Registrierungsregeln angegeben und der Importvorgang ist für den Austauschplan gültig %2'");
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescription, Registration.ExchangePlanName, ExchangePlanNameForImport);
		ReportProcessingError(5, ErrorDescription);
		
	EndIf;
	
EndProcedure

Function GetCompareOperatorText(Val ComparisonType = "Equal")
	
	// Default return value.
	TextOperator = "=";
	
	If      ComparisonType = "Equal"          Then TextOperator = "=";
	ElsIf ComparisonType = "NotEqual"        Then TextOperator = "<>";
	ElsIf ComparisonType = "Greater"         Then TextOperator = ">";
	ElsIf ComparisonType = "GreaterOrEqual" Then TextOperator = ">=";
	ElsIf ComparisonType = "Less"         Then TextOperator = "<";
	ElsIf ComparisonType = "LessOrEqual" Then TextOperator = "<=";
	EndIf;
	
	Return TextOperator;
EndFunction

Function GetConfigurationPresentationFromRegistrationRules()
	
	ConfigurationName = "";
	Registration.Property("ConfigurationSynonym", ConfigurationName);
	
	If Not ValueIsFilled(ConfigurationName) Then
		Return "";
	EndIf;
	
	AccurateVersion = "";
	Registration.Property("ConfigurationVersion", AccurateVersion);
	
	If ValueIsFilled(AccurateVersion) Then
		
		AccurateVersion = CommonClientServer.ConfigurationVersionWithoutBuildNumber(AccurateVersion);
		
		ConfigurationName = ConfigurationName + " version " + AccurateVersion;
		
	EndIf;
	
	Return ConfigurationName;
		
EndFunction

Function GetObjectPropertyAsString(ObjectProperties)
	
	Result = "";
	
	For Each Item In ObjectProperties Do
		
		Result = Result + Item.Value + " AS " + Item.Key + ", ";
		
	EndDo;
	
	// Deleting the last two characters.
	StringFunctionsClientServer.DeleteLastCharInString(Result, 2);
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// For operations with the XMLReader object.

// Reads the attribute value by the name from the specified object, converts the value to the 
// specified primitive type.
//
// Parameters:
//  Object - XMLReader object positioned to the beginning of the element whose attribute is required.
//                
//  Type - a value of Type type. Attribute type.
//  Name         - String. Attribute name.
//
// Returns:
//  The attribute value received by the name and casted to the specified type.
// 
Function deAttribute(Object, Type, Name)
	
	ValueStr = TrimR(Object.GetAttribute(Name));
	
	If Not IsBlankString(ValueStr) Then
		
		Return XMLValue(Type, ValueStr);
		
	Else
		If Type = StringType Then
			Return "";
			
		ElsIf Type = BooleanType Then
			Return False;
			
		ElsIf Type = NumberType Then
			Return 0;
			
		ElsIf Type = DateType Then
			Return BlankDateValue;
			
		EndIf;
	EndIf;
	
EndFunction

// Reads the element text and converts the value to the specified type.
//
// Parameters:
//  Object - XMLReader object whose data will be read.
//  Type - type of the return value.
//  SearchByProperty - for reference types, you can specify a property to be used for searching the 
//                     object: Code, Description, <AttributeName>, Name (predefined value).
//
// Returns:
//  Value of an XML element converted to the relevant type.
//
Function deElementValue(Object, Type, SearchByProperty="")

	Value = "";
	Name      = Object.LocalName;

	While Object.Read() Do
		
		NodeName = Object.LocalName;
		NodeType = Object.NodeType;
		
		If NodeType = XMLNodeType.Text Then
			
			Value = TrimR(Object.Value);
			
		ElsIf (NodeName = Name) AND (NodeType = XMLNodeType.EndElement) Then
			
			Break;
			
		Else
			
			Return Undefined;
			
		EndIf;
	EndDo;
	
	Return XMLValue(Type, Value)
	
EndFunction

// Skips xml nodes to the end of the specified item (whichg is currently the default one).
//
// Parameters:
//  Object - an object of the XMLReader type.
//  Name - a name of node, to the end of which items are skipped.
// 
Procedure deSkip(Object, Name = "")
	
	AttachmentsCount = 0; // Number of attachments with the same name.
	
	If IsBlankString(Name) Then
	
		Name = Object.LocalName;
	
	EndIf;
	
	While Object.Read() Do
		
		NodeName = Object.LocalName;
		NodeType = Object.NodeType;
		
		If NodeName = Name Then
			
			If NodeType = XMLNodeType.EndElement Then
				
				If AttachmentsCount = 0 Then
					Break;
				Else
					AttachmentsCount = AttachmentsCount - 1;
				EndIf;
				
			ElsIf NodeType = XMLNodeType.StartElement Then
				
				AttachmentsCount = AttachmentsCount + 1;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local internal functions for retrieving properties.

Function EventLogMessageKey()
	
	Return DataExchangeServer.DataExchangeRuleImportEventLogEvent();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Initializing attributes and modular variables.

// Initializes data processor attributes and modular variables.
//
// Parameters:
//  No.
// 
Procedure InitAttributesAndModuleVariables()
	
	ErrorFlag = False;
	
	// Types
	StringType            = Type("String");
	BooleanType            = Type("Boolean");
	NumberType             = Type("Number");
	DateType              = Type("Date");
	
	BlankDateValue = Date('00010101');
	
	BooleanPropertyRootGroupValue = "AND"; // Boolean value for the root property group.
	
EndProcedure

// Initializes the registration structure.
//
// Parameters:
//  No.
// 
Function RecordInitialization()
	
	Registration = New Structure;
	Registration.Insert("FormatVersion",       "");
	Registration.Insert("ID",                  "");
	Registration.Insert("Description",        "");
	Registration.Insert("CreationDateTime",   BlankDateValue);
	Registration.Insert("ExchangePlan",          "");
	Registration.Insert("ExchangePlanName",      "");
	Registration.Insert("Comment",         "");
	
	// Configuration parameters
	Registration.Insert("PlatformVersion",     "");
	Registration.Insert("ConfigurationVersion",  "");
	Registration.Insert("ConfigurationSynonym", "");
	Registration.Insert("Configuration",        "");
	
	Return Registration;
	
EndFunction

// Initializes a variable that contains mapping of message codes and their description.
//
// Parameters:
//  No.
// 
Function InitMessages()
	
	Messages = New Map;
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Messages.Insert(0, NStr("ru = 'Внутренняя ошибка'; en = 'Internal error'; pl = 'Błąd zewnętrzny';es_ES = 'Error interno';es_CO = 'Error interno';tr = 'Dahili hata';it = 'Errore interno';de = 'Interner Fehler'", DefaultLanguageCode));
	Messages.Insert(1, NStr("ru = 'Ошибка открытия файла правил'; en = 'Error opening the rule file.'; pl = 'Błąd otwarcia pliku reguł';es_ES = 'Ha ocurrido un error al abrir el archivo de reglas';es_CO = 'Ha ocurrido un error al abrir el archivo de reglas';tr = 'Kural dosyası açılırken bir hata oluştu';it = 'Errore durante l''apertura del file di regole.';de = 'Beim Öffnen der Regeldatei ist ein Fehler aufgetreten'", DefaultLanguageCode));
	Messages.Insert(2, NStr("ru = 'Ошибка при загрузке правил'; en = 'Error loading rules.'; pl = 'Błąd podczas importu reguł';es_ES = 'Ha ocurrido un error al importar las reglas';es_CO = 'Ha ocurrido un error al importar las reglas';tr = 'Kurallar içe aktarılırken bir hata oluştu';it = 'Errore durante il caricamento regole.';de = 'Beim Importieren von Regeln ist ein Fehler aufgetreten'", DefaultLanguageCode));
	Messages.Insert(3, NStr("ru = 'Ошибка формата правил'; en = 'Rule format error'; pl = 'Błąd formatu reguł';es_ES = 'Error de formato de la regla';es_CO = 'Error de formato de la regla';tr = 'Kural biçimi hatası';it = 'Errore di formato Regola';de = 'Regelformatfehler'", DefaultLanguageCode));
	Messages.Insert(4, NStr("ru = 'Ошибка при получении файла правил для чтения'; en = 'Error retrieving the rule file for reading.'; pl = 'Wystąpił błąd podczas odbierania pliku reguły odczytu';es_ES = 'Ha ocurrido un error al recibir un archivo de reglas de lectura';es_CO = 'Ha ocurrido un error al recibir un archivo de reglas de lectura';tr = 'Bir okuma kuralı dosyası alınırken hata oluştu';it = 'Errore nel recupero del file di regola per la lettura.';de = 'Beim Empfang einer Leseregeldatei ist ein Fehler aufgetreten'", DefaultLanguageCode));
	Messages.Insert(5, NStr("ru = 'Загружаемые правила регистрации не предназначены для текущего плана обмена.'; en = 'Registration rules you try to load are not intended for the current exchange plan.'; pl = 'Zaimportowane reguły rejestracji nie dotyczą bieżącego planu wymiany.';es_ES = 'Reglas del registro de la importación no son para el plan de intercambio actual.';es_CO = 'Reglas del registro de la importación no son para el plan de intercambio actual.';tr = 'İçe aktarılan kayıt kuralları mevcut alışveriş planı için geçerli değildir.';it = 'Le regole di registrazione che stai provando a caricare non sono intese per il corrente piano di scambio.';de = 'Importierte Registrierungsregeln sind nicht für den aktuellen Austauschplan.'", DefaultLanguageCode));
	
	Return Messages;
	
EndFunction

#EndRegion

#Region Initializing

InitAttributesAndModuleVariables();

#EndRegion

#EndIf