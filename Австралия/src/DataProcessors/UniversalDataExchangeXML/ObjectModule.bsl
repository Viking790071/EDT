#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

////////////////////////////////////////////////////////////////////////////////
// ACRONYMS IN VARIABLE NAMES

//  OCR is an object conversion rule.
//  OCR is an object property conversion rule.
//  PGCR is an object property group conversion rule.
//  VCR is an object value conversion rule.
//  DER is a data export rule.
//  DCR is a data clearing rule.

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY MODULE VARIABLES FOR CREATING ALGORITHMS (FOR BOTH IMPORT AND EXPORT)

Var Conversion  Export;  // Conversion property structure (name, ID, and exchange event handlers).

Var Algorithms    Export;  // Structure containing used algorithms.
Var Queries      Export;  // Structure containing used queries.
Var AdditionalDataProcessors Export;  // Structure containing used external data processors.

Var Rules      Export;  // Structure containing references to OCR.

Var Managers    Export;  // Map containing the following fields: Name, TypeName, RefTypeAsString, Manager, MetadataObject, and OCR.
Var ManagersForExchangePlans Export;
Var ExchangeFile Export;            // Sequentially written or read exchange file.

Var AdditionalDataProcessorParameters Export;  // Structure containing parameters of used external data processors.

Var ParametersInitialized Export;  // If True, necessary conversion parameters are initialized.

Var mDataProtocolFile Export; // Data exchange log file.
Var CommentObjectProcessingFlag Export;

Var EventHandlersExternalDataProcessor Export; // The ExternalDataProcessorsManager object to call export procedures of handlers when debugging 
                                                   // import or export.

Var CommonProceduresFunctions;  // The variable stores a reference to the current instance of the data processor called ThisObject.
                              // It is required to call export procedures from event handlers.

Var mHandlerParameterTemplate; // Spreadsheet document with handler parameters.
Var mCommonProceduresFunctionsTemplate;  // Text document with comments, global variables and wrappers of common procedures and functions.
                                    // 

Var mDataProcessingModes; // The structure that contains modes of using this data processor.
Var DataProcessingMode;   // It contains current value of data processing mode.

Var mAlgorithmDebugModes; // The structure that contains modes of debugging algorithms.
Var IntegratedAlgorithms; // The structure containing algorithms with integrated codes of nested algorithms.

Var HandlerNames; // The structure that contains names of all exchange rule handlers.

Var ApplicationSeparators; // Array: contains application separators.

////////////////////////////////////////////////////////////////////////////////
// FLAGS THAT SHOW WHETHER GLOBAL EVENT HANDLERS EXIST

Var HasBeforeExportObjectGlobalHandler;
Var HasAfterExportObjectGlobalHandler;

Var HasBeforeConvertObjectGlobalHandler;

Var HasBeforeImportObjectGlobalHandler;
Var HasAfterImportObjectGlobalHandler;

Var DestinationPlatformVersion;
Var DestinationPlatform;

////////////////////////////////////////////////////////////////////////////////
// VARIABLES THAT ARE USED IN EXCHANGE HANDLERS (BOTH FOR IMPORT AND EXPORT)

Var deStringType;                  // Type("String")
Var deBooleanType;                  // Type("Boolean")
Var deNumberType;                   // Type("Number")
Var deDateType;                    // Type("Date")
Var deValueStorageType;       // Type("ValueStorage")
Var deUUIDType; // Type("UUID")
Var deBinaryDataType;          // Type("BinaryData")
Var deAccumulationRecordTypeType;   // Type("AccumulationRecordType")
Var deObjectDeletionType;         // Type("ObjectDeletion")
Var deAccountTypeType;			    // Type("AccountType")
Var deTypeType;			  		    // Type("Type")
Var deMapType;		    // Type("Map".

Var deXMLNodeType_EndElement  Export;
Var deXMLNodeType_StartElement Export;
Var deXMLNodeType_Text          Export;

Var BlankDateValue Export;

Var deMessages;             // Map. Key - an error code, Value - error details.

Var mExchangeRuleTemplateList Export;


////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCESSING MODULE VARIABLES
 
Var mExportedObjectCounter Export;   // Number - counter of exported objects.
Var mSnCounter Export;   // Number - an NBSp counter.
Var mPropertyConversionRuleTable;      // ValueTable - a template for restoring the table structure by copying.
                                             //                   
Var mXMLRules;                           // XML string that contains exchange rule description.
Var mTypesForDestinationRow;


////////////////////////////////////////////////////////////////////////////////
// IMPORT PROCESSING MODULE VARIABLES
 
Var mImportedObjectCounter Export;// Number - imported object counter.

Var mExchangeFileAttributes Export;       // Structure. After opening the file it contains exchange file attributes according to the format.
                                          // 
                                          // 

Var ImportedObjects Export;         // Map. Key - object NBSp in file,
                                          // Value - a reference to the imported object.
Var ImportedGlobalObjects Export;
Var ImportedObjectToStoreCount Export;  // Number of stored imported objects. If the number of imported object exceeds the value of this 
                                          // variable, the ImportedObjects map is cleared.
                                          // 
Var RememberImportedObjects Export;

Var mExtendedSearchParameterMap;
Var mConversionRuleMap; // Map to define an object conversion rule by this object type.

Var mDataImportDataProcessor Export;

Var mEmptyTypeValueMap;
Var mTypeDescriptionMap;

Var mExchangeRulesReadOnImport Export;

Var mDataExportCallStack;

Var mDataTypeMapForImport;

Var mNotWrittenObjectGlobalStack;

Var EventsAfterParameterImport Export;

Var CurrentNestingLevelExportByRule;

////////////////////////////////////////////////////////////////////////////////
// VARIABLES TO STORE STANDARD SUBSYSTEM MODULES

Var ModulePeriodClosingDates;

#EndRegion

#Region Public

#Region StringOperations

// Splits a string into two parts: before the separator substring and after it.
//
// Parameters:
//  Str          - String - a string to be split;
//  Separator  - String - a separator substring:
//  Mode        - Number -0 - separator is not included in the returned substrings.
//                        1 - separator is included in the left substring.
//                        2 - separator is included in the right substring.
//
// Returns:
//  The right part of the string - before the separator character.
// 
Function SplitWithSeparator(Page, Val Separator, Mode=0) Export

	RightPart         = "";
	SeparatorPos      = StrFind(Page, Separator);
	SeparatorLength    = StrLen(Separator);
	If SeparatorPos > 0 Then
		RightPart	 = Mid(Page, SeparatorPos + ?(Mode=2, 0, SeparatorLength));
		Page          = TrimAll(Left(Page, SeparatorPos - ?(Mode=1, -SeparatorLength + 1, 1)));
	EndIf;

	Return(RightPart);

EndFunction

// Converts values from a string to an array using the specified separator.
//
// Parameters:
//  Str            - String - a string to be split.
//  Separator    - String - a separator substring.
//
// Returns:
//  Array - received array of values.
// 
Function ArrayFromString(Val Page, Separator=",") Export

	Array      = New Array;
	RightPart = SplitWithSeparator(Page, Separator);
	
	While Not IsBlankString(Page) Do
		Array.Add(TrimAll(Page));
		Page         = RightPart;
		RightPart = SplitWithSeparator(Page, Separator);
	EndDo; 

	Return(Array);
	
EndFunction

// Splits the string into several strings by the separator. The separator can be any length.
//
// Parameters:
//  String                 - String - delimited text;
//  String            - String - a text separator, at least 1 character;
//  SkipEmptyStrings - Boolean - flag that shows whether empty strings must be included in the result.
//    If this parameter is not set, the function executes in compatibility with its earlier version.
//     - if space is used as a separator, empty strings are not included in the result, for other 
//       separators empty strings are included in the result.
//     if String parameter does not contain significant characters (or it is an empty string) and 
//       space is used as a separator, the function returns an array with a single empty string 
//       value (""). - if the String parameter does not contain significant characters (or it is an empty string) and any character except space is used as a separator, the function returns an empty array.
//
//
// Returns:
//  Array - an array of strings.
//
// Example:
//  SplitStringIntoSubstringArray(",One,,Two,", ",") - returns an array of 5 items, three of which 
//  are empty strings;
//  SplitStringIntoSubstringArray(",one,,two,", ",", True) - returns an array of two items;
//  SplitStringIntoSubstringArray(" one   two  ", " ") - returns an array of two items;
//  SplitStringIntoSubstringArray("") - returns a blank array;
//  SplitStringIntoSubstringArray("",,False) - returns an array of one item "" (empty string);
//  SplitStringIntoSubstringArray - returns an array with an empty string ("");
//
Function SplitStringIntoSubstringsArray(Val Row, Val Separator = ",", Val SkipEmptyStrings = Undefined) Export
	
	Result = New Array;
	
	// This procedure ensures backward compatibility.
	If SkipEmptyStrings = Undefined Then
		SkipEmptyStrings = ?(Separator = " ", True, False);
		If IsBlankString(Row) Then 
			If Separator = " " Then
				Result.Add("");
			EndIf;
			Return Result;
		EndIf;
	EndIf;
	//
	
	Position = StrFind(Row, Separator);
	While Position > 0 Do
		Substring = Left(Row, Position - 1);
		If Not SkipEmptyStrings Or Not IsBlankString(Substring) Then
			Result.Add(Substring);
		EndIf;
		Row = Mid(Row, Position + StrLen(Separator));
		Position = StrFind(Row, Separator);
	EndDo;
	
	If Not SkipEmptyStrings Or Not IsBlankString(Row) Then
		Result.Add(Row);
	EndIf;
	
	Return Result;
	
EndFunction 

// Returns a number in the string format, without a symbolic prefix.
// Example:
//  GetStringNumberWithoutPrefixes("TM0000001234") = "0000001234"
//
// Parameters:
//  Number - String - a number, from which the function result must be calculated.
// 
// Returns:
//   String - a number string without symbolic prefixes.
//
Function GetStringNumberWithoutPrefixes(Number) Export
	
	NumberWithoutPrefixes = "";
	Cnt = StrLen(Number);
	
	While Cnt > 0 Do
		
		Char = Mid(Number, Cnt, 1);
		
		If (Char >= "0" AND Char <= "9") Then
			
			NumberWithoutPrefixes = Char + NumberWithoutPrefixes;
			
		Else
			
			Return NumberWithoutPrefixes;
			
		EndIf;
		
		Cnt = Cnt - 1;
		
	EndDo;
	
	Return NumberWithoutPrefixes;
	
EndFunction

// Splits a string into a prefix and numerical part.
//
// Parameters:
//  Str            - String - a string to be split;
//  NumberPart  - Number - a variable that contains numeric part of the passed string.
//  Mode          - String -  if "Number", then returns the numerical part otherwise returns a prefix.
//
// Returns:
//  String - a string prefix.
//
Function GetNumberPrefixAndNumericalPart(Val Page, NumericalPart = "", Mode = "") Export

	NumericalPart = 0;
	Prefix = "";
	Page = TrimAll(Page);
	Length   = StrLen(Page);
	
	StringNumberWithoutPrefix = GetStringNumberWithoutPrefixes(Page);
	StringPartLength = StrLen(StringNumberWithoutPrefix);
	If StringPartLength > 0 Then
		NumericalPart = Number(StringNumberWithoutPrefix);
		Prefix = Mid(Page, 1, Length - StringPartLength);
	Else
		Prefix = Page;	
	EndIf;

	If Mode = "Number" Then
		Return(NumericalPart);
	Else
		Return(Prefix);
	EndIf;

EndFunction

// Casts the number (code) to the required length, splitting the number into a prefix and numeric part. 
// The space between the prefix and number is filled with zeros.
// 
// Can be used in the event handlers whose script is stored in data exchange rules.
//  Is called with the Execute() method.
// The "No links to function found" message during the configuration check is not an error.
// 
//
// Parameters:
//  Str          - String - a string to be converted.
//  Length        - Number - required length of a row.
//  AddZerosIfLengthNotLessCurrentNumberLength - Boolean - shows that it is necessary to add zeros.
//  Prefix      - String - a prefix to be added to the number.
//
// Returns:
//  String       - code or number casted to the required length.
// 
Function CastNumberToLength(Val Page, Length, AddZerosIfLengthNotLessCurrentNumberLength = True, Prefix = "") Export

	If IsBlankString(Page)
		OR StrLen(Page) = Length Then
		
		Return Page;
		
	EndIf;
	
	Page             = TrimAll(Page);
	IncomingNumberLength = StrLen(Page);

	NumericalPart   = "";
	StringNumberPrefix   = GetNumberPrefixAndNumericalPart(Page, NumericalPart);
	
	FinalPrefix = ?(IsBlankString(Prefix), StringNumberPrefix, Prefix);
	ResultingPrefixLength = StrLen(FinalPrefix);
	
	NumericPartString = Format(NumericalPart, "NG=0");
	NumericPartLength = StrLen(NumericPartString);

	If (Length >= IncomingNumberLength AND AddZerosIfLengthNotLessCurrentNumberLength)
		OR (Length < IncomingNumberLength) Then
		
		For TemporaryVariable = 1 To Length - ResultingPrefixLength - NumericPartLength Do
			
			NumericPartString = "0" + NumericPartString;
			
		EndDo;
	
	EndIf;
	
	// Cutting excess symbols
	NumericPartString = Right(NumericPartString, Length - ResultingPrefixLength);
		
	Result = FinalPrefix + NumericPartString;

	Return Result;

EndFunction

// Adds a substring to a number of code prefix.
// Can be used in the event handlers whose script is stored in data exchange rules.
//  Is called with the Execute() method.
// The "No links to function found" message during the configuration check is not an error.
// 
//
// Parameters:
//  Str          - String - number or code;
//  Additive - String - a substring to be added to a prefix.
//  Length        - Number - required resulting length of a row.
//  Mode        - String - pass "Left" if you want to add substring from the left, otherwise the substring will be added from the right.
//
// Returns:
//  String       - a number or code with the specified substring added to the prefix.
//
Function AddToPrefix(Val Page, Additive = "", Length = "", Mode = "Left") Export

	Page = TrimAll(Format(Page,"NG=0"));

	If IsBlankString(Length) Then
		Length = StrLen(Page);
	EndIf;

	NumericalPart   = "";
	Prefix         = GetNumberPrefixAndNumericalPart(Page, NumericalPart);

	If Mode = "Left" Then
		Result = TrimAll(Additive) + Prefix;
	Else
		Result = Prefix + TrimAll(Additive);
	EndIf;

	While Length - StrLen(Result) - StrLen(Format(NumericalPart, "NG=0")) > 0 Do
		Result = Result + "0";
	EndDo;

	Result = Result + Format(NumericalPart, "NG=0");

	Return Result;

EndFunction

// Supplements string with the specified symbol to the specified length.
//
// Parameters:
//  Str          - String - string to be supplemented;
//  Length        - Number - required length of a resulting row.
//  What          - String - acharacter used for supplementing the string.
//
// Returns:
//  String - the received string that is supplemented with the specified symbol to the specified length.
//
Function odSupplementString(Page, Length, Than = " ") Export

	Result = TrimAll(Page);
	While Length - StrLen(Result) > 0 Do
		Result = Result + Than;
	EndDo;

	Return(Result);

EndFunction

#EndRegion

#Region DataOperations

// Returns a string - a name of the passed enumeration value.
// Can be used in the event handlers whose script is stored in data exchange rules.
//  Is called with the Execute() method.
// The "No links to function found" message during the configuration check is not an error.
// 
//
// Parameters:
//  Value     - EnumRef - an enumeration value.
//
// Returns:
//  String       - a name of the passed enumeration value.
//
Function deEnumValueName(Value) Export

	MetadateObject       = Value.Metadata();
	ValueIndex = Enums[MetadateObject.Name].IndexOf(Value);

	Return MetadateObject.EnumValues[ValueIndex].Name;

EndFunction

// Defines whether the passed value is filled.
//
// Parameters:
//  Value       - Arbitrary - CatalogRef, DocumentRef, string or any other type.
//                   Value to be checked.
//  IsNULL        - Boolean - if the passed value is NULL, this variable is set to True.
//
// Returns:
//  True         - the value is not filled in, otherwise False.
//
Function deEmpty(Value, IsNULL=False) Export

	// Primitive types first
	If Value = Undefined Then
		Return True;
	ElsIf Value = NULL Then
		IsNULL   = True;
		Return True;
	EndIf;
	
	ValueType = TypeOf(Value);
	
	If ValueType = deValueStorageType Then
		
		Result = deEmpty(Value.Get());
		Return Result;
		
	ElsIf ValueType = deBinaryDataType Then
		
		Return False;
		
	Else
		
		// The value is considered empty if it is equal to the default value of its type.
		// 
		Try
			Return Not ValueIsFilled(Value);
		Except
			// In case of mutable values.
			Return False;
		EndTry;
	EndIf;
	
EndFunction

// Returns the TypeDescription object that contains the specified type.
//
// Parameters:
//  TypeValue - String, Type - contains a type name or value of the Type type.
//  
// Returns:
//  TypesDetails - Types description object.
//
Function deTypeDetails(TypeValue) Export
	
	TypesDetails = mTypeDescriptionMap[TypeValue];
	
	If TypesDetails = Undefined Then
		
		TypesArray = New Array;
		If TypeOf(TypeValue) = deStringType Then
			TypesArray.Add(Type(TypeValue));
		Else
			TypesArray.Add(TypeValue);
		EndIf; 
		TypesDetails	= New TypeDescription(TypesArray);
		
		mTypeDescriptionMap.Insert(TypeValue, TypesDetails);
		
	EndIf;
	
	Return TypesDetails;
	
EndFunction

// Returns the blank (default) value of the specified type.
//
// Parameters:
//  Type          - String, Type - a type name or value of the Type type.
//
// Returns:
//  Arbitrary - a blank value of the specified type.
// 
Function deGetEmptyValue(Type) Export

	EmptyTypeValue = mEmptyTypeValueMap[Type];
	
	If EmptyTypeValue = Undefined Then
		
		EmptyTypeValue = deTypeDetails(Type).AdjustValue(Undefined);
		mEmptyTypeValueMap.Insert(Type, EmptyTypeValue);
		
	EndIf;
	
	Return EmptyTypeValue;

EndFunction

// Performs a simple search for infobase object by the specified property.
//
// Parameters:
//  Manager       - CatalogManager, DocumentManager - manager of the object to be searched.
//  Property       - String - a property to implement the search: Name, Code, 
//                   Description or a Name of an indexed attribute.
//  Value       - String, Number, Date - value of a property to be used for searching the object.
//  FoundByUUIDObject - CatalogObject, DocumentObject - an infobase object that was found by UUID 
//                   while executing function.
//  CommonPropertyStructure - structure - properties of the object to be searched.
//  CommonSearchProperties - Structure - common properties of the search.
//  SearchByUUIDQueryString - String - a query text for to search by UUID.
//
// Returns:
//  Arbitrary - found infobase object.
//
Function FindObjectByProperty(Manager, Property, Value,
	FoundByUUIDObject,
	CommonPropertyStructure = Undefined, CommonSearchProperties = Undefined,
	SearchByUUIDQueryString = "") Export
	
	If CommonPropertyStructure = Undefined Then
		Try
			CurrPropertiesStructure = Managers[TypeOf(Manager.EmptyRef())];
			TypeName = CurrPropertiesStructure.TypeName;
		Except
			TypeName = "";
		EndTry;
	Else
		TypeName = CommonPropertyStructure.TypeName;
	EndIf;
	
	If Property = "Name" Then
		
		Return Manager[Value];
		
	ElsIf Property = "Code"
		AND (TypeName = "Catalog"
		OR TypeName = "ChartOfCharacteristicTypes"
		OR TypeName = "ChartOfAccounts"
		OR TypeName = "ExchangePlan"
		OR TypeName = "ChartOfCalculationTypes") Then
		
		Return Manager.FindByCode(Value);
		
	ElsIf Property = "Description"
		AND (TypeName = "Catalog"
		OR TypeName = "ChartOfCharacteristicTypes"
		OR TypeName = "ChartOfAccounts"
		OR TypeName = "ExchangePlan"
		OR TypeName = "ChartOfCalculationTypes"
		OR TypeName = "Task") Then
		
		Return Manager.FindByDescription(Value, TRUE);
		
	ElsIf Property = "Number"
		AND (TypeName = "Document"
		OR TypeName = "BusinessProcess"
		OR TypeName = "Task") Then
		
		Return Manager.FindByNumber(Value);
		
	ElsIf Property = "{UUID}" Then
		
		RefByUUID = Manager.GetRef(New UUID(Value));
		
		Ref = CheckRefExists(RefByUUID, Manager, FoundByUUIDObject,
			SearchByUUIDQueryString);
			
		Return Ref;
		
	ElsIf Property = "{PredefinedItemName}" Then
		
		Try
			
			Ref = Manager[Value];
			
		Except
			
			Ref = Manager.FindByCode(Value);
			
		EndTry;
		
		Return Ref;
		
	Else
		
		// You can find it only by attribute, except for strings of arbitrary length and value storage.
		If NOT (Property = "Date"
			OR Property = "Posted"
			OR Property = "DeletionMark"
			OR Property = "Owner"
			OR Property = "Parent"
			OR Property = "IsFolder") Then
			
			Try
				
				UnlimitedLengthString = IsUnlimitedLengthParameter(CommonPropertyStructure, Value, Property);
				
			Except
				
				UnlimitedLengthString = False;
				
			EndTry;
			
			If NOT UnlimitedLengthString Then
				
				Return Manager.FindByAttribute(Property, Value);
				
			EndIf;
			
		EndIf;
		
		ObjectRef = FindItemUsingRequest(CommonPropertyStructure, CommonSearchProperties, , Manager);
		Return ObjectRef;
		
	EndIf;
	
EndFunction

// Performs a simple search for infobase object by the specified property.
//
// Parameters:
//  Str            - String - a property value, by which an object is filtered;
//                   
//  Type            - Type - type of the document to be searched.
//  Property       - String - a property name, by which an object is found.
//
// Returns:
//  Arbitrary - found infobase object.
//
Function deGetValueByString(Page, Type, Property = "") Export

	If IsBlankString(Page) Then
		Return New(Type);
	EndIf; 

	Properties = Managers[Type];

	If Properties = Undefined Then
		
		TypesDetails = deTypeDetails(Type);
		Return TypesDetails.AdjustValue(Page);
		
	EndIf;

	If IsBlankString(Property) Then
		
		If Properties.TypeName = "Enum" Then
			Property = "Name";
		Else
			Property = "{PredefinedItemName}";
		EndIf;
		
	EndIf;
	
	Return FindObjectByProperty(Properties.Manager, Property, Page, Undefined);
	
EndFunction

// Returns a string presentation of a value type.
//
// Parameters:
//  ValueOrType - Arbitrary - a value of any type or Type.
//
// Returns:
//  String - a string presentation of the value type.
//
Function deValueTypeAsString(ValueOrType) Export

	ValueType	= TypeOf(ValueOrType);
	
	If ValueType = deTypeType Then
		ValueType	= ValueOrType;
	EndIf; 
	
	If (ValueType = Undefined) Or (ValueOrType = Undefined) Then
		Result = "";
	ElsIf ValueType = deStringType Then
		Result = "String";
	ElsIf ValueType = deNumberType Then
		Result = "Number";
	ElsIf ValueType = deDateType Then
		Result = "Date";
	ElsIf ValueType = deBooleanType Then
		Result = "Boolean";
	ElsIf ValueType = deValueStorageType Then
		Result = "ValueStorage";
	ElsIf ValueType = deUUIDType Then
		Result = "UUID";
	ElsIf ValueType = deAccumulationRecordTypeType Then
		Result = "AccumulationRecordType";
	Else
		Manager = Managers[ValueType];
		If Manager = Undefined Then
			
			Text= NStr("ru='Неизвестный тип:'; en = 'Unknown type:'; pl = 'Nieznany typ:';es_ES = 'Tipo desconocido:';es_CO = 'Tipo desconocido:';tr = 'Bilinmeyen tür:';it = 'Tipo sconosciuto:';de = 'Unbekannter Typ:'") + String(TypeOf(ValueType));
			MessageToUser(Text);
			
		Else
			Result = Manager.RefTypeString;
		EndIf;
	EndIf;

	Return Result;
	
EndFunction

// Returns an XML presentation of the TypesDetails object.
// Can be used in the event handlers whose script is stored in data exchange rules.
// 
// Parameters:
//  TypesDetails  - TypesDetails - a TypesDetails object whose XML presentation is being retrieved.
//
// Returns:
//  String - an XML presentation of the passed TypesDetails object.
//
Function deGetTypesDescriptionXMLPresentation(TypesDetails) Export
	
	TypeNode = CreateNode("Types");
	
	If TypeOf(TypesDetails) = Type("Structure") Then
		SetAttribute(TypeNode, "AllowedSign",          TrimAll(TypesDetails.AllowedSign));
		SetAttribute(TypeNode, "Digits",             TrimAll(TypesDetails.Digits));
		SetAttribute(TypeNode, "FractionDigits", TrimAll(TypesDetails.FractionDigits));
		SetAttribute(TypeNode, "Length",                   TrimAll(TypesDetails.Length));
		SetAttribute(TypeNode, "AllowedLength",         TrimAll(TypesDetails.AllowedLength));
		SetAttribute(TypeNode, "DateComposition",              TrimAll(TypesDetails.DateFractions));
		
		For each StrType In TypesDetails.Types Do
			NodeOfType = CreateNode("Type");
			NodeOfType.WriteText(TrimAll(StrType));
			AddSubordinateNode(TypeNode, NodeOfType);
		EndDo;
	Else
		NumberQualifiers       = TypesDetails.NumberQualifiers;
		StringQualifiers      = TypesDetails.StringQualifiers;
		DateQualifiers        = TypesDetails.DateQualifiers;
		
		SetAttribute(TypeNode, "AllowedSign",          TrimAll(NumberQualifiers.AllowedSign));
		SetAttribute(TypeNode, "Digits",             TrimAll(NumberQualifiers.Digits));
		SetAttribute(TypeNode, "FractionDigits", TrimAll(NumberQualifiers.FractionDigits));
		SetAttribute(TypeNode, "Length",                   TrimAll(StringQualifiers.Length));
		SetAttribute(TypeNode, "AllowedLength",         TrimAll(StringQualifiers.AllowedLength));
		SetAttribute(TypeNode, "DateComposition",              TrimAll(DateQualifiers.DateFractions));
		
		For each Type In TypesDetails.Types() Do
			NodeOfType = CreateNode("Type");
			NodeOfType.WriteText(deValueTypeAsString(Type));
			AddSubordinateNode(TypeNode, NodeOfType);
		EndDo;
	EndIf;
	
	TypeNode.WriteEndElement();
	
	Return(TypeNode.Close());
	
EndFunction

#EndRegion

#Region ProceeduresAndFunctionsToWorkWithXMLObjectWrite

// Replaces prohibited XML characters with other character.
//
// Parameters:
//       Text - String - a text where the characters are to be changed.
//       ReplacementChar - String - a value, by which the prohibited characters will be changed.
// Returns:
//       String - replacement result.
//
Function ReplaceProhibitedXMLChars(Val Text, ReplacementChar = " ") Export
	
	Position = FindDisallowedXMLCharacters(Text);
	While Position > 0 Do
		Text = StrReplace(Text, Mid(Text, Position, 1), ReplacementChar);
		Position = FindDisallowedXMLCharacters(Text);
	EndDo;
	
	Return Text;
EndFunction

// Creates a new XML node
// The function can be used in event handlers, application code.
// of which is stored in the data exchange rules. Is called with the Execute() method.
//
// Parameters:
//  Name  - String - a node name.
//
// Returns:
//  XMLWriter - an object of the new XML node.
//
Function CreateNode(Name) Export

	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteStartElement(Name);

	Return XMLWriter;

EndFunction

// Adds a new XML node to the specified parent node.
// Can be used in the event handlers whose script is stored in data exchange rules.
//  Is called with the Execute() method.
// The "No links to function found" message during the configuration check is not an error.
// 
//
// Parameters:
//  ParentNode - parent XML node.
//  Name - String - a name of the node to be added.
//
// Returns:
//  New XML node added to the specified parent node.
//
Function AddNode(ParentNode, Name) Export

	ParentNode.WriteStartElement(Name);

	Return ParentNode;

EndFunction

// Copies the specified xml node.
// Can be used in the event handlers whose script is stored in data exchange rules.
//  Is called with the Execute() method.
// The "No links to function found" message during the configuration check is not an error.
// 
//
// Parameters:
//  Node - XML node.
//
// Returns:
//  New xml is a copy of the specified node.
//
Function CopyNode(Node) Export

	Page = Node.Close();

	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	
	If WriteToXMLAdvancedMonitoring Then
		
		Page = DeleteProhibitedXMLChars(Page);
		
	EndIf;
	
	XMLWriter.WriteRaw(Page);

	Return XMLWriter;
	
EndFunction

// Writes item and its value to the specified object.
//
// Parameters:
//  Object - XMLWrite - an object of the XMLWrite type.
//  Name            - String - an item name.
//  Value       - Arbitrary - item value.
// 
Procedure deWriteElement(Object, Name, Value="") Export

	Object.WriteStartElement(Name);
	Page = XMLString(Value);
	
	If WriteToXMLAdvancedMonitoring Then
		
		Page = DeleteProhibitedXMLChars(Page);
		
	EndIf;
	
	Object.WriteText(Page);
	Object.WriteEndElement();
	
EndProcedure

// Subordinates an xml node to the specified parent node.
//
// Parameters:
//  ParentNode - parent XML node.
//  Node           - xml - a node to be subordinated.
//
Procedure AddSubordinateNode(ParentNode, Node) Export

	If TypeOf(Node) <> deStringType Then
		Node.WriteEndElement();
		InformationToWriteToFile = Node.Close();
	Else
		InformationToWriteToFile = Node;
	EndIf;
	
	ParentNode.WriteRaw(InformationToWriteToFile);
		
EndProcedure

// Sets an attribute of the specified xml node.
//
// Parameters:
//  Node - XML node
//  Name            - String - an attribute name.
//  Value - Arbitrary - a value to set.
//
Procedure SetAttribute(Node, Name, Value) Export

	RecordString = XMLString(Value);
	
	If WriteToXMLAdvancedMonitoring Then
		
		RecordString = DeleteProhibitedXMLChars(RecordString);
		
	EndIf;
	
	Node.WriteAttribute(Name, RecordString);
	
EndProcedure

#EndRegion

#Region ProceeduresAndFunctionsToWorkWithXMLObjectRead

// Reads the attribute value by the name from the specified object, converts the value to the 
// specified primitive type.
//
// Parameters:
//  Object      - XMLReader - XMLReader object positioned to the beginning of the item whose 
//                attribute is required.
//  Type        - Type - attribute type.
//  Name         - String - an attribute name.
//
// Returns:
//  Arbitrary - attribute value received by the name and casted to the specified type.
// 
Function deAttribute(Object, Type, Name) Export

	ValueStr = Object.GetAttribute(Name);
	If Not IsBlankString(ValueStr) Then
		Return XMLValue(Type, TrimR(ValueStr));
	ElsIf      Type = deStringType Then
		Return ""; 
	ElsIf Type = deBooleanType Then
		Return False;
	ElsIf Type = deNumberType Then
		Return 0;
	ElsIf Type = deDateType Then
		Return BlankDateValue;
	EndIf;
		
EndFunction
 
// Skips xml nodes to the end of the specified item (whichg is currently the default one).
//
// Parameters:
//  Object   - XMLReader - an object of the XMLReader type.
//  Name      - String - a name of node, to the end of which items are skipped.
// 
Procedure deSkip(Object, Name = "") Export

	AttachmentsCount = 0; // Number of attachments with the same name.

	If Name = "" Then
		
		Name = Object.LocalName;
		
	EndIf; 
	
	While Object.Read() Do
		
		If Object.LocalName <> Name Then
			Continue;
		EndIf;
		
		NodeType = Object.NodeType;
			
		If NodeType = deXMLNodeType_EndElement Then
				
			If AttachmentsCount = 0 Then
					
				Break;
					
			Else
					
				AttachmentsCount = AttachmentsCount - 1;
					
			EndIf;
				
		ElsIf NodeType = deXMLNodeType_StartElement Then
				
			AttachmentsCount = AttachmentsCount + 1;
				
		EndIf;
					
	EndDo;
	
EndProcedure

// Reads the element text and converts the value to the specified type.
//
// Parameters:
//  Object           - XMLReader - XMLReader object whose data will be read.
//  Type              - Type - type of the value to be received.
//  SearchByProperty - String - for reference types, you can specify a property, by which.
//                     search for the following object: "Code", "Description", <AttributeName>, "Name" (of the predefined value).
//  CutStringRight - Boolean - shows that you need to cut string on the right.
//
// Returns:
//  Value of an XML element converted to the relevant type.
//
Function deElementValue(Object, Type, SearchByProperty = "", CutStringRight = True) Export

	Value = "";
	Name      = Object.LocalName;

	While Object.Read() Do
		
		NodeType = Object.NodeType;
		
		If NodeType = deXMLNodeType_Text Then
			
			Value = Object.Value;
			
			If CutStringRight Then
				
				Value = TrimR(Value);
				
			EndIf;
						
		ElsIf (Object.LocalName = Name) AND (NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		Else
			
			Return Undefined;
			
		EndIf;
		
	EndDo;

	
	If (Type = deStringType)
		OR (Type = deBooleanType)
		OR (Type = deNumberType)
		OR (Type = deDateType)
		OR (Type = deValueStorageType)
		OR (Type = deUUIDType)
		OR (Type = deAccumulationRecordTypeType)
		OR (Type = deAccountTypeType) Then
		
		Return XMLValue(Type, Value);
		
	Else
		
		Return deGetValueByString(Value, Type, SearchByProperty);
		
	EndIf;
	
EndFunction

#EndRegion

#Region ExchangeFileOperationsProceduresAndFunctions

// Saves the specified xml node to file.
//
// Parameters:
//  Node - XML node to be saved to the file.
//
Procedure WriteToFile(Node) Export

	If TypeOf(Node) <> deStringType Then
		InformationToWriteToFile = Node.Close();
	Else
		InformationToWriteToFile = Node;
	EndIf;
	
	If DirectReadingInDestinationIB Then
		
		ErrorStringInDestinationInfobase = "";
		SendWriteInformationToDestination(InformationToWriteToFile, ErrorStringInDestinationInfobase);
		If Not IsBlankString(ErrorStringInDestinationInfobase) Then
			
			Raise ErrorStringInDestinationInfobase;
			
		EndIf;
		
	Else
		
		ExchangeFile.WriteLine(InformationToWriteToFile);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsOfExchangeProtocolOperations

// Returns a Structure type object containing all possible fields of the execution protocol record 
// (such as error messages and others).
//
// Parameters:
//  MessageCode - String - message code.
//  ErrorString - String - error string content.
//
// Returns:
//  Structure - all possible fields of the execution protocol.
//
Function GetProtocolRecordStructure(MessageCode = "", ErrorRow = "") Export

	ErrorStructure = New Structure("OCRName,DPRName,Sn,Gsn,Source,ObjectType,Property,Value,ValueType,OCR,PCR,PGCR,DER,DPR,Object,DestinationProperty,ConvertedValue,Handler,ErrorDescription,ModulePosition,Text,MessageCode,ExchangePlanNode");
	
	ModuleLine              = SplitWithSeparator(ErrorRow, "{");
	ErrorDescription            = SplitWithSeparator(ModuleLine, "}: ");
	
	If ErrorDescription <> "" Then
		
		ErrorStructure.ErrorDescription         = ErrorDescription;
		ErrorStructure.ModulePosition          = ModuleLine;
				
	EndIf;
	
	If ErrorStructure.MessageCode <> "" Then
		
		ErrorStructure.MessageCode           = MessageCode;
		
	EndIf;
	
	Return ErrorStructure;
	
EndFunction 

// Writes error details to the exchange protocol.
//
// Parameters:
//  MessageCode - String - message code.
//  ErrorString - String - error string content.
//  Object - Arbitrary - object, which the error is related to.
//  ObjectType - Type - type of the object, which the error is related to.
//
// Returns:
//  String - an error string.
//
Function WriteErrorInfoToProtocol(MessageCode, ErrorRow, Object, ObjectType = Undefined) Export
	
	WP         = GetProtocolRecordStructure(MessageCode, ErrorRow);
	WP.Object  = Object;
	
	If ObjectType <> Undefined Then
		WP.ObjectType     = ObjectType;
	EndIf;	
		
	ErrorRow = WriteToExecutionProtocol(MessageCode, WP);	
	
	Return ErrorRow;	
	
EndFunction

// Registers the error of object conversion rule handler (import) in the execution protocol.
//
// Parameters:
//  MessageCode - String - message code.
//  ErrorString - String - error string content.
//  RuleName - String - a name of object conversion rule.
//  Source - Arbitrary - source, which conversion caused an error.
//  ObjectType - Type - type of the object, which conversion caused an error.
//  Object - Arbitrary - an object received as a result of conversion.
//  HandlerName - String - name of the handler where an error occurred.
//
Procedure WriteInfoOnOCRHandlerImportError(MessageCode, ErrorRow, RuleName, Source,
	ObjectType, Object, HandlerName) Export
	
	WP            = GetProtocolRecordStructure(MessageCode, ErrorRow);
	WP.OCRName     = RuleName;
	WP.ObjectType = ObjectType;
	WP.Handler = HandlerName;
	
	If Not IsBlankString(Source) Then
		
		WP.Source = Source;
		
	EndIf;
	
	If Object <> Undefined Then
		
		WP.Object = String(Object);
		
	EndIf;
	
	ErrorMessageString = WriteToExecutionProtocol(MessageCode, WP);
	
	If Not DebugModeFlag Then
		Raise ErrorMessageString;
	EndIf;
	
EndProcedure

// Registers the error of property conversion rule handler in the execution protocol.
//
// Parameters:
//  MessageCode - String - message code.
//  ErrorString - String - error string content.
//  OCR - ValueTableRow - a property conversion rule.
//  PCR - ValueTableRow - a property conversion rule.
//  Source - Arbitrary - source, which conversion caused an error.
//  HandlerName - String - name of the handler where an error occurred.
//  Value - Arbitrary - value, which conversion caused an error.
//  IsPCR - Boolean - an error occurred when processing the rule of property conversion.
//
Procedure WriteErrorInfoPCRHandlers(MessageCode, ErrorRow, OCR, PCR, Source = "", 
	HandlerName = "", Value = Undefined, IsPCR = True) Export
	
	WP                        = GetProtocolRecordStructure(MessageCode, ErrorRow);
	WP.OCR                    = OCR.Name + "  (" + OCR.Description + ")";
	
	RuleName = PCR.Name + "  (" + PCR.Description + ")";
	If IsPCR Then
		WP.PCR                = RuleName;
	Else
		WP.PGCR               = RuleName;
	EndIf;
	
	TypesDetails = New TypeDescription("String");
	StringSource  = TypesDetails.AdjustValue(Source);
	If Not IsBlankString(StringSource) Then
		WP.Object = StringSource + "  (" + TypeOf(Source) + ")";
	Else
		WP.Object = "(" + TypeOf(Source) + ")";
	EndIf;
	
	If IsPCR Then
		WP.DestinationProperty      = PCR.Destination + "  (" + PCR.DestinationType + ")";
	EndIf;
	
	If HandlerName <> "" Then
		WP.Handler         = HandlerName;
	EndIf;
	
	If Value <> Undefined Then
		WP.ConvertedValue = String(Value) + "  (" + TypeOf(Value) + ")";
	EndIf;
	
	ErrorMessageString = WriteToExecutionProtocol(MessageCode, WP);
	
	If Not DebugModeFlag Then
		Raise ErrorMessageString;
	EndIf;
		
EndProcedure

#EndRegion

#Region GeneratingHandlerCallInterfacesInExchangeRulesProcedures

// Complements existing collections with rules for exchanging handler call interfaces.
//
// Parameters:
//  ConversionStructure - Structure - contains the conversion rules and global handlers.
//  OCRTable           - ValueTable - contains object conversion rules.
//  DERTable           - ValuesTree - contains the data export rules.
//  DPRTable           - ValuesTree - contains data clearing rules.
//  
Procedure SupplementRulesWithHandlerInterfaces(ConversionStructure, OCRTable, DERTable, DPRTable) Export
	
	mHandlerParameterTemplate = GetTemplate("HandlersParameters");
	
	// Adding the Conversion interfaces (global.
	SupplementWithConversionRuleInterfaceHandler(ConversionStructure);
	
	// Adding the DER interfaces
	SupplementDataExportRulesWithHandlerInterfaces(DERTable, DERTable.Rows);
	
	// Adding DPR interfaces.
	SupplementWithDataClearingRuleHandlerInterfaces(DPRTable, DPRTable.Rows);
	
	// Adding OCR, PCR, PGCR interfaces.
	SupplementWithObjectConversionRuleHandlerInterfaces(OCRTable);
	
EndProcedure 

#EndRegion

#Region ExchangeRulesOperationProcedures

// Searches for the conversion rule by name or according to the passed object type.
// 
//
// Parameters:
//  Object         -  a source object whose conversion rule will be searched.
//  RuleName     - String - conversion rule name.
//
// Returns:
//  ValueTableRow - conversion rule reference in the rules table.
// 
Function FindRule(Object, RuleName="") Export

	If Not IsBlankString(RuleName) Then
		
		Rule = Rules[RuleName];
		
	Else
		
		Rule = Managers[TypeOf(Object)];
		If Rule <> Undefined Then
			Rule    = Rule.OCR;
			
			If Rule <> Undefined Then 
				RuleName = Rule.Name;
			EndIf;
			
		EndIf; 
		
	EndIf;
	
	Return Rule; 
	
EndFunction

// Saves exchange rules in the internal format.
//
Procedure SaveRulesInInternalFormat() Export

	For Each Rule In ConversionRulesTable Do
		Rule.Exported.Clear();
		Rule.OnlyRefsExported.Clear();
	EndDo;

	RulesStructure = New Structure;
	
	// Saving queries
	QueriesToSave = New Structure;
	For Each StructureItem In Queries Do
		QueriesToSave.Insert(StructureItem.Key, StructureItem.Value.Text);
	EndDo;

	ParametersToSave = New Structure;
	For Each StructureItem In Parameters Do
		ParametersToSave.Insert(StructureItem.Key, Undefined);
	EndDo;

	RulesStructure.Insert("ExportRuleTable",      ExportRuleTable);
	RulesStructure.Insert("ConversionRulesTable",   ConversionRulesTable);
	RulesStructure.Insert("Algorithms",                  Algorithms);
	RulesStructure.Insert("Queries",                    QueriesToSave);
	RulesStructure.Insert("Conversion",                Conversion);
	RulesStructure.Insert("mXMLRules",                mXMLRules);
	RulesStructure.Insert("ParameterSetupTable", ParameterSetupTable);
	RulesStructure.Insert("Parameters",                  ParametersToSave);
	
	RulesStructure.Insert("DestinationPlatformVersion",   DestinationPlatformVersion);
	
	SavedSettings  = New ValueStorage(RulesStructure);
	
EndProcedure

// Sets parameters values  in the Parameters structure by the ParameterSetupTable table.
// 
//
Procedure SetParametersFromDialog() Export

	For Each TableRow In ParameterSetupTable Do
		Parameters.Insert(TableRow.Name, TableRow.Value);
	EndDo;

EndProcedure

// Sets the parameter value in the parameter table as a handler.
//
// Parameters:
//   ParameterName - String - a parameter name.
//   ParameterValue - Arbitrary - parameter value.
//
Procedure SetParameterValueInTable(ParameterName, ParameterValue) Export
	
	TableRow = ParameterSetupTable.Find(ParameterName, "Name");
	
	If TableRow <> Undefined Then
		
		TableRow.Value = ParameterValue;	
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ClearingRuleProcessing

// Deletes (or marks for deletion) a selection object according to the specified rule.
//
// Parameters:
//  Object - Arbitrary - selection object to be deleted (or whose deletion mark will be set).
//  Rule        - ValueTableRow - data clearing rule reference.
//  Properties - Manager - metadata object properties of the object to be deleted.
//  IncomingData - Arbitrary - arbitrary auxiliary data.
// 
Procedure SelectionObjectDeletion(Object, Rule, Properties=Undefined, IncomingData=Undefined) Export

	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ApplicationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	Cancel			       = False;
	DeleteDirectly = Rule.Directly;


	// BeforeSelectionObjectDeletion handler
	If Not IsBlankString(Rule.BeforeDelete) Then
	
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeDelete"));
				
			Else
				
				Execute(Rule.BeforeDelete);
				
			EndIf;
			
		Except
			
			WriteDataClearingHandlerErrorInfo(29, ErrorDescription(), Rule.Name, Object, "BeforeDeleteSelectionObject");
									
		EndTry;
		
		If Cancel Then
		
			Return;
			
		EndIf;
			
	EndIf;	 


	Try
		
		ExecuteObjectDeletion(Object, Properties, DeleteDirectly);
					
	Except
		
		WriteDataClearingHandlerErrorInfo(24, ErrorDescription(), Rule.Name, Object, "");
								
	EndTry;	

EndProcedure

#EndRegion

#Region DataExportProcedures

// Exports an object according to the specified conversion rule.
//
// Parameters:
//  Source				 - Arbitrary - a data source.
//  Destination				 - a destination object XML node.
//  IncomingData			 - Arbitrary - auxiliary data to execute conversion.
//                             
//  OutgoingData			 - Arbitrary - arbitrary auxiliary data passed to property conversion rules.
//                             
//  OCRName					 - String - a name of the conversion rule used to execute export.
//  RefNode				 - a destination object reference XML node.
//  GetRefNodeOnly - Boolean - if True, the object is not exported but the reference XML node is 
//                             generated.
//  OCR						 - ValueTableRow - conversion rule reference.
//  IsRuleWithGlobalObjectExport - Boolean - a flag of a rule with global object export.
//  SelectionForDataExport - QueryResultSelection - a selection containing data for export.
//
// Returns:
//  a reference XML node or a destination value.
//
Function ExportByRule(Source					= Undefined,
						   Destination					= Undefined,
						   IncomingData			= Undefined,
						   OutgoingData			= Undefined,
						   OCRName					= "",
						   RefNode				= Undefined,
						   GetRefNodeOnly	= False,
						   OCR						= Undefined,
						   IsRuleWithGlobalObjectExport = False,
						   SelectionForDataExport = Undefined) Export
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ApplicationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	// Searching for OCR
	If OCR = Undefined Then
		
		OCR = FindRule(Source, OCRName);
		
	ElsIf (Not IsBlankString(OCRName))
		AND OCR.Name <> OCRName Then
		
		OCR = FindRule(Source, OCRName);
				
	EndIf;	
	
	If OCR = Undefined Then
		
		WP = GetProtocolRecordStructure(45);
		
		WP.Object = Source;
		WP.ObjectType = TypeOf(Source);
		
		WriteToExecutionProtocol(45, WP, True); // OCR is not found
		Return Undefined;
		
	EndIf;

	CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule + 1;
	
	If CommentObjectProcessingFlag Then
		
		TypeDetails = New TypeDescription("String");
		SourceToString = TypeDetails.AdjustValue(Source);
		SourceToString = ?(SourceToString = "", " ", SourceToString);
		
		ObjectRul = SourceToString + "  (" + TypeOf(Source) + ")";
		
		OCRNameString = " OCR: " + TrimAll(OCRName) + "  (" + TrimAll(OCR.Description) + ")";
		
		StringForUser = ?(GetRefNodeOnly, NStr("ru = 'Конвертация ссылки на объект: %1'; en = 'Converting object reference: %1'; pl = 'Konwersja linku do obiektu: %1';es_ES = 'Conversión de la referencia al objeto: %1';es_CO = 'Conversión de la referencia al objeto: %1';tr = 'Referansın %1 nesneye dönüştürülmesi';it = 'Converti riferimento oggetto: %1';de = 'Konvertierung der Referenz auf Objekt: %1'"), NStr("ru = 'Конвертация объекта: %1'; en = 'Converting object: %1'; pl = 'Konwertowanie linku na obiekt: %1';es_ES = 'Conversión del objeto: %1';es_CO = 'Conversión del objeto: %1';tr = 'Nesne dönüştürmesi: %1';it = 'Conversione oggetto: %1';de = 'Objektkonvertierung: %1'"));
		StringForUser = SubstituteParametersToString(StringForUser, ObjectRul);
		
		WriteToExecutionProtocol(StringForUser + OCRNameString, , False, CurrentNestingLevelExportByRule + 1, 7);
		
	EndIf;
	
	IsRuleWithGlobalObjectExport = ExecuteDataExchangeInOptimizedFormat AND OCR.UseQuickSearchOnImport;

    RememberExported       = OCR.RememberExported;
	ExportedObjects          = OCR.Exported;
	ExportedObjectsOnlyRefs = OCR.OnlyRefsExported;
	AllObjectsExported         = OCR.AllObjectsExported;
	DontReplaceObjectOnImport = OCR.DoNotReplace;
	DontCreateIfNotFound     = OCR.DoNotCreateIfNotFound;
	OnExchangeObjectByRefSetGIUDOnly     = OCR.OnMoveObjectByRefSetGIUDOnly;
	
	AutonumberingPrefix		= "";
	WriteMode     			= "";
	PostingMode 			= "";
	TempFileList = Undefined;

   	TypeName          = "";
	PropertyStructure = Managers[OCR.Source];
	If PropertyStructure = Undefined Then
		PropertyStructure = Managers[TypeOf(Source)];
	EndIf;
	
	If PropertyStructure <> Undefined Then
		TypeName = PropertyStructure.TypeName;
	EndIf;

	// ExportedDataKey
	
	If (Source <> Undefined) AND RememberExported Then
		If TypeName = "InformationRegister" OR TypeName = "Constants" OR IsBlankString(TypeName) Then
			RememberExported = False;
		Else
			ExportedDataKey = ValueToStringInternal(Source);
		EndIf;
	Else
		ExportedDataKey = OCRName;
		RememberExported = False;
	EndIf;
	
	
	// Variable for storing the predefined item name.
	PredefinedItemName = Undefined;

	// BeforeObjectConversion global handler.
    Cancel = False;	
	If HasBeforeConvertObjectGlobalHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "BeforeConvertObject"));

			Else
				
				Execute(Conversion.BeforeConvertObject);
				
			EndIf;
			
		Except
			WriteInfoOnOCRHandlerExportError(64, ErrorDescription(), OCR, Source, NStr("ru = 'BeforeObjectConversion (глобальный)'; en = 'BeforeObjectConversion (global)'; pl = 'BeforeObjectConversion (globalny)';es_ES = 'BeforeObjectConversion (global)';es_CO = 'BeforeObjectConversion (global)';tr = 'BeforeObjectConversion (global)';it = 'BeforeObjectConversion (globale)';de = 'VorDerObjektkonvertierung (global)'"));
		EndTry;
		
		If Cancel Then	//	Canceling further rule processing.
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Destination;
		EndIf;
		
	EndIf;
	
	// BeforeExport handler
	If OCR.HasBeforeExportHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "BeforeExport"));
				
			Else
				
				Execute(OCR.BeforeExport);
				
			EndIf;
			
		Except
			WriteInfoOnOCRHandlerExportError(41, ErrorDescription(), OCR, Source, "BeforeExportObject");
		EndTry;
		
		If Cancel Then	//	Canceling further rule processing.
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Destination;
		EndIf;
		
	EndIf;
	
	// Perhaps this data has already been exported.
	If Not AllObjectsExported Then
		
		SN = 0;
		
		If RememberExported Then
			
			RefNode = ExportedObjects[ExportedDataKey];
			If RefNode <> Undefined Then
				
				If GetRefNodeOnly Then
					CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
					Return RefNode;
				EndIf;
				
				ExportedRefNumber = ExportedObjectsOnlyRefs[ExportedDataKey];
				If ExportedRefNumber = Undefined Then
					CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
					Return RefNode;
				Else
					
					ExportStackRow = mDataExportCallStack.Find(ExportedDataKey, "Ref");
				
					If ExportStackRow <> Undefined Then
						CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
						Return RefNode;
					EndIf;
					
					ExportStackRow = mDataExportCallStack.Add();
					ExportStackRow.Ref = ExportedDataKey;
					
					SN = ExportedRefNumber;
				EndIf;
			EndIf;
			
		EndIf;
		
		If SN = 0 Then
			
			mSnCounter = mSnCounter + 1;
			SN         = mSnCounter;
			
		EndIf;
		
		// Preventing cyclic reference existence.
		If RememberExported Then
			
			ExportedObjects[ExportedDataKey] = SN;
			If GetRefNodeOnly Then
				ExportedObjectsOnlyRefs[ExportedDataKey] = SN;
			Else
				
				ExportStackRow = mDataExportCallStack.Add();
				ExportStackRow.Ref = ExportedDataKey;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	ValueMap = OCR.Values;
	ValueMapItemCount = ValueMap.Count();
	
	// Predefined item map processing.
	If DestinationPlatform = "V8" Then
		
		// If the name of predefined item is not defined yet, attempting to define it.
		If PredefinedItemName = Undefined Then
			
			If PropertyStructure <> Undefined
				AND ValueMapItemCount > 0
				AND PropertyStructure.SearchByPredefinedItemsPossible Then
			
				Try
					PredefinedNameSource = PredefinedItemName(Source);
				Except
					PredefinedNameSource = "";
				EndTry;
				
			Else
				
				PredefinedNameSource = "";
				
			EndIf;
			
			If NOT IsBlankString(PredefinedNameSource)
				AND ValueMapItemCount > 0 Then
				
				PredefinedItemName = ValueMap[Source];
				
			Else
				PredefinedItemName = Undefined;
			EndIf;
			
		EndIf;
		
		If PredefinedItemName <> Undefined Then
			ValueMapItemCount = 0;
		EndIf;
		
	Else
		PredefinedItemName = Undefined;
	EndIf;
	
	DontExportByValueMap = (ValueMapItemCount = 0);
	
	If Not DontExportByValueMap Then
		
		// If value mapping does not contain values, exporting mapping in the ordinary way.
		RefNode = ValueMap[Source];
		If RefNode = Undefined
			AND OCR.SearchProperties.Count() > 0 Then
			
			// Perhaps, this is a conversion from enumeration into enumeration and
			// required VCR is not found. Exporting an empty reference.
			If PropertyStructure.TypeName = "Enum"
				AND StrFind(OCR.Destination, "EnumRef.") > 0 Then
				
				RefNode = "";
				
			Else
						
				DontExportByValueMap = True;	
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	MustRememberObject = RememberExported AND (Not AllObjectsExported);

	If DontExportByValueMap Then
		
		If OCR.SearchProperties.Count() > 0 
			OR PredefinedItemName <> Undefined Then
			
			//	Creating reference node
			RefNode = CreateNode("Ref");
			
			If MustRememberObject Then
				
				If IsRuleWithGlobalObjectExport Then
					SetAttribute(RefNode, "Gsn", SN);
				Else
					SetAttribute(RefNode, "Sn", SN);
				EndIf;
				
			EndIf;
			
			ExportRefOnly = OCR.DoNotExportPropertyObjectsByRefs OR GetRefNodeOnly;
			
			If DontCreateIfNotFound Then
				SetAttribute(RefNode, "DoNotCreateIfNotFound", DontCreateIfNotFound);
			EndIf;
			
			If OnExchangeObjectByRefSetGIUDOnly Then
				SetAttribute(RefNode, "OnMoveObjectByRefSetGIUDOnly", OnExchangeObjectByRefSetGIUDOnly);
			EndIf;
			
			ExportProperties(Source, Destination, IncomingData, OutgoingData, OCR, OCR.SearchProperties, 
				RefNode, SelectionForDataExport, PredefinedItemName, OCR.DoNotExportPropertyObjectsByRefs OR GetRefNodeOnly);
			
			RefNode.WriteEndElement();
			RefNode = RefNode.Close();
			
			If MustRememberObject Then
				
				ExportedObjects[ExportedDataKey] = RefNode;
				
			EndIf;
			
		Else
			RefNode = SN;
		EndIf;
		
	Else
		
		// Searching in the value map by VCR.
		If RefNode = Undefined Then
			// If cannot find by value Map, try to find by search properties.
			RecordStructure = New Structure("Source,SourceType", Source, TypeOf(Source));
			WriteToExecutionProtocol(71, RecordStructure);
			If ExportStackRow <> Undefined Then
				mDataExportCallStack.Delete(ExportStackRow);
			EndIf;
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Undefined;
		EndIf;
		
		If RememberExported Then
			ExportedObjects[ExportedDataKey] = RefNode;
		EndIf;
		
		If ExportStackRow <> Undefined Then
			mDataExportCallStack.Delete(ExportStackRow);
		EndIf;
		CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
		Return RefNode;
		
	EndIf;
	
	If GetRefNodeOnly Or AllObjectsExported Then
	
		If ExportStackRow <> Undefined Then
			mDataExportCallStack.Delete(ExportStackRow);
		EndIf;
		CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
		Return RefNode;
		
	EndIf;

	If Destination = Undefined Then
		
		Destination = CreateNode("Object");
		
		If IsRuleWithGlobalObjectExport Then
			SetAttribute(Destination, "Gsn", SN);
		Else
			SetAttribute(Destination, "Sn", SN);
		EndIf;
		
		SetAttribute(Destination, "Type", 			OCR.Destination);
		SetAttribute(Destination, "RuleName",	OCR.Name);
		
		If DontReplaceObjectOnImport Then
			SetAttribute(Destination, "DoNotReplace",	"true");
		EndIf;
		
		If Not IsBlankString(AutonumberingPrefix) Then
			SetAttribute(Destination, "AutonumberingPrefix",	AutonumberingPrefix);
		EndIf;
		
		If Not IsBlankString(WriteMode) Then
			SetAttribute(Destination, "WriteMode",	WriteMode);
			If Not IsBlankString(PostingMode) Then
				SetAttribute(Destination, "PostingMode",	PostingMode);
			EndIf;
		EndIf;
		
		If TypeOf(RefNode) <> deNumberType Then
			AddSubordinateNode(Destination, RefNode);
		EndIf; 
		
	EndIf;

	// OnExport handler
	StandardProcessing = True;
	Cancel = False;
	
	If OCR.HasOnExportHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "OnExport"));
				
			Else
				
				Execute(OCR.OnExport);
				
			EndIf;
			
		Except
			WriteInfoOnOCRHandlerExportError(42, ErrorDescription(), OCR, Source, "OnExportObject");
		EndTry;
		
		If Cancel Then	//	Canceling writing the object to a file.
			If ExportStackRow <> Undefined Then
				mDataExportCallStack.Delete(ExportStackRow);
			EndIf;
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return RefNode;
		EndIf;
		
	EndIf;

	// Exporting properties
	If StandardProcessing Then
		
		ExportProperties(Source, Destination, IncomingData, OutgoingData, OCR, OCR.Properties, , SelectionForDataExport, ,
			OCR.DoNotExportPropertyObjectsByRefs OR GetRefNodeOnly, TempFileList);
			
	EndIf;
	
	// AfterExport handler
	If OCR.HasAfterExportHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "AfterExport"));
				
			Else
				
				Execute(OCR.AfterExport);
				
			EndIf;
			
		Except
			WriteInfoOnOCRHandlerExportError(43, ErrorDescription(), OCR, Source, "AfterExportObject");
		EndTry;
		
		If Cancel Then	//	Canceling writing the object to a file.
			
			If ExportStackRow <> Undefined Then
				mDataExportCallStack.Delete(ExportStackRow);
			EndIf;
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return RefNode;
			
		EndIf;
		
	EndIf;
	
	If TempFileList = Undefined Then
	
		//	Writing the object to a file
		Destination.WriteEndElement();
		WriteToFile(Destination);
		
	Else
		
		WriteToFile(Destination);
		
		MoveDataFromTemporaryFiles(TempFileList);
		
		WriteToFile("</Object>");
		
	EndIf;
	
	mExportedObjectCounter = 1 + mExportedObjectCounter;
	
	If MustRememberObject Then
				
		If IsRuleWithGlobalObjectExport Then
			ExportedObjects[ExportedDataKey] = SN;
		EndIf;
		
	EndIf;
	
	If ExportStackRow <> Undefined Then
		mDataExportCallStack.Delete(ExportStackRow);
	EndIf;
	
	CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
	
	// AfterExportToFile handler
	If OCR.HasAfterExportToFileHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "AfterExportToFile"));
				
			Else
				
				Execute(OCR.AfterExportToFile);
				
			EndIf;
			
		Except
			WriteInfoOnOCRHandlerExportError(76, ErrorDescription(), OCR, Source, "HasAfterExportToFileHandler");
		EndTry;				
				
	EndIf;	
	
	Return RefNode;

EndFunction	//	ExportByRule()

// Returns the fragment of query language text that expresses the restriction condition to date interval.
//
// Parameters:
//   Properties - Metadata - metadata object properties.
//   TypeName - String - a type name.
//   TableGroupName - String - a table group name.
//   SelectionForDataClearing - Boolean - selection to clear data.
//
// Returns:
//     String - a query fragment with restriction condition for date interval.
//
Function GetRestrictionByDateStringForQuery(Properties, TypeName, TableGroupName = "", SelectionForDataClearing = False) Export
	
	ResultingDateRestriction = "";
	
	If NOT (TypeName = "Document" OR TypeName = "InformationRegister") Then
		Return ResultingDateRestriction;
	EndIf;
	
	If TypeName = "InformationRegister" Then
		
		Nonperiodical = NOT Properties.Periodic;
		RestrictionByDateNotRequired = SelectionForDataClearing	OR Nonperiodical;
		
		If RestrictionByDateNotRequired Then
			Return ResultingDateRestriction;
		EndIf;
				
	EndIf;	
	
	If IsBlankString(TableGroupName) Then
		RestrictionFieldName = ?(TypeName = "Document", "Date", "Period");
	Else
		RestrictionFieldName = TableGroupName + "." + ?(TypeName = "Document", "Date", "Period");
	EndIf;
	
	If StartDate <> BlankDateValue Then
		
		ResultingDateRestriction = "
		|	WHERE
		|		" + RestrictionFieldName + " >= &StartDate";
		
	EndIf;
		
	If EndDate <> BlankDateValue Then
		
		If IsBlankString(ResultingDateRestriction) Then
			
			ResultingDateRestriction = "
			|	WHERE
			|		" + RestrictionFieldName + " <= &EndDate";
			
		Else
			
			ResultingDateRestriction = ResultingDateRestriction + "
			|	AND
			|		" + RestrictionFieldName + " <= &EndDate";
			
		EndIf;
		
	EndIf;
	
	Return ResultingDateRestriction;
	
EndFunction

// Generates the query result for data clearing export.
// 
// Parameters:
//   Properties - Maneger - metadata object properties.
//   TypeName - String - a type name.
//   SelectionForDataClearing - Boolean - selection to clear data.
//   DeleteObjectsDirectly - Boolean - a flag showing whether direct deletion is required.
//   SelectAllFields - Boolean - shows whether it is necessary to select all fields.
//
// Returns:
//   QueryResult or Undefined - a result of the query to export data cleaning.
//
Function GetQueryResultForExportDataClearing(Properties, TypeName, 
	SelectionForDataClearing = False, DeleteObjectsDirectly = False, SelectAllFields = True) Export 
	
	PermissionRow = ?(ExportAllowedObjectsOnly, " ALLOWED ", "");
			
	FieldSelectionString = ?(SelectAllFields, " * ", "	ObjectForExport.Ref AS Ref ");
	
	If TypeName = "Catalog" 
		OR TypeName = "ChartOfCharacteristicTypes" 
		OR TypeName = "ChartOfAccounts" 
		OR TypeName = "ChartOfCalculationTypes" 
		OR TypeName = "AccountingRegister"
		OR TypeName = "ExchangePlan"
		OR TypeName = "Task"
		OR TypeName = "BusinessProcess" Then
		
		Query = New Query();
		
		If TypeName = "Catalog" Then
			ObjectMetadata = Metadata.Catalogs[Properties.Name];
		ElsIf TypeName = "ChartOfCharacteristicTypes" Then
		    ObjectMetadata = Metadata.ChartsOfCharacteristicTypes[Properties.Name];			
		ElsIf TypeName = "ChartOfAccounts" Then
		    ObjectMetadata = Metadata.ChartsOfAccounts[Properties.Name];
		ElsIf TypeName = "ChartOfCalculationTypes" Then
		    ObjectMetadata = Metadata.ChartsOfCalculationTypes[Properties.Name];
		ElsIf TypeName = "AccountingRegister" Then
		    ObjectMetadata = Metadata.AccountingRegisters[Properties.Name];
		ElsIf TypeName = "ExchangePlan" Then
		    ObjectMetadata = Metadata.ExchangePlans[Properties.Name];
		ElsIf TypeName = "Task" Then
		    ObjectMetadata = Metadata.Tasks[Properties.Name];
		ElsIf TypeName = "BusinessProcess" Then
		    ObjectMetadata = Metadata.BusinessProcesses[Properties.Name];			
		EndIf;
		
		If TypeName = "AccountingRegister" Then
			
			FieldSelectionString = "*";
			TableNameForSelection = Properties.Name + ".RecordsWithExtDimensions";
			
		Else
			
			TableNameForSelection = Properties.Name;	
			
			If ExportAllowedObjectsOnly
				AND NOT SelectAllFields Then
				
				FirstAttributeName = GetFirstMetadataAttributeName(ObjectMetadata);
				If Not IsBlankString(FirstAttributeName) Then
					FieldSelectionString = FieldSelectionString + ", ObjectForExport." + FirstAttributeName;
				EndIf;
				
			EndIf;
			
		EndIf;
		
		Query.Text = "SELECT " + PermissionRow + "
		         |	" + FieldSelectionString + "
		         |FROM
		         |	" + TypeName + "." + TableNameForSelection + " AS ObjectForExport
				 |
				 |";
		
	ElsIf TypeName = "Document" Then
		
		If ExportAllowedObjectsOnly Then
			
			FirstAttributeName = GetFirstMetadataAttributeName(Metadata.Documents[Properties.Name]);
			If Not IsBlankString(FirstAttributeName) Then
				FieldSelectionString = FieldSelectionString + ", ObjectForExport." + FirstAttributeName;
			EndIf;
			
		EndIf;
		
		ResultingDateRestriction = GetRestrictionByDateStringForQuery(Properties, TypeName, "ObjectForExport", SelectionForDataClearing);
		
		Query = New Query();
		
		Query.SetParameter("StartDate", StartDate);
		Query.SetParameter("EndDate", EndDate);
		
		Query.Text = "SELECT " + PermissionRow + "
		         |	" + FieldSelectionString + "
		         |FROM
		         |	" + TypeName + "." + Properties.Name + " AS ObjectForExport
				 |
				 |" + ResultingDateRestriction;
					 
											
	ElsIf TypeName = "InformationRegister" Then
		
		Nonperiodical = NOT Properties.Periodic;
		SubordinatedToRecorder = Properties.SubordinateToRecorder;		
		
		ResultingDateRestriction = GetRestrictionByDateStringForQuery(Properties, TypeName, "ObjectForExport", SelectionForDataClearing);
						
		Query = New Query();
		
		Query.SetParameter("StartDate", StartDate);
		Query.SetParameter("EndDate", EndDate);
		
		SelectionFieldSupplementionStringSubordinateToRegistrar = ?(NOT SubordinatedToRecorder, ", NULL AS Active,
		|	NULL AS Recorder,
		|	NULL AS LineNumber", "");
		
		SelectionFieldSupplementionStringPeriodicity = ?(Nonperiodical, ", NULL AS Period", "");
		
		Query.Text = "SELECT " + PermissionRow + "
		         |	*
				 |
				 | " + SelectionFieldSupplementionStringSubordinateToRegistrar + "
				 | " + SelectionFieldSupplementionStringPeriodicity + "
				 |
		         |FROM
		         |	" + TypeName + "." + Properties.Name + " AS ObjectForExport
				 |
				 |" + ResultingDateRestriction;
		
	Else
		
		Return Undefined;
					
	EndIf;	
	
	Return Query.Execute();
	
EndFunction

// Generates selection for data clearing export.
//
// Parameters:
//   Properties - Maneger - metadata object properties.
//   TypeName - String - a type name.
//   SelectionForDataClearing - Boolean - selection to clear data.
//   DeleteObjectsDirectly - Boolean - shows whether it is required to delete directly.
//   SelectAllFields - Boolean - shows whether it is necessary to select all fields.
//
// Returns:
//   QueryResultSelection - a selection to export data clearing.
//
Function GetSelectionForDataClearingExport(Properties, TypeName, 
	SelectionForDataClearing = False, DeleteObjectsDirectly = False, SelectAllFields = True) Export
	
	QueryResult = GetQueryResultForExportDataClearing(Properties, TypeName, 
			SelectionForDataClearing, DeleteObjectsDirectly, SelectAllFields);
			
	If QueryResult = Undefined Then
		Return Undefined;
	EndIf;
			
	Selection = QueryResult.Select();
	
	Return Selection;
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsToExport

// Fills in the passed values table with object types of metadata for deletion having the access 
// right for deletion.
//
// Parameters:
//   DataTable - ValueTable - a table to fill in.
//
Procedure FillTypeAvailableToDeleteList(DataTable) Export
	
	DataTable.Clear();
	
	For each MetadateObject In Metadata.Catalogs Do
		
		If Not AccessRight("Delete", MetadateObject) Then
			Continue;
		EndIf;
		
		TableRow = DataTable.Add();
		TableRow.Metadata = "CatalogRef." + MetadateObject.Name;
		
	EndDo;

	For each MetadateObject In Metadata.ChartsOfCharacteristicTypes Do
		
		If Not AccessRight("Delete", MetadateObject) Then
			Continue;
		EndIf;
		
		TableRow = DataTable.Add();
		TableRow.Metadata = "ChartOfCharacteristicTypesRef." + MetadateObject.Name;
	EndDo;

	For Each MetadateObject In Metadata.Documents Do
		
		If Not AccessRight("Delete", MetadateObject) Then
			Continue;
		EndIf;
		
		TableRow = DataTable.Add();
		TableRow.Metadata = "DocumentRef." + MetadateObject.Name;
	EndDo;

	For each MetadateObject In Metadata.InformationRegisters Do
		
		If Not AccessRight("Delete", MetadateObject) Then
			Continue;
		EndIf;
		
		Subordinate		=	(MetadateObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate);
		If Subordinate Then Continue EndIf;
		
		TableRow = DataTable.Add();
		TableRow.Metadata = "InformationRegisterRecord." + MetadateObject.Name;
		
	EndDo;
	
EndProcedure

// Sets mark value in subordinate tree rows according to the mark value in the current row.
// 
//
// Parameters:
//  CurRow      - ValueTreeRow - a string, subordinate lines of which are to be processed.
//  Attribute       - String - a name of an attribute, which contains the mark.
// 
Procedure SetSubordinateMarks(curRow, Attribute) Export

	SubordinateElements = curRow.Rows;

	If SubordinateElements.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Row In SubordinateElements Do
		
		If Row.BuilderSettings = Undefined 
			AND Attribute = "UseFilter" Then
			
			Row[Attribute] = 0;
			
		Else
			
			Row[Attribute] = curRow[Attribute];
			
		EndIf;
		
		SetSubordinateMarks(Row, Attribute);
		
	EndDo;
		
EndProcedure

// Sets the mark status for parent rows of the value tree row.
// depending on the mark of the current row.
//
// Parameters:
//  CurRow      - ValueTreeRow - a string, parent lines of which are to be processed.
//  Attribute       - String - a name of an attribute, which contains the mark.
// 
Procedure SetParentMarks(curRow, Attribute) Export

	Parent = curRow.Parent;
	If Parent = Undefined Then
		Return;
	EndIf; 

	CurState       = Parent[Attribute];

	EnabledItemsFound  = False;
	DisabledItemsFound = False;

	If Attribute = "UseFilter" Then
		
		For Each Row In Parent.Rows Do
			
			If Row[Attribute] = 0 
				AND Row.BuilderSettings <> Undefined Then
				
				DisabledItemsFound = True;
				
			ElsIf Row[Attribute] = 1 Then
				EnabledItemsFound  = True;
			EndIf; 
			
			If EnabledItemsFound AND DisabledItemsFound Then
				Break;
			EndIf; 
			
		EndDo;
		
	Else
		
		For Each Row In Parent.Rows Do
			If Row[Attribute] = 0 Then
				DisabledItemsFound = True;
			ElsIf Row[Attribute] = 1
				OR Row[Attribute] = 2 Then
				EnabledItemsFound  = True;
			EndIf; 
			If EnabledItemsFound AND DisabledItemsFound Then
				Break;
			EndIf; 
		EndDo;
		
	EndIf;

	
	If EnabledItemsFound AND DisabledItemsFound Then
		Enable = 2;
	ElsIf EnabledItemsFound AND (Not DisabledItemsFound) Then
		Enable = 1;
	ElsIf (Not EnabledItemsFound) AND DisabledItemsFound Then
		Enable = 0;
	ElsIf (Not EnabledItemsFound) AND (Not DisabledItemsFound) Then
		Enable = 2;
	EndIf;

	If Enable = CurState Then
		Return;
	Else
		Parent[Attribute] = Enable;
		SetParentMarks(Parent, Attribute);
	EndIf; 
	
EndProcedure

// Generates the full path to a file from the directory path and the file name.
//
// Parameters:
//  DirectoryName - String - the path to the directory that contains the file.
//  FileName - String - the file name.
//
// Returns:
//   String - the full path to the file.
//
Function GetExchangeFileName(DirectoryName, FileName) Export

	If Not IsBlankString(FileName) Then
		
		Return DirectoryName + ?(Right(DirectoryName, 1) = "\", "", "\") + FileName;	
		
	Else
		
		Return DirectoryName;
		
	EndIf;

EndFunction

// Passed the data string to import in the destination base.
//
// Parameters:
//  InformationToWriteToFile - String - a data string (XML text).
//  ErrorStringInDestinationInfobase - String - contains error description upon import to the destination infobase.
// 
Procedure SendWriteInformationToDestination(InformationToWriteToFile, ErrorStringInDestinationInfobase = "") Export
	
	mDataImportDataProcessor.ExchangeFile.SetString(InformationToWriteToFile);
	
	mDataImportDataProcessor.ReadData(ErrorStringInDestinationInfobase);
	
	If Not IsBlankString(ErrorStringInDestinationInfobase) Then
		
		MessageString = SubstituteParametersToString(NStr("ru = 'Загрузка в приемнике: %1'; en = 'Importing in destination: %1'; pl = 'Importuj do celu: %1';es_ES = 'Importación en la destinación: %1';es_CO = 'Importación en la destinación: %1';tr = 'Hedefe içe aktar: %1';it = 'Importazione nella destinazione: %1';de = 'Import im Zielort: %1'"), ErrorStringInDestinationInfobase);
		WriteToExecutionProtocol(MessageString, Undefined, True, , , True);
		
	EndIf;
	
EndProcedure

// Writes a name, a type, and a value of the parameter to an exchange message file. This data is sent to the destination infobase.
//
// Parameters:
//   Name                          - String - a parameter name.
//   InitialParameterValue    - Arbitrary - a parameter value.
//   ConversionRule           - String - a conversion rule name for reference types.
// 
Procedure SendOneParameterToDestination(Name, InitialParameterValue, ConversionRule = "") Export
	
	If IsBlankString(ConversionRule) Then
		
		ParameterNode = CreateNode("ParameterValue");
		
		SetAttribute(ParameterNode, "Name", Name);
		SetAttribute(ParameterNode, "Type", deValueTypeAsString(InitialParameterValue));
		
		IsNULL = False;
		Empty = deEmpty(InitialParameterValue, IsNULL);
					
		If Empty Then
			
			// Writing the empty value.
			deWriteElement(ParameterNode, "Empty");
								
			ParameterNode.WriteEndElement();
			
			WriteToFile(ParameterNode);
			
			Return;
								
		EndIf;
	
		deWriteElement(ParameterNode, "Value", InitialParameterValue);
	
		ParameterNode.WriteEndElement();
		
		WriteToFile(ParameterNode);
		
	Else
		
		ParameterNode = CreateNode("ParameterValue");
		
		SetAttribute(ParameterNode, "Name", Name);
		
		IsNULL = False;
		Empty = deEmpty(InitialParameterValue, IsNULL);
					
		If Empty Then
			
			PropertiesOCR = FindRule(InitialParameterValue, ConversionRule);
			DestinationType  = PropertiesOCR.Destination;
			SetAttribute(ParameterNode, "Type", DestinationType);
			
			// Writing the empty value.
			deWriteElement(ParameterNode, "Empty");
								
			ParameterNode.WriteEndElement();
			
			WriteToFile(ParameterNode);
			
			Return;
								
		EndIf;
		
		ExportRefObjectData(InitialParameterValue, Undefined, ConversionRule, Undefined, Undefined, ParameterNode, True);
		
		ParameterNode.WriteEndElement();
		
		WriteToFile(ParameterNode);				
		
	EndIf;	
	
EndProcedure

#EndRegion

#Region SetAttributesValuesAndDataProcessorModalVariables

// Returns the current value of data processor version.
//
// Returns:
//  Number - current value of the data processor version.
//
Function ObjectVersion() Export
	
	Return 218;
	
EndFunction

#EndRegion

#Region InitializingExchangeRulesTables

// Initializes table columns of object property conversion rules.
//
// Parameters:
//  Tab            - ValueTable - a table of property conversion rules to initialize.
// 
Procedure InitPropertyConversionRuleTable(Tab) Export

	Columns = Tab.Columns;

	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Order");

	AddMissingColumns(Columns, "IsFolder", 			deTypeDetails("Boolean"));
    AddMissingColumns(Columns, "GroupRules");

	AddMissingColumns(Columns, "SourceKind");
	AddMissingColumns(Columns, "DestinationKind");
	
	AddMissingColumns(Columns, "SimplifiedPropertyExport", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "XMLNodeRequiredOnExport", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "XMLNodeRequiredOnExportGroup", deTypeDetails("Boolean"));

	AddMissingColumns(Columns, "SourceType", deTypeDetails("String"));
	AddMissingColumns(Columns, "DestinationType", deTypeDetails("String"));
	
	AddMissingColumns(Columns, "Source");
	AddMissingColumns(Columns, "Destination");

	AddMissingColumns(Columns, "ConversionRule");

	AddMissingColumns(Columns, "GetFromIncomingData", deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "DoNotReplace", deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "BeforeExport");
	AddMissingColumns(Columns, "OnExport");
	AddMissingColumns(Columns, "AfterExport");

	AddMissingColumns(Columns, "BeforeProcessExport");
	AddMissingColumns(Columns, "AfterProcessExport");

	AddMissingColumns(Columns, "HasBeforeExportHandler",			deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "HasOnExportHandler",				deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "HasAfterExportHandler",				deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "HasBeforeProcessExportHandler",	deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "HasAfterProcessExportHandler",	deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "CastToLength",	deTypeDetails("Number"));
	AddMissingColumns(Columns, "ParameterForTransferName");
	AddMissingColumns(Columns, "SearchByEqualDate",					deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "ExportGroupToFile",					deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "SearchFieldsString");
	
EndProcedure

#EndRegion

#Region InitAttributesAndModuleVariables

// Initializes the external data processor with event handlers debug module.
//
// Parameters:
//  ExecutionPossible - Boolean - flag that shows that external data processor is initialized successfully.
//  OwnerObject - DataProcessorObject - an object that will own the initialized external data 
//                                     processor.
//  
Procedure InitEventHandlerExternalDataProcessor(ExecutionPossible, OwnerObject) Export
	
	If Not ExecutionPossible Then
		Return;
	EndIf; 
	
	If HandlersDebugModeFlag AND IsBlankString(EventHandlerExternalDataProcessorFileName) Then
		
		WriteToExecutionProtocol(77); 
		ExecutionPossible = False;
		
	ElsIf HandlersDebugModeFlag Then
		
		Try
			
			If IsExternalDataProcessor() Then
				
				Raise
					NStr("ru = 'Внешняя обработка отладки, загружаемая из файла на диске, не поддерживается.'; en = 'External debug data processor imported from the file on disk is not supported.'; pl = 'Zewnętrzny procesor danych importowany z pliku na dysku nie jest obsługiwany.';es_ES = 'Procesamiento externo de depuración, descargado del archivo en el disco, no se admite.';es_CO = 'Procesamiento externo de depuración, descargado del archivo en el disco, no se admite.';tr = 'Diskteki bir dosyadan yüklenen harici hata ayıklama işlemi desteklenmez.';it = 'Il debug esterno dell''elaboratore dati importato dal file su disco non è supportato.';de = 'Externe Debug-Verarbeitung, die aus der Datei auf der Festplatte geladen wird, wird nicht unterstützt.'");
				
			Else
				
				EventHandlersExternalDataProcessor = DataProcessors[EventHandlerExternalDataProcessorFileName].Create();
				
			EndIf;
			
			EventHandlersExternalDataProcessor.Designer(OwnerObject);
			
		Except
			
			EventHandlerExternalDataProcessorDestructor();
			
			MessageToUser(BriefErrorDescription(ErrorInfo()));
			WriteToExecutionProtocol(78);
			
			ExecutionPossible               = False;
			HandlersDebugModeFlag = False;
			
		EndTry;
		
	EndIf;
	
	If ExecutionPossible Then
		
		CommonProceduresFunctions = ThisObject;
		
	EndIf; 
	
EndProcedure

// External data processor destructor.
//
// Parameters:
//  DebugModeEnabled - Boolean - shows whether the debug mode is on.
//  
Procedure EventHandlerExternalDataProcessorDestructor(DebugModeEnabled = False) Export
	
	If Not DebugModeEnabled Then
		
		If EventHandlersExternalDataProcessor <> Undefined Then
			
			Try
				
				EventHandlersExternalDataProcessor.Destructor();
				
			Except
				MessageToUser(BriefErrorDescription(ErrorInfo()));
			EndTry; 
			
		EndIf; 
		
		EventHandlersExternalDataProcessor = Undefined;
		CommonProceduresFunctions               = Undefined;
		
	EndIf;
	
EndProcedure

// Deletes temporary files with the specified name.
//
// Parameters:
//  TempFileName - String - a full name of the file to be deleted. It clears after the procedure is executed.
//  
Procedure DeleteTempFiles(TempFileName) Export
	
	If Not IsBlankString(TempFileName) Then
		
		Try
			
			DeleteFiles(TempFileName);
			
			TempFileName = "";
			
		Except
			WriteLogEvent(NStr("ru = 'Универсальный обмен данными в формате XML'; en = 'Universal data exchange in XML format'; pl = 'Uniwersalna wymiana danymi w formacie XML';es_ES = 'Intercambio de datos universal en el formato XML';es_CO = 'Intercambio de datos universal en el formato XML';tr = 'XML formatında üniversal veri değişimi';it = 'Scambio di dati universale in formato XML';de = 'Universeller Datenaustausch im XML-Format'", DefaultLanguageCode()),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

#Region ExchangeFileOperationsProceduresAndFunctions

// Opens an exchange file, writes a file header according to the exchange format.
//
// Parameters:
//  No.
//
Function OpenExportFile(ErrorMessageString = "")

	// Archive files are recognized by the ZIP extension.
	
	If ArchiveFile Then
		ExchangeFileName = StrReplace(ExchangeFileName, ".zip", ".xml");
	EndIf;
    	
	ExchangeFile = New TextWriter;
	Try
		
		If DirectReadingInDestinationIB Then
			ExchangeFile.Open(GetTempFileName(".xml"), TextEncoding.UTF8);
		Else
			ExchangeFile.Open(ExchangeFileName, TextEncoding.UTF8);
		EndIf;
				
	Except
		
		ErrorMessageString = WriteToExecutionProtocol(8);
		Return "";
		
	EndTry; 
	
	XMLInfoString = "<?xml version=""1.0"" encoding=""UTF-8""?>";
	
	ExchangeFile.WriteLine(XMLInfoString);

	TempXMLWriter = New XMLWriter();
	
	TempXMLWriter.SetString();
	
	TempXMLWriter.WriteStartElement("ExchangeFile");
							
	SetAttribute(TempXMLWriter, "FormatVersion", "2.0");
	SetAttribute(TempXMLWriter, "ExportDate",				CurrentSessionDate());
	SetAttribute(TempXMLWriter, "ExportPeriodStart",		StartDate);
	SetAttribute(TempXMLWriter, "ExportPeriodEnd",	EndDate);
	SetAttribute(TempXMLWriter, "SourceConfigurationName",	Conversion.Source);
	SetAttribute(TempXMLWriter, "DestinationConfigurationName",	Conversion.Destination);
	SetAttribute(TempXMLWriter, "ConversionRuleIDs",		Conversion.ID);
	SetAttribute(TempXMLWriter, "Comment",				Comment);
	
	TempXMLWriter.WriteEndElement();
	
	Page = TempXMLWriter.Close(); 
	
	Page = StrReplace(Page, "/>", ">");
	
	ExchangeFile.WriteLine(Page);
	
	Return XMLInfoString + Chars.LF + Page;
			
EndFunction

// Closes the exchange file.
//
// Parameters:
//  No.
//
Procedure CloseFile()

    ExchangeFile.WriteLine("</ExchangeFile>");
	ExchangeFile.Close();
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsOfTemporaryFilesOperations

Function WriteTextToTemporaryFile(TempFileList)
	
	RecordFileName = GetTempFileName();
	
	RecordsTemporaryFile = New TextWriter;
	
	If SafeMode() <> False Then
		SetSafeModeDisabled(True);
	EndIf;
	
	Try
		RecordsTemporaryFile.Open(RecordFileName, TextEncoding.UTF8);
	Except
		WriteErrorInfoConversionHandlers(1000,
			ErrorDescription(),
			NStr("ru = 'Ошибка при создании временного файла для выгрузки данных'; en = 'Error creating temporary file for data export'; pl = 'Wystąpił błąd podczas tworzenia pliku tymczasowego do eksportu danych';es_ES = 'Ha ocurrido un error al crear un archivo temporal para exportar los datos';es_CO = 'Ha ocurrido un error al crear un archivo temporal para exportar los datos';tr = 'Geçici bir veri dışa aktarımı dosyası oluşturulurken bir hata oluştu';it = 'Errore durante la creazione del file temporaneo per l''upload dei dati';de = 'Beim Erstellen einer temporären Datei für den Datenexport ist ein Fehler aufgetreten'"));
		Raise;
	EndTry;
	
	// Temporary files deletion is performed not by location via DeleteFiles(RecordFileName), but 
	// centrally.
	TempFileList.Add(RecordFileName);
		
	Return RecordsTemporaryFile;
	
EndFunction

Function ReadTextFromTemporaryFile(TempFileName)
	
	TempFile = New TextReader;
	
	If SafeMode() <> False Then
		SetSafeModeDisabled(True);
	EndIf;
	
	Try
		TempFile.Open(TempFileName, TextEncoding.UTF8);
	Except
		WriteErrorInfoConversionHandlers(1000,
			ErrorDescription(),
			NStr("ru = 'Ошибка при открытии временного файла для переноса данных в файл обмена'; en = 'An error occurred when opening the temporary file to transfer data to the exchange file'; pl = 'Błąd podczas otwarcia czasowego pliku do przeniesienia danych do pliku wymiany';es_ES = 'Error al abrir el archivo temporal para trasladar los datos en el archivo de intercambio';es_CO = 'Error al abrir el archivo temporal para trasladar los datos en el archivo de intercambio';tr = 'Verilerin alışveriş dosyasına transfer edilmesi için geçici dosya açılırken bir hata oluştu';it = 'Errore durante l''apertura del file temporaneo per il trasferimento dati nel file di scambio';de = 'Fehler beim Öffnen einer temporären Datei zum Übertragen von Daten in eine Austauschdatei'"));
		Raise;
	EndTry;
	
	Return TempFile;
EndFunction

Procedure MoveDataFromTemporaryFiles(TempFileList)
	
	For Each TempFileName In TempFileList Do
		TempFile = ReadTextFromTemporaryFile(TempFileName);
		
		TempFileLine = TempFile.ReadLine();
		While TempFileLine <> Undefined Do
			WriteToFile(TempFileLine);	
			TempFileLine = TempFile.ReadLine();
		EndDo;
		
		TempFile.Close();
	EndDo;
	
	If SafeMode() <> False Then
		SetSafeModeDisabled(True);
	EndIf;
	
	For Each TempFileName In TempFileList Do
		DeleteFiles(TempFileName);
	EndDo;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsOfExchangeProtocolOperations

// Initializes the file to write data import/export events.
//
// Parameters:
//  No.
// 
Procedure InitializeKeepExchangeProtocol() Export
	
	If IsBlankString(ExchangeProtocolFileName) Then
		
		mDataProtocolFile = Undefined;
		CommentObjectProcessingFlag = OutputInfoMessagesInMessageWindow;		
		Return;
		
	Else	
		
		CommentObjectProcessingFlag = OutputInfoMessagesToProtocol OR OutputInfoMessagesInMessageWindow;		
		
	EndIf;
	
	mDataProtocolFile = New TextWriter(ExchangeProtocolFileName, TextEncoding.ANSI, , AppendDataToExchangeLog) ;
	
EndProcedure

Procedure InitializeKeepExchangeProtocolForHandlersExport()
	
	ExchangeProtocolTempFileName = GetNewUniqueTempFileName(ExchangeProtocolTempFileName);
	
	mDataProtocolFile = New TextWriter(ExchangeProtocolTempFileName, TextEncoding.ANSI);
	
	CommentObjectProcessingFlag = False;
	
EndProcedure

// Closes a data exchange protocol file. File is saved to the hard drive.
//
Procedure FinishKeepExchangeProtocol() Export 
	
	If mDataProtocolFile <> Undefined Then
		
		mDataProtocolFile.Close();
				
	EndIf;	
	
	mDataProtocolFile = Undefined;
	
EndProcedure

// Writes to a protocol or displays messages of the specified structure.
//
// Parameters:
//  Code - Number. Message code.
//  RecordStructure - Structure. Protocol record structure.
//  SetErrorsFlag - if true, then it is an error message. Setting ErrorFlag.
// 
Function WriteToExecutionProtocol(Code="", RecordStructure=Undefined, SetErrorFlag=True, 
	Level=0, Align=22, UnconditionalWriteToExchangeProtocol = False) Export

	Indent = "";
    For Cnt = 0 To Level-1 Do
		Indent = Indent + Chars.Tab;
	EndDo; 
	
	If TypeOf(Code) = deNumberType Then
		
		If deMessages = Undefined Then
			InitMessages();
		EndIf;
		
		Page = deMessages[Code];
		
	Else
		
		Page = String(Code);
		
	EndIf;

	Page = Indent + Page;
	
	If RecordStructure <> Undefined Then
		
		For each Field In RecordStructure Do
			
			Value = Field.Value;
			If Value = Undefined Then
				Continue;
			EndIf; 
			varKey = Field.Key;
			Page  = Page + Chars.LF + Indent + Chars.Tab + odSupplementString(Field.Key, Align) + " =  " + String(Value);
			
		EndDo;
		
	EndIf;
	
	ResultingStringToWrite = Chars.LF + Page;

	
	If SetErrorFlag Then
		
		SetErrorFlag(True);
		MessageToUser(ResultingStringToWrite);
		
	Else
		
		If DontOutputInfoMessagesToUser = False
			AND (UnconditionalWriteToExchangeProtocol OR OutputInfoMessagesInMessageWindow) Then
			
			MessageToUser(ResultingStringToWrite);
			
		EndIf;
		
	EndIf;
	
	If mDataProtocolFile <> Undefined Then
		
		If SetErrorFlag Then
			
			mDataProtocolFile.WriteLine(Chars.LF + "Error.");
			
		EndIf;
		
		If SetErrorFlag OR UnconditionalWriteToExchangeProtocol OR OutputInfoMessagesToProtocol Then
			
			mDataProtocolFile.WriteLine(ResultingStringToWrite);
		
		EndIf;		
		
	EndIf;
	
	Return Page;
		
EndFunction

// Writes error details to the exchange log for data clearing handler.
//
Function WriteDataClearingHandlerErrorInfo(MessageCode, ErrorRow, DataClearingRuleName, Object = "", HandlerName = "")
	
	WP                        = GetProtocolRecordStructure(MessageCode, ErrorRow);
	WP.DPR                    = DataClearingRuleName;
	
	If Object <> "" Then
		TypesDetails = New TypeDescription("String");
		RowObject  = TypesDetails.AdjustValue(Object);
		If Not IsBlankString(RowObject) Then
			WP.Object = RowObject + "  (" + TypeOf(Object) + ")";
		Else
			WP.Object = "" + TypeOf(Object) + "";
		EndIf;
	EndIf;
	
	If HandlerName <> "" Then
		WP.Handler             = HandlerName;
	EndIf;
	
	ErrorMessageString = WriteToExecutionProtocol(MessageCode, WP);
	
	If Not DebugModeFlag Then
		Raise ErrorMessageString;
	EndIf;	
	
EndFunction

// Registers the error of object conversion rule handler (export) in the execution protocol.
//
Function WriteInfoOnOCRHandlerExportError(MessageCode, ErrorRow, OCR, Source, HandlerName)
	
	WP                        = GetProtocolRecordStructure(MessageCode, ErrorRow);
	WP.OCR                    = OCR.Name + "  (" + OCR.Description + ")";
	
	TypesDetails = New TypeDescription("String");
	StringSource  = TypesDetails.AdjustValue(Source);
	If Not IsBlankString(StringSource) Then
		WP.Object = StringSource + "  (" + TypeOf(Source) + ")";
	Else
		WP.Object = "(" + TypeOf(Source) + ")";
	EndIf;
	
	WP.Handler = HandlerName;
	
	ErrorMessageString = WriteToExecutionProtocol(MessageCode, WP);
	
	If Not DebugModeFlag Then
		Raise ErrorMessageString;
	EndIf;
		
EndFunction

Function WriteErrorInfoDERHandlers(MessageCode, ErrorRow, RuleName, HandlerName, Object = Undefined)
	
	WP                        = GetProtocolRecordStructure(MessageCode, ErrorRow);
	WP.DER                    = RuleName;
	
	If Object <> Undefined Then
		TypesDetails = New TypeDescription("String");
		RowObject  = TypesDetails.AdjustValue(Object);
		If Not IsBlankString(RowObject) Then
			WP.Object = RowObject + "  (" + TypeOf(Object) + ")";
		Else
			WP.Object = "" + TypeOf(Object) + "";
		EndIf;
	EndIf;
	
	WP.Handler             = HandlerName;
	
	ErrorMessageString = WriteToExecutionProtocol(MessageCode, WP);
	
	If Not DebugModeFlag Then
		Raise ErrorMessageString;
	EndIf;
	
EndFunction

Function WriteErrorInfoConversionHandlers(MessageCode, ErrorRow, HandlerName)
	
	WP                        = GetProtocolRecordStructure(MessageCode, ErrorRow);
	WP.Handler             = HandlerName;
	ErrorMessageString = WriteToExecutionProtocol(MessageCode, WP);
	Return ErrorMessageString;
	
EndFunction

#EndRegion

#Region ExchangeRulesImportProcedures

// Imports the property group conversion rule.
//
// Parameters:
//  ExchangeRules - XMLReader object.
//  PropertiesTable - a value table containing PCR.
// 
Procedure ImportPGCR(ExchangeRules, PropertiesTable)

	If deAttribute(ExchangeRules, deBooleanType, "Disable") Then
		deSkip(ExchangeRules);
		Return;
	EndIf;

	
	NewRow               = PropertiesTable.Add();
	NewRow.IsFolder     = True;
	NewRow.GroupRules = mPropertyConversionRuleTable.Copy();

	
	// Default value

	NewRow.DoNotReplace               = False;
	NewRow.GetFromIncomingData = False;
	NewRow.SimplifiedPropertyExport = False;
	
	SearchFieldsString = "";	
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Source" Then
			NewRow.Source		= deAttribute(ExchangeRules, deStringType, "Name");
			NewRow.SourceKind	= deAttribute(ExchangeRules, deStringType, "Kind");
			NewRow.SourceType	= deAttribute(ExchangeRules, deStringType, "Type");
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "Destination" Then
			NewRow.Destination		= deAttribute(ExchangeRules, deStringType, "Name");
			NewRow.DestinationKind	= deAttribute(ExchangeRules, deStringType, "Kind");
			NewRow.DestinationType	= deAttribute(ExchangeRules, deStringType, "Type");
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "Property" Then
			ImportPCR(ExchangeRules, NewRow.GroupRules, , SearchFieldsString);

		ElsIf NodeName = "BeforeProcessExport" Then
			NewRow.BeforeProcessExport	= GetHandlerValueFromText(ExchangeRules);
			NewRow.HasBeforeProcessExportHandler = Not IsBlankString(NewRow.BeforeProcessExport);
			
		ElsIf NodeName = "AfterProcessExport" Then
			NewRow.AfterProcessExport	= GetHandlerValueFromText(ExchangeRules);
			NewRow.HasAfterProcessExportHandler = Not IsBlankString(NewRow.AfterProcessExport);
			
		ElsIf NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "DoNotReplace" Then
			NewRow.DoNotReplace = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "ConversionRuleCode" Then
			NewRow.ConversionRule = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "BeforeExport" Then
			NewRow.BeforeExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			NewRow.OnExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasOnExportHandler    = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			NewRow.AfterExport = GetHandlerValueFromText(ExchangeRules);
	        NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "ExportGroupToFile" Then
			NewRow.ExportGroupToFile = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "GetFromIncomingData" Then
			NewRow.GetFromIncomingData = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf (NodeName = "Group") AND (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	NewRow.SearchFieldsString = SearchFieldsString;
	
	NewRow.XMLNodeRequiredOnExport = NewRow.HasOnExportHandler OR NewRow.HasAfterExportHandler;
	
	NewRow.XMLNodeRequiredOnExportGroup = NewRow.HasAfterProcessExportHandler; 

EndProcedure

Procedure AddFieldToSearchString(SearchFieldsString, FieldName)
	
	If IsBlankString(FieldName) Then
		Return;
	EndIf;
	
	If NOT IsBlankString(SearchFieldsString) Then
		SearchFieldsString = SearchFieldsString + ",";
	EndIf;
	
	SearchFieldsString = SearchFieldsString + FieldName;
	
EndProcedure

// Imports the property group conversion rule.
//
// Parameters:
//  ExchangeRules - XMLReader object.
//  PropertiesTable - a value table containing PCR.
//  SearchTable - a value table containing PCR (synchronizing).
// 
Procedure ImportPCR(ExchangeRules, PropertiesTable, SearchTable = Undefined, SearchFieldsString = "")

	If deAttribute(ExchangeRules, deBooleanType, "Disable") Then
		deSkip(ExchangeRules);
		Return;
	EndIf;

	
	IsSearchField = deAttribute(ExchangeRules, deBooleanType, "Search");
	
	If IsSearchField 
		AND SearchTable <> Undefined Then
		
		NewRow = SearchTable.Add();
		
	Else
		
		NewRow = PropertiesTable.Add();
		
	EndIf;  

	
	// Default value

	NewRow.DoNotReplace               = False;
	NewRow.GetFromIncomingData = False;
	
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Source" Then
			NewRow.Source		= deAttribute(ExchangeRules, deStringType, "Name");
			NewRow.SourceKind	= deAttribute(ExchangeRules, deStringType, "Kind");
			NewRow.SourceType	= deAttribute(ExchangeRules, deStringType, "Type");
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "Destination" Then
			NewRow.Destination		= deAttribute(ExchangeRules, deStringType, "Name");
			NewRow.DestinationKind	= deAttribute(ExchangeRules, deStringType, "Kind");
			NewRow.DestinationType	= deAttribute(ExchangeRules, deStringType, "Type");
			
			If IsSearchField Then
				AddFieldToSearchString(SearchFieldsString, NewRow.Destination);
			EndIf;
			
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "DoNotReplace" Then
			NewRow.DoNotReplace = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "ConversionRuleCode" Then
			NewRow.ConversionRule = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "BeforeExport" Then
			NewRow.BeforeExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			NewRow.OnExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasOnExportHandler    = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			NewRow.AfterExport = GetHandlerValueFromText(ExchangeRules);
	        NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "GetFromIncomingData" Then
			NewRow.GetFromIncomingData = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "CastToLength" Then
			NewRow.CastToLength = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "ParameterForTransferName" Then
			NewRow.ParameterForTransferName = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "SearchByEqualDate" Then
			NewRow.SearchByEqualDate = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf (NodeName = "Property") AND (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	NewRow.SimplifiedPropertyExport = NOT NewRow.GetFromIncomingData
		AND NOT NewRow.HasBeforeExportHandler
		AND NOT NewRow.HasOnExportHandler
		AND NOT NewRow.HasAfterExportHandler
		AND IsBlankString(NewRow.ConversionRule)
		AND NewRow.SourceType = NewRow.DestinationType
		AND (NewRow.SourceType = "String" OR NewRow.SourceType = "Number" OR NewRow.SourceType = "Boolean" OR NewRow.SourceType = "Date");
		
	NewRow.XMLNodeRequiredOnExport = NewRow.HasOnExportHandler OR NewRow.HasAfterExportHandler;
	
EndProcedure

// Imports property conversion rules.
//
// Parameters:
//  ExchangeRules - XMLReader object.
//  PropertiesTable - a value table containing PCR.
//  SearchTable - a value table containing PCR (synchronizing).
// 
Procedure ImportProperties(ExchangeRules, PropertiesTable, SearchTable)

	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Property" Then
			ImportPCR(ExchangeRules, PropertiesTable, SearchTable);
		ElsIf NodeName = "Group" Then
			ImportPGCR(ExchangeRules, PropertiesTable);
		ElsIf (NodeName = "Properties") AND (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	PropertiesTable.Sort("Order");
	SearchTable.Sort("Order");
	
EndProcedure

// Imports the value conversion rule.
//
// Parameters:
//  ExchangeRules - XMLReader object.
//  Values       - a map of source object values to destination object presentation strings.
//                   
//  SourceType   - value of the Type type - source object type.
// 
Procedure ImportVCR(ExchangeRules, Values, SourceType)

	Source = "";
	Destination = "";
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Source" Then
			Source = deElementValue(ExchangeRules, deStringType);
		ElsIf NodeName = "Destination" Then
			Destination = deElementValue(ExchangeRules, deStringType);
		ElsIf (NodeName = "Value") AND (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	If ExchangeMode <> "Load" Then
		Values[deGetValueByString(Source, SourceType)] = Destination;
	EndIf;
	
EndProcedure

// Imports value conversion rules.
//
// Parameters:
//  ExchangeRules - XMLReader object.
//  Values       - a map of source object values to destination object presentation strings.
//                   
//  SourceType   - value of the Type type - source object type.
// 
Procedure LoadValues(ExchangeRules, Values, SourceType);

	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Value" Then
			ImportVCR(ExchangeRules, Values, SourceType);
		ElsIf (NodeName = "Values") AND (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
EndProcedure

// Clears OCR for exchange rule managers.
Procedure ClearManagersOCR()
	
	If Managers = Undefined Then
		Return;
	EndIf;
	
	For Each RuleManager In Managers Do
		RuleManager.Value.OCR = Undefined;
	EndDo;
	
EndProcedure

// Imports the object conversion rule.
//
// Parameters:
//  ExchangeRules - XMLReader object.
//  WriteXML - Object of the XMLWrite type  - rules to be saved into the exchange file and used on 
//                   data import.
// 
Procedure ImportConversionRule(ExchangeRules, XMLWriter)

	XMLWriter.WriteStartElement("Rule");

	NewRow = ConversionRulesTable.Add();

	
	// Default value
	
	NewRow.RememberExported = True;
	NewRow.DoNotReplace            = False;
	
	
	SearchInTSTable = New ValueTable;
	SearchInTSTable.Columns.Add("ItemName");
	SearchInTSTable.Columns.Add("TSSearchFields");
	
	NewRow.SearchInTabularSections = SearchInTSTable;
	
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
				
		If      NodeName = "Code" Then
			
			Value = deElementValue(ExchangeRules, deStringType);
			deWriteElement(XMLWriter, NodeName, Value);
			NewRow.Name = Value;
			
		ElsIf NodeName = "Description" Then
			
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "SynchronizeByID" Then
			
			NewRow.SynchronizeByID = deElementValue(ExchangeRules, deBooleanType);
			deWriteElement(XMLWriter, NodeName, NewRow.SynchronizeByID);
			
		ElsIf NodeName = "DoNotCreateIfNotFound" Then
			
			NewRow.DoNotCreateIfNotFound = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "DoNotExportPropertyObjectsByRefs" Then
			
			NewRow.DoNotExportPropertyObjectsByRefs = deElementValue(ExchangeRules, deBooleanType);
						
		ElsIf NodeName = "SearchBySearchFieldsIfNotFoundByID" Then
			
			NewRow.SearchBySearchFieldsIfNotFoundByID = deElementValue(ExchangeRules, deBooleanType);	
			deWriteElement(XMLWriter, NodeName, NewRow.SearchBySearchFieldsIfNotFoundByID);
			
		ElsIf NodeName = "OnMoveObjectByRefSetGIUDOnly" Then
			
			NewRow.OnMoveObjectByRefSetGIUDOnly = deElementValue(ExchangeRules, deBooleanType);	
			deWriteElement(XMLWriter, NodeName, NewRow.OnMoveObjectByRefSetGIUDOnly);
			
		ElsIf NodeName = "DoNotReplaceObjectCreatedInDestinationInfobase" Then
			// Has no effect on the exchange
			DontReplaceObjectCreatedInDestinationInfobase = deElementValue(ExchangeRules, deBooleanType);	
						
		ElsIf NodeName = "UseQuickSearchOnImport" Then
			
			NewRow.UseQuickSearchOnImport = deElementValue(ExchangeRules, deBooleanType);	
			
		ElsIf NodeName = "GenerateNewNumberOrCodeIfNotSet" Then
			
			NewRow.GenerateNewNumberOrCodeIfNotSet = deElementValue(ExchangeRules, deBooleanType);
			deWriteElement(XMLWriter, NodeName, NewRow.GenerateNewNumberOrCodeIfNotSet);
			
		ElsIf NodeName = "DoNotRememberExported" Then
			
			NewRow.RememberExported = Not deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "DoNotReplace" Then
			
			Value = deElementValue(ExchangeRules, deBooleanType);
			deWriteElement(XMLWriter, NodeName, Value);
			NewRow.DoNotReplace = Value;
			
		ElsIf NodeName = "ExchangeObjectsPriority" Then
			
			// Does not take part in the universal exchange.
			ExchangeObjectsPriority = deElementValue(ExchangeRules, deStringType);			
			
		ElsIf NodeName = "Destination" Then
			
			Value = deElementValue(ExchangeRules, deStringType);
			deWriteElement(XMLWriter, NodeName, Value);
			NewRow.Destination = Value;
			
		ElsIf NodeName = "Source" Then
			
			Value = deElementValue(ExchangeRules, deStringType);
			deWriteElement(XMLWriter, NodeName, Value);
			
			If ExchangeMode = "Load" Then
				
				NewRow.Source	= Value;
				
			Else
				
				If Not IsBlankString(Value) Then
					          
					NewRow.SourceType = Value;
					NewRow.Source	= Type(Value);
					
					Try
						
						Managers[NewRow.Source].OCR = NewRow;
						
					Except
						
						WriteErrorInfoToProtocol(11, ErrorDescription(), String(NewRow.Source));
						
					EndTry; 
					
				EndIf;
				
			EndIf;
			
		// Properties
		
		ElsIf NodeName = "Properties" Then
		
			NewRow.SearchProperties	= mPropertyConversionRuleTable.Copy();
			NewRow.Properties		= mPropertyConversionRuleTable.Copy();
			
			
			If NewRow.SynchronizeByID <> Undefined AND NewRow.SynchronizeByID Then
				
				SearchPropertyUUID = NewRow.SearchProperties.Add();
				SearchPropertyUUID.Name = "{UUID}";
				SearchPropertyUUID.Source = "{UUID}";
				SearchPropertyUUID.Destination = "{UUID}";
				
			EndIf;
			
			ImportProperties(ExchangeRules, NewRow.Properties, NewRow.SearchProperties);

			
		// Values
		
		ElsIf NodeName = "Values" Then
		
			LoadValues(ExchangeRules, NewRow.Values, NewRow.Source);
			
		// EVENT HANDLERS
		
		ElsIf NodeName = "BeforeExport" Then
		
			NewRow.BeforeExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			
			NewRow.OnExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasOnExportHandler    = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			
			NewRow.AfterExport = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "AfterExportToFile" Then
			
			NewRow.AfterExportToFile = GetHandlerValueFromText(ExchangeRules);
			NewRow.HasAfterExportToFileHandler  = Not IsBlankString(NewRow.AfterExportToFile);
						
		// For import
		
		ElsIf NodeName = "BeforeImport" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			
 			If ExchangeMode = "Load" Then
				
				NewRow.BeforeImport               = Value;
				NewRow.HasBeforeImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "OnImport" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Load" Then
				
				NewRow.OnImport               = Value;
				NewRow.HasOnImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf; 
			
		ElsIf NodeName = "AfterImport" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Load" Then
				
				NewRow.AfterImport               = Value;
				NewRow.HasAfterImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
	 		EndIf;
			
		ElsIf NodeName = "SearchFieldSequence" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			NewRow.HasSearchFieldSequenceHandler = Not IsBlankString(Value);
			
			If ExchangeMode = "Load" Then
				
				NewRow.SearchFieldSequence = Value;
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "SearchInTabularSections" Then
			
			Value = deElementValue(ExchangeRules, deStringType);
			
			For Number = 1 To StrLineCount(Value) Do
				
				CurrentRow = StrGetLine(Value, Number);
				
				SearchString = SplitWithSeparator(CurrentRow, ":");
				
				TableRow = SearchInTSTable.Add();
				TableRow.ItemName = CurrentRow;
				
				TableRow.TSSearchFields = SplitStringIntoSubstringsArray(SearchString);
				
			EndDo;
			
		ElsIf (NodeName = "Rule") AND (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;
	
	ResultingTSSearchString = "";
	
	// Sending details of tabular section search fields to the destination.
	For Each PropertyString In NewRow.Properties Do
		
		If Not PropertyString.IsFolder
			OR IsBlankString(PropertyString.SourceKind)
			OR IsBlankString(PropertyString.Destination) Then
			
			Continue;
			
		EndIf;
		
		If IsBlankString(PropertyString.SearchFieldsString) Then
			Continue;
		EndIf;
		
		ResultingTSSearchString = ResultingTSSearchString + Chars.LF + PropertyString.SourceKind + "." + PropertyString.Destination + ":" + PropertyString.SearchFieldsString;
		
	EndDo;
	
	ResultingTSSearchString = TrimAll(ResultingTSSearchString);
	
	If Not IsBlankString(ResultingTSSearchString) Then
		
		deWriteElement(XMLWriter, "SearchInTabularSections", ResultingTSSearchString);	
		
	EndIf;

	XMLWriter.WriteEndElement();

	
	// Quick access to OCR by name.
	
	Rules.Insert(NewRow.Name, NewRow);
	
EndProcedure
 
// Imports object conversion rules.
//
// Parameters:
//  ExchangeRules - XMLReader object.
//  WriteXML - Object of the XMLWrite type  - rules to be saved into the exchange file and used on 
//                   data import.
// 
Procedure ImportConversionRules(ExchangeRules, XMLWriter)

	ConversionRulesTable.Clear();
	ClearManagersOCR();
	
	XMLWriter.WriteStartElement("ObjectConversionRules");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Rule" Then
			
			ImportConversionRule(ExchangeRules, XMLWriter);
			
		ElsIf (NodeName = "ObjectConversionRules") AND (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
	ConversionRulesTable.Indexes.Add("Destination");
	
EndProcedure

// Imports the data clearing rule group according to the exchange rule format.
//
// Parameters:
//  NewRow    - a value tree row that describes a data clearing rules group.
// 
Procedure ImportDPRGroup(ExchangeRules, NewRow)

	NewRow.IsFolder = True;
	NewRow.Enable  = Number(Not deAttribute(ExchangeRules, deBooleanType, "Disable"));
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;
		
		If      NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, deStringType);

		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "Rule" Then
			ReversalString = NewRow.Rows.Add();
			ImportDPR(ExchangeRules, ReversalString);
			
		ElsIf (NodeName = "Group") AND (NodeType = deXMLNodeType_StartElement) Then
			ReversalString = NewRow.Rows.Add();
			ImportDPRGroup(ExchangeRules, ReversalString);
			
		ElsIf (NodeName = "Group") AND (NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	
	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports the data clearing rule according to the format of exchange rules.
//
// Parameters:
//  NewString    - a value tree row describing the data clearing rule.
// 
Procedure ImportDPR(ExchangeRules, NewRow)
	
	NewRow.Enable = Number(Not deAttribute(ExchangeRules, deBooleanType, "Disable"));
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Code" Then
			Value = deElementValue(ExchangeRules, deStringType);
			NewRow.Name = Value;

		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "DataFilterMethod" Then
			NewRow.DataFilterMethod = deElementValue(ExchangeRules, deStringType);

		ElsIf NodeName = "SelectionObject" Then
			SelectionObject = deElementValue(ExchangeRules, deStringType);
			If Not IsBlankString(SelectionObject) Then
				NewRow.SelectionObject = Type(SelectionObject);
			EndIf; 

		ElsIf NodeName = "DeleteForPeriod" Then
			NewRow.DeleteForPeriod = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Directly" Then
			NewRow.Directly = deElementValue(ExchangeRules, deBooleanType);

		
		// EVENT HANDLERS

		ElsIf NodeName = "BeforeProcessRule" Then
			NewRow.BeforeProcess = GetHandlerValueFromText(ExchangeRules);
			
		ElsIf NodeName = "AfterProcessRule" Then
			NewRow.AfterProcess = GetHandlerValueFromText(ExchangeRules);
		
		ElsIf NodeName = "BeforeDeleteObject" Then
			NewRow.BeforeDelete = GetHandlerValueFromText(ExchangeRules);

		// Exit
		ElsIf (NodeName = "Rule") AND (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
			
		EndIf;
		
	EndDo;

	
	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports data clearing rules.
//
// Parameters:
//  ExchangeRules - XMLReader object.
//  WriteXML - Object of the XMLWrite type  - rules to be saved into the exchange file and used on 
//                   data import.
// 
Procedure ImportClearingRules(ExchangeRules, XMLWriter)
	
 	CleanupRulesTable.Rows.Clear();
	VTRows = CleanupRulesTable.Rows;
	
	XMLWriter.WriteStartElement("DataClearingRules");

	While ExchangeRules.Read() Do
		
		NodeType = ExchangeRules.NodeType;
		
		If NodeType = deXMLNodeType_StartElement Then
			NodeName = ExchangeRules.LocalName;
			If ExchangeMode <> "Load" Then
				XMLWriter.WriteStartElement(ExchangeRules.Name);
				While ExchangeRules.ReadAttribute() Do
					XMLWriter.WriteAttribute(ExchangeRules.Name, ExchangeRules.Value);
				EndDo;
			Else
				If NodeName = "Rule" Then
					ReversalString = VTRows.Add();
					ImportDPR(ExchangeRules, ReversalString);
				ElsIf NodeName = "Group" Then
					ReversalString = VTRows.Add();
					ImportDPRGroup(ExchangeRules, ReversalString);
				EndIf;
			EndIf;
		ElsIf NodeType = deXMLNodeType_EndElement Then
			NodeName = ExchangeRules.LocalName;
			If NodeName = "DataClearingRules" Then
				Break;
			Else
				If ExchangeMode <> "Load" Then
					XMLWriter.WriteEndElement();
				EndIf;
			EndIf;
		ElsIf NodeType = deXMLNodeType_Text Then
			If ExchangeMode <> "Load" Then
				XMLWriter.WriteText(ExchangeRules.Value);
			EndIf;
		EndIf; 
	EndDo;

	VTRows.Sort("Order", True);
	
 	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports the algorithm according to the exchange rule format.
//
// Parameters:
//  ExchangeRules - XMLReader object.
//  WriteXML - Object of the XMLWrite type  - rules to be saved into the exchange file and used on 
//                   data import.
// 
Procedure ImportAlgorithm(ExchangeRules, XMLWriter)

	UsedOnImport = deAttribute(ExchangeRules, deBooleanType, "UsedOnImport");
	Name                     = deAttribute(ExchangeRules, deStringType, "Name");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Text" Then
			Text = GetHandlerValueFromText(ExchangeRules);
		ElsIf (NodeName = "Algorithm") AND (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		Else
			deSkip(ExchangeRules);
		EndIf;
		
	EndDo;

	
	If UsedOnImport Then
		If ExchangeMode = "Load" Then
			Algorithms.Insert(Name, Text);
		Else
			XMLWriter.WriteStartElement("Algorithm");
			SetAttribute(XMLWriter, "UsedOnImport", True);
			SetAttribute(XMLWriter, "Name",   Name);
			deWriteElement(XMLWriter, "Text", Text);
			XMLWriter.WriteEndElement();
		EndIf;
	Else
		If ExchangeMode <> "Load" Then
			Algorithms.Insert(Name, Text);
		EndIf;
	EndIf;
	
	
EndProcedure

// Imports algorithms according to the exchange rule format.
//
// Parameters:
//  ExchangeRules - XMLReader object.
//  WriteXML - Object of the XMLWrite type  - rules to be saved into the exchange file and used on 
//                   data import.
// 
Procedure ImportAlgorithms(ExchangeRules, XMLWriter)

	Algorithms.Clear();

	XMLWriter.WriteStartElement("Algorithms");
	
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		If      NodeName = "Algorithm" Then
			ImportAlgorithm(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "Algorithms") AND (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports the query according to the exchange rule format.
//
// Parameters:
//  ExchangeRules - XMLReader object.
//  WriteXML - Object of the XMLWrite type  - rules to be saved into the exchange file and used on 
//                   data import.
// 
Procedure ImportQuery(ExchangeRules, XMLWriter)

	UsedOnImport = deAttribute(ExchangeRules, deBooleanType, "UsedOnImport");
	Name                     = deAttribute(ExchangeRules, deStringType, "Name");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Text" Then
			Text = GetHandlerValueFromText(ExchangeRules);
		ElsIf (NodeName = "Query") AND (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		Else
			deSkip(ExchangeRules);
		EndIf;
		
	EndDo;

	If UsedOnImport Then
		If ExchangeMode = "Load" Then
			Query	= New Query(Text);
			Queries.Insert(Name, Query);
		Else
			XMLWriter.WriteStartElement("Query");
			SetAttribute(XMLWriter, "UsedOnImport", True);
			SetAttribute(XMLWriter, "Name",   Name);
			deWriteElement(XMLWriter, "Text", Text);
			XMLWriter.WriteEndElement();
		EndIf;
	Else
		If ExchangeMode <> "Load" Then
			Query	= New Query(Text);
			Queries.Insert(Name, Query);
		EndIf;
	EndIf;
	
EndProcedure

// Imports queries according to the exchange rule format.
//
// Parameters:
//  ExchangeRules - XMLReader object.
//  WriteXML - Object of the XMLWrite type  - rules to be saved into the exchange file and used on 
//                   data import.
// 
Procedure ImportQueries(ExchangeRules, XMLWriter)

	Queries.Clear();

	XMLWriter.WriteStartElement("Queries");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Query" Then
			ImportQuery(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "Queries") AND (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports parameters according to the exchange rule format.
//
// Parameters:
//  ExchangeRules - XMLReader object.
// 
Procedure ImportParameters(ExchangeRules, XMLWriter)

	Parameters.Clear();
	EventsAfterParameterImport.Clear();
	ParameterSetupTable.Clear();
	
	XMLWriter.WriteStartElement("Parameters");
	
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;

		If NodeName = "Parameter" AND NodeType = deXMLNodeType_StartElement Then
			
			// Importing by the 2.01 rule version.
			Name                     = deAttribute(ExchangeRules, deStringType, "Name");
			Description            = deAttribute(ExchangeRules, deStringType, "Description");
			SetInDialog   = deAttribute(ExchangeRules, deBooleanType, "SetInDialog");
			ValueTypeString      = deAttribute(ExchangeRules, deStringType, "ValueType");
			UsedOnImport = deAttribute(ExchangeRules, deBooleanType, "UsedOnImport");
			PassParameterOnExport = deAttribute(ExchangeRules, deBooleanType, "PassParameterOnExport");
			ConversionRule = deAttribute(ExchangeRules, deStringType, "ConversionRule");
			AfterParameterImportAlgorithm = deAttribute(ExchangeRules, deStringType, "AfterImportParameter");
			
			If Not IsBlankString(AfterParameterImportAlgorithm) Then
				
				EventsAfterParameterImport.Insert(Name, AfterParameterImportAlgorithm);
				
			EndIf;
			
			If ExchangeMode = "Load" AND NOT UsedOnImport Then
				Continue;
			EndIf;
			
			// Determining value types and setting initial values.
			If Not IsBlankString(ValueTypeString) Then
				
				Try
					DataValueType = Type(ValueTypeString);
					TypeDefined = TRUE;
				Except
					TypeDefined = FALSE;
				EndTry;
				
			Else
				
				TypeDefined = FALSE;
				
			EndIf;
			
			If TypeDefined Then
				ParameterValue = deGetEmptyValue(DataValueType);
				Parameters.Insert(Name, ParameterValue);
			Else
				ParameterValue = "";
				Parameters.Insert(Name);
			EndIf;
						
			If SetInDialog = TRUE Then
				
				TableRow              = ParameterSetupTable.Add();
				TableRow.Description = Description;
				TableRow.Name          = Name;
				TableRow.Value = ParameterValue;				
				TableRow.PassParameterOnExport = PassParameterOnExport;
				TableRow.ConversionRule = ConversionRule;
				
			EndIf;
			
			If UsedOnImport
				AND ExchangeMode = "DataExported" Then
				
				XMLWriter.WriteStartElement("Parameter");
				SetAttribute(XMLWriter, "Name",   Name);
				SetAttribute(XMLWriter, "Description", Description);
					
				If NOT IsBlankString(AfterParameterImportAlgorithm) Then
					SetAttribute(XMLWriter, "AfterImportParameter", XMLString(AfterParameterImportAlgorithm));
				EndIf;
				
				XMLWriter.WriteEndElement();
				
			EndIf;

		ElsIf (NodeType = deXMLNodeType_Text) Then
			
			// Importing from the string to provide 2.0 compatibility.
			ParameterString = ExchangeRules.Value;
			For each Par In ArrayFromString(ParameterString) Do
				Parameters.Insert(Par);
			EndDo;
			
		ElsIf (NodeName = "Parameters") AND (NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();

EndProcedure

// Imports the data processor according to the exchange rule format.
//
// Parameters:
//  ExchangeRules - XMLReader object.
//  WriteXML - Object of the XMLWrite type  - rules to be saved into the exchange file and used on 
//                   data import.
// 
Procedure ImportDataProcessor(ExchangeRules, XMLWriter)

	Name                     = deAttribute(ExchangeRules, deStringType, "Name");
	Description            = deAttribute(ExchangeRules, deStringType, "Description");
	IsSetupDataProcessor   = deAttribute(ExchangeRules, deBooleanType, "IsSetupDataProcessor");
	
	UsedOnExport = deAttribute(ExchangeRules, deBooleanType, "UsedOnExport");
	UsedOnImport = deAttribute(ExchangeRules, deBooleanType, "UsedOnImport");

	ParameterString        = deAttribute(ExchangeRules, deStringType, "Parameters");
	
	DataProcessorStorage      = deElementValue(ExchangeRules, deValueStorageType);

	AdditionalDataProcessorParameters.Insert(Name, ArrayFromString(ParameterString));
	
	
	If UsedOnImport Then
		If ExchangeMode = "Load" Then
			
		Else
			XMLWriter.WriteStartElement("DataProcessor");
			SetAttribute(XMLWriter, "UsedOnImport", True);
			SetAttribute(XMLWriter, "Name",                     Name);
			SetAttribute(XMLWriter, "Description",            Description);
			SetAttribute(XMLWriter, "IsSetupDataProcessor",   IsSetupDataProcessor);
			XMLWriter.WriteText(XMLString(DataProcessorStorage));
			XMLWriter.WriteEndElement();
		EndIf;
	EndIf;
	
	If IsSetupDataProcessor Then
		If (ExchangeMode = "Load") AND UsedOnImport Then
			ImportSettingsDataProcessors.Add(Name, Description, , );
			
		ElsIf (ExchangeMode = "DataExported") AND UsedOnExport Then
			ExportSettingsDataProcessors.Add(Name, Description, , );
			
		EndIf; 
	EndIf; 
	
EndProcedure

// Imports external data processors according to the exchange rule format.
//
// Parameters:
//  ExchangeRules - XMLReader object.
//  WriteXML - Object of the XMLWrite type  - rules to be saved into the exchange file and used on 
//                   data import.
// 
Procedure ImportDataProcessors(ExchangeRules, XMLWriter)

	AdditionalDataProcessors.Clear();
	AdditionalDataProcessorParameters.Clear();
	
	ExportSettingsDataProcessors.Clear();
	ImportSettingsDataProcessors.Clear();

	XMLWriter.WriteStartElement("DataProcessors");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "DataProcessor" Then
			ImportDataProcessor(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "DataProcessors") AND (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports the data exporting rule group according to the exchange rule format.
//
// Parameters:
//  ExchangeRules - XMLReader object.
//  NewRow    - a value tree row describing an export rules table group.
// 
Procedure ImportDERGroup(ExchangeRules, NewRow)

	NewRow.IsFolder = True;
	NewRow.Enable  = Number(Not deAttribute(ExchangeRules, deBooleanType, "Disable"));
	
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;
		If      NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, deStringType);

		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "Rule" Then
			ReversalString = NewRow.Rows.Add();
			ImportDER(ExchangeRules, ReversalString);
			
		ElsIf (NodeName = "Group") AND (NodeType = deXMLNodeType_StartElement) Then
			ReversalString = NewRow.Rows.Add();
			ImportDERGroup(ExchangeRules, ReversalString);
					
		ElsIf (NodeName = "Group") AND (NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	
	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports the data export rule according to the exchange rule format.
//
// Parameters:
//  ExchangeRules - XMLReader object.
//  NewString    - a value tree row describing the data export rule.
// 
Procedure ImportDER(ExchangeRules, NewRow)

	NewRow.Enable = Number(Not deAttribute(ExchangeRules, deBooleanType, "Disable"));
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		If      NodeName = "Code" Then
			NewRow.Name = deElementValue(ExchangeRules, deStringType);

		ElsIf NodeName = "Description" Then
			NewRow.Description = deElementValue(ExchangeRules, deStringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deElementValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "DataFilterMethod" Then
			NewRow.DataFilterMethod = deElementValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "SelectExportDataInSingleQuery" Then
			NewRow.SelectExportDataInSingleQuery = deElementValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "DoNotExportObjectsCreatedInDestinationInfobase" Then
			// Skipping the parameter during the data exchange.
			DontExportObjectsCreatedInDestinationInfobase = deElementValue(ExchangeRules, deBooleanType);

		ElsIf NodeName = "SelectionObject" Then
			SelectionObject = deElementValue(ExchangeRules, deStringType);
			If Not IsBlankString(SelectionObject) Then
				NewRow.SelectionObject = Type(SelectionObject);
			EndIf;
			// For filtering using the query builder.
			If StrFind(SelectionObject, "Ref.") Then
				NewRow.ObjectForQueryName = StrReplace(SelectionObject, "Ref.", ".");
			Else
				NewRow.ObjectNameForRegisterQuery = StrReplace(SelectionObject, "Record.", ".");
			EndIf;

		ElsIf NodeName = "ConversionRuleCode" Then
			NewRow.ConversionRule = deElementValue(ExchangeRules, deStringType);

		// EVENT HANDLERS

		ElsIf NodeName = "BeforeProcessRule" Then
			NewRow.BeforeProcess = GetHandlerValueFromText(ExchangeRules);
			
		ElsIf NodeName = "AfterProcessRule" Then
			NewRow.AfterProcess = GetHandlerValueFromText(ExchangeRules);
		
		ElsIf NodeName = "BeforeExportObject" Then
			NewRow.BeforeExport = GetHandlerValueFromText(ExchangeRules);

		ElsIf NodeName = "AfterExportObject" Then
			NewRow.AfterExport = GetHandlerValueFromText(ExchangeRules);
        		
		ElsIf (NodeName = "Rule") AND (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports data export rules according to the exchange rule format.
//
// Parameters:
//  ExchangeRules - XMLReader object.
// 
Procedure ImportExportRules(ExchangeRules)

	ExportRuleTable.Rows.Clear();

	VTRows = ExportRuleTable.Rows;
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Rule" Then
			
			ReversalString = VTRows.Add();
			ImportDER(ExchangeRules, ReversalString);
			
		ElsIf NodeName = "Group" Then
			
			ReversalString = VTRows.Add();
			ImportDERGroup(ExchangeRules, ReversalString);
			
		ElsIf (NodeName = "DataExportRules") AND (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;

	VTRows.Sort("Order", True);

EndProcedure

#EndRegion

#Region ProceduresOfExportHandlersAndProceduresToTXTFileFromExchangeRules

// Exports event handlers and algorithms to the temporary text file (user temporary directory).
// 
// Generates debug module with handlers and algorithms and all necessary global variables, common 
// function wrappers, and comments.
//
// Parameters:
//  Cancel - a flag showing that debug module creation is canceled. Is set in case of exchange rule 
//          reading failure.
//
Procedure ExportEventHandlers(Cancel) Export
	
	InitializeKeepExchangeProtocolForHandlersExport();
	
	DataProcessingMode = mDataProcessingModes.EventHandlerExport;
	
	ErrorFlag = False;
	
	ImportExchangeRulesForHandlerExport();
	
	If ErrorFlag Then
		Cancel = True;
		Return;
	EndIf; 
	
	SupplementRulesWithHandlerInterfaces(Conversion, ConversionRulesTable, ExportRuleTable, CleanupRulesTable);
	
	If AlgorithmDebugMode = mAlgorithmDebugModes.CodeIntegration Then
		
		GetFullAlgorithmScriptRecursively();
		
	EndIf;
	
	EventHandlersTempFileName = GetNewUniqueTempFileName(EventHandlersTempFileName);
	
	Result = New TextWriter(EventHandlersTempFileName, TextEncoding.ANSI);
	
	mCommonProceduresFunctionsTemplate = GetTemplate("CommonProceduresFunctions");
	
	// Adding comments.
	AddCommentToStream(Result, "Header");
	AddCommentToStream(Result, "DataProcessorVariables");
	
	// Adding the service script.
	AddServiceCodeToStream(Result, "DataProcessorVariables");
	
	// Exporting global handlers.
	ExportConversionHandlers(Result);
	
	// Exporting DER.
	AddCommentToStream(Result, "DER", ExportRuleTable.Rows.Count() <> 0);
	ExportDataExportRuleHandlers(Result, ExportRuleTable.Rows);
	
	// Exporting DPR.
	AddCommentToStream(Result, "DPR", CleanupRulesTable.Rows.Count() <> 0);
	ExportDataClearingRuleHandlers(Result, CleanupRulesTable.Rows);
	
	// Exporting OCR, PCR, PGCR.
	ExportConversionRuleHandlers(Result);
	
	If AlgorithmDebugMode = mAlgorithmDebugModes.ProceduralCall Then
		
		// Exporting algorithms with standard (default) parameters.
		ExportAlgorithms(Result);
		
	EndIf; 
	
	// Adding comments
	AddCommentToStream(Result, "Warning");
	AddCommentToStream(Result, "CommonProceduresFunctions");
		
	// Adding common procedures and functions to the stream.
	AddServiceCodeToStream(Result, "CommonProceduresFunctions");

	// Adding the external data processor constructor.
	ExportExternalDataProcessorConstructor(Result);
	
	// Adding the destructor
	AddServiceCodeToStream(Result, "Destructor");
	
	Result.Close();
	
	FinishKeepExchangeProtocol();
	
	If IsInteractiveMode Then
		
		If ErrorFlag Then
			
			MessageToUser(NStr("ru = 'При выгрузке обработчиков были обнаружены ошибки.'; en = 'Error exporting handlers.'; pl = 'Wystąpiły błędy podczas eksportowania procedur obsługi.';es_ES = 'Errores ocurridos al exportar los manipuladores.';es_CO = 'Errores ocurridos al exportar los manipuladores.';tr = 'İşleyicileri dışa aktarırken hatalar oluştu.';it = 'Durante l''upload di elaboratori sono stati rilevati gli errori.';de = 'Beim Exportieren von Handlern sind Fehler aufgetreten.'"));
			
		Else
			
			MessageToUser(NStr("ru = 'Обработчики успешно выгружены.'; en = 'Handlers has been successfully exported.'; pl = 'Procedury obsługi zostały pomyślnie wyeksportowane.';es_ES = 'Manipuladores se han exportado con éxito.';es_CO = 'Manipuladores se han exportado con éxito.';tr = 'İşleyiciler başarıyla dışa aktarıldı.';it = 'Elaboratori importati con successo.';de = 'Handler werden erfolgreich exportiert.'"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Clears variables with structure of exchange rules.
//
// Parameters:
//  No.
//  
Procedure ClearExchangeRules()
	
	ExportRuleTable.Rows.Clear();
	CleanupRulesTable.Rows.Clear();
	ConversionRulesTable.Clear();
	Algorithms.Clear();
	Queries.Clear();

	// Data processors
	AdditionalDataProcessors.Clear();
	AdditionalDataProcessorParameters.Clear();
	ExportSettingsDataProcessors.Clear();
	ImportSettingsDataProcessors.Clear();

EndProcedure  

// Exports exchange rules from rule file or data file.
//
// Parameters:
//  No.
//  
Procedure ImportExchangeRulesForHandlerExport()
	
	ClearExchangeRules();
	
	If ReadEventHandlersFromExchangeRulesFile Then
		
		ExchangeMode = ""; // Exporting data.

		ImportExchangeRules();
		
		mExchangeRulesReadOnImport = False;
		
		InitializeInitialParameterValues();
		
	Else // Data file
		
		ExchangeMode = "Load"; 
		
		If IsBlankString(ExchangeFileName) Then
			WriteToExecutionProtocol(15);
			Return;
		EndIf;
		
		OpenImportFile(True);
		
		// If the flag is set, the data processor requires to reimport rules on data export start.
		// 
		mExchangeRulesReadOnImport = True;

	EndIf;
	
EndProcedure

// Exports global conversion handlers to a text file.
// When exporting handlers from the file with data, the content of the Conversion_AfterParameterImport handler
// is not exported, because the handler code is not in the exchange rule node, but in a separate node.
// During the handler export from the rule file, this algorithm exported as all others.
//
// Parameters:
//  Result - TextWriter object - to output handlers to a text file.
//  
Procedure ExportConversionHandlers(Result)
	
	AddCommentToStream(Result, "Conversion");
	
	For Each Item In HandlerNames.Conversion Do
		
		AddConversionHandlerToStream(Result, Item.Key);
		
	EndDo; 
	
EndProcedure 

// Exports handlers of data export rules to the text file.
//
// Parameters:
//  Result    - TextWriter object - to output handlers to a text file.
//  TreeRows - ValueTreeRowCollection object, contains data export rule of this value tree level.
// 
Procedure ExportDataExportRuleHandlers(Result, TreeRows)
	
	For Each Rule In TreeRows Do
		
		If Rule.IsFolder Then
			
			ExportDataExportRuleHandlers(Result, Rule.Rows); 
			
		Else
			
			For Each Item In HandlerNames.DER Do
				
				AddHandlerToStream(Result, Rule, "DER", Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

// Exports handlers of data clearing rules to the text file.
//
// Parameters:
//  Result    - TextWriter object - to output handlers to a text file.
//  TreeRows - ValueTreeRowCollection object, contains data clearing rules of this value tree level.
// 
Procedure ExportDataClearingRuleHandlers(Result, TreeRows)
	
	For Each Rule In TreeRows Do
		
		If Rule.IsFolder Then
			
			ExportDataClearingRuleHandlers(Result, Rule.Rows); 
			
		Else
			
			For Each Item In HandlerNames.DPR Do
				
				AddHandlerToStream(Result, Rule, "DPR", Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

// Exports the following conversion rule handlers into a text file: OCR, PCR, and PGCR.
//
// Parameters:
//  Result    - TextWriter object - to output handlers to a text file.
// 
Procedure ExportConversionRuleHandlers(Result)
	
	OutputComment = ConversionRulesTable.Count() <> 0;
	
	// Exporting OCR.
	AddCommentToStream(Result, "OCR", OutputComment);
	
	For Each OCR In ConversionRulesTable Do
		
		For Each Item In HandlerNames.OCR Do
			
			AddOCRHandlerToStream(Result, OCR, Item.Key);
			
		EndDo; 
		
	EndDo; 
	
	// Exporting PCR and PGCR.
	AddCommentToStream(Result, "PCR", OutputComment);
	
	For Each OCR In ConversionRulesTable Do
		
		ExportPropertyConversionRuleHandlers(Result, OCR.SearchProperties);
		ExportPropertyConversionRuleHandlers(Result, OCR.Properties);
		
	EndDo; 
	
EndProcedure 

// Exports handlers of property conversion rules to a text file.
//
// Parameters:
//  Result - TextWriter object - to output handlers to a text file.
//  PCR       - ValueTable - contains rules of conversion of properties or object property group.
// 
Procedure ExportPropertyConversionRuleHandlers(Result, PCR)
	
	For Each Rule In PCR Do
		
		If Rule.IsFolder Then // PGCR
			
			For Each Item In HandlerNames.PGCR Do
				
				AddOCRHandlerToStream(Result, Rule, Item.Key);
				
			EndDo; 

			ExportPropertyConversionRuleHandlers(Result, Rule.GroupRules);
			
		Else
			
			For Each Item In HandlerNames.PCR Do
				
				AddOCRHandlerToStream(Result, Rule, Item.Key);
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Exports algorithms to the text file.
//
// Parameters:
//  Result - TextWriter object - to output algorithms to a text file.
// 
Procedure ExportAlgorithms(Result)
	
	// Commenting the Algorithms block.
	AddCommentToStream(Result, "Algorithms", Algorithms.Count() <> 0);
	
	For Each Algorithm In Algorithms Do
		
		AddAlgorithmToSteam(Result, Algorithm);
		
	EndDo; 
	
EndProcedure  

// Exports the constructor of external data processor to the text file.
//  If algorithm debug mode is "debug algorithms as procedures", then the constructor receives structure
//  "Algorithms".
//  Structure item key is algorithm name and its value is the interface of procedure call that contains algorithm code.
//
// Parameters:
//  Result    - TextWriter object - to output handlers to a text file.
// 
Procedure ExportExternalDataProcessorConstructor(Result)
	
	// Displaying the comment
	AddCommentToStream(Result, "Designer");
	
	ProcedureBody = GetServiceCode("Constructor_ProcedureBody");

	If AlgorithmDebugMode = mAlgorithmDebugModes.ProceduralCall Then
		
		ProcedureBody = ProcedureBody + GetServiceCode("Constructor_ProcedureBody_ProceduralAlgorithmCall");
		
		// Adding algorithm calls to the constructor body.
		For Each Algorithm In Algorithms Do
			
			AlgorithmKey = TrimAll(Algorithm.Key);
			
			AlgorithmInterface = GetAlgorithmInterface(AlgorithmKey) + ";";
			
			AlgorithmInterface = StrReplace(StrReplace(AlgorithmInterface, Chars.LF, " ")," ","");
			
			ProcedureBody = ProcedureBody + Chars.LF 
			   + "Algorithms.Insert(""" + AlgorithmKey + """, """ + AlgorithmInterface + """);";

			
		EndDo; 
		
	ElsIf AlgorithmDebugMode = mAlgorithmDebugModes.CodeIntegration Then
		
		ProcedureBody = ProcedureBody + GetServiceCode("Constructor_ProcedureBody_AlgorithmCodeIntegration");
		
	ElsIf AlgorithmDebugMode = mAlgorithmDebugModes.DontUse Then
		
		ProcedureBody = ProcedureBody + GetServiceCode("Constructor_ProcedureBody_DoNotUseAlgorithmDebug");
		
	EndIf; 
	
	ExternalDataProcessorProcedureInterface = "Procedure " + GetExternalDataProcessorProcedureInterface("Designer") + " Export";
	
	AddFullHandlerToStream(Result, ExternalDataProcessorProcedureInterface, ProcedureBody);
	
EndProcedure  

// Adds to the Result object an OCR, PCR, or PGCR handler.
//
// Parameters:
//  Result      - TextWriter object - to output a handler to a text file.
//  Rule        - value table row that contains object conversion rules.
//  HandlerName - String - a handler name.
//  
Procedure AddOCRHandlerToStream(Result, Rule, HandlerName)
	
	If Not Rule["HasHandler" + HandlerName] Then
		Return;
	EndIf; 
	
	HandlerInterface = "Procedure " + Rule["HandlerInterface" + HandlerName] + " Export";
	
	AddFullHandlerToStream(Result, HandlerInterface, Rule[HandlerName]);
	
EndProcedure  

// Adds an algorithm code to the Result object.
//
// Parameters:
//  Result - TextWriter object - to output a handler to a text file.
//  Algorithm  - structure item - an algorithm for the export.
//  
Procedure AddAlgorithmToSteam(Result, Algorithm)
	
	AlgorithmInterface = "Procedure " + GetAlgorithmInterface(Algorithm.Key);

	AddFullHandlerToStream(Result, AlgorithmInterface, Algorithm.Value);
	
EndProcedure  

// Adds to the Result object a DER or DPR handler.
//
// Parameters:
//  Result      - TextWriter object - to output a handler to a text file.
//  Rule        - a value tree row with rules.
//  HandlerPrefix - String - a handler prefix: DER or DPR.
//  HandlerName - String - a handler name.
//  
Procedure AddHandlerToStream(Result, Rule, HandlerPrefix, HandlerName)
	
	If IsBlankString(Rule[HandlerName]) Then
		Return;
	EndIf;
	
	HandlerInterface = "Procedure " + Rule["HandlerInterface" + HandlerName] + " Export";
	
	AddFullHandlerToStream(Result, HandlerInterface, Rule[HandlerName]);
	
EndProcedure  

// Adds a global conversion handler to the Result object.
//
// Parameters:
//  Result      - TextWriter object - to output a handler to a text file.
//  HandlerName - String - a handler name.
//  
Procedure AddConversionHandlerToStream(Result, HandlerName)
	
	HandlerAlgorithm = "";
	
	If Conversion.Property(HandlerName, HandlerAlgorithm) AND Not IsBlankString(HandlerAlgorithm) Then
		
		HandlerInterface = "Procedure " + Conversion["HandlerInterface" + HandlerName] + " Export";
		
		AddFullHandlerToStream(Result, HandlerInterface, HandlerAlgorithm);
		
	EndIf;
	
EndProcedure  

// Adds a procedure with a handler or algorithm code to the Result object.
//
// Parameters:
//  Result            - TextWriter object - to output procedure to a text file.
//  HandlerInterface - String - full handler interface description:
//                         procedure name, parameters, "Export" keyword.
//  Handler           - String - a body of handler or algorithm.
//
Procedure AddFullHandlerToStream(Result, HandlerInterface, Handler)
	
	PrefixString = Chars.Tab;
	
	Result.WriteLine("");
	
	Result.WriteLine(HandlerInterface);
	
	Result.WriteLine("");
	
	For Index = 1 To StrLineCount(Handler) Do
		
		HandlerRow = StrGetLine(Handler, Index);
		
		// In the "Script integration" algorithm debugging mode the algorithm script is inserted directly 
		// into the handler script. The algorithm script is inserted instead of this algorithm call.
		// Algorithms can be nested. The algorithm scripts support nested algorithms.
		If AlgorithmDebugMode = mAlgorithmDebugModes.CodeIntegration Then
			
			HandlerAlgorithms = GetHandlerAlgorithms(HandlerRow);
			
			If HandlerAlgorithms.Count() <> 0 Then // There are algorithm calls in the line.
				
				// Receiving the initial algorithm code offset relative to the current handler code.
				PrefixStringForInlineCode = GetInlineAlgorithmPrefix(HandlerRow, PrefixString);
				
				For Each Algorithm In HandlerAlgorithms Do
					
					AlgorithmHandler = IntegratedAlgorithms[Algorithm];
					
					For AlgorithmRowIndex = 1 To StrLineCount(AlgorithmHandler) Do
						
						Result.WriteLine(PrefixStringForInlineCode + StrGetLine(AlgorithmHandler, AlgorithmRowIndex));
						
					EndDo;	
					
				EndDo;
				
			EndIf;
		EndIf;

		Result.WriteLine(PrefixString + HandlerRow);
		
	EndDo;
	
	Result.WriteLine("");
	Result.WriteLine("EndProcedure");
	
EndProcedure

// Adds a comment to the Result object.
//
// Parameters:
//  Result          - TextWriter object - to output comment to a text file.
//  AreaName         - String - a name of the mCommonProceduresFunction text template area.
//                       that contains the required comment.
//  OutputComment - Boolean - shows whether it is necessary to display a comment.
//
Procedure AddCommentToStream(Result, AreaName, OutputComment = True)
	
	If Not OutputComment Then
		Return;
	EndIf; 
	
	// Getting handler comments by the area name.
	CurrentArea = mCommonProceduresFunctionsTemplate.GetArea(AreaName+"_Comment");
	
	CommentFromTemplate = TrimAll(GetTextByAreaWithoutAreaTitle(CurrentArea));
	
	// Excluding last end of line character.
	CommentFromTemplate = Mid(CommentFromTemplate, 1, StrLen(CommentFromTemplate));
	
	Result.WriteLine(Chars.LF + Chars.LF + CommentFromTemplate);
	
EndProcedure  

// Adds service code to the Result object: parameters, common procedures and functions, and destructor of external data processor.
//
// Parameters:
//  Result          - TextWriter object - to output service code to a text file.
//  AreaName         - String - a name of the mCommonProceduresFunction text template area.
//                       that contains the required service code.
//
Procedure AddServiceCodeToStream(Result, AreaName)
	
	// Getting the area text
	CurrentArea = mCommonProceduresFunctionsTemplate.GetArea(AreaName);
	
	Text = TrimAll(GetTextByAreaWithoutAreaTitle(CurrentArea));
	
	Text = Mid(Text, 1, StrLen(Text)); // Excluding last end of line character.
	
	Result.WriteLine(Chars.LF + Chars.LF + Text);
	
EndProcedure  

// Retrieves the service code from the specified mCommonProceduresFunctionsTemplate template area.
//
// Parameters:
//  AreaName - String - a name of the mCommonProceduresFunction text template area.
//  
// Returns:
//  Text from the template.
//
Function GetServiceCode(AreaName)
	
	// Getting the area text
	CurrentArea = mCommonProceduresFunctionsTemplate.GetArea(AreaName);
	
	Return GetTextByAreaWithoutAreaTitle(CurrentArea);
EndFunction

#EndRegion

#Region ProceduresAndFUnctionsOfGetFullAlgorithmsCodeConsideringTheyCanBeNested

// Generates the full code of algorithms considering their nesting.
//
// Parameters:
//  No.
//  
Procedure GetFullAlgorithmScriptRecursively()
	
	// Filling the structure of integrated algorithms.
	IntegratedAlgorithms = New Structure;
	
	For Each Algorithm In Algorithms Do
		
		IntegratedAlgorithms.Insert(Algorithm.Key, ReplaceAlgorithmCallsWithTheirHandlerScript(Algorithm.Value, Algorithm.Key, New Array));
		
	EndDo; 
	
EndProcedure 

// Adds the NewHandler string as a comment to algorithm code insertion.
//
// Parameters:
//  NewHandler - String - a result string that contains full algorithm scripts taking algorithm nesting into account.
//  AlgorithmName    - String - an algorithm name.
//  PrefixString  - String - sets the initial offset of the comment to be inserted.
//  Header       - String - comment description: "{ALGORITHM START}", "{ALGORITHM END}"...
//
Procedure WriteAlgorithmBlockTitle(NewHandler, AlgorithmName, PrefixString, Header) 
	
	AlgorithmTitle = "//============================ " + Header + " """ + AlgorithmName + """ ============================";
	
	NewHandler = NewHandler + Chars.LF;
	NewHandler = NewHandler + Chars.LF + PrefixString + AlgorithmTitle;
	NewHandler = NewHandler + Chars.LF;
	
EndProcedure  

// Complements the HandlerAlgorithms array with names of algorithms that are called  from the passed 
// procedure of the HandlerLine handler line.
//
// Parameters:
//  HandlerLine - String - a handler line or algorithm line where algorithm calls are searched.
//  HandlerAlgorithms - Array - contains algorithm names that are called from the specified handler.
//  
Procedure GetHandlerStringAlgorithms(HandlerRow, HandlerAlgorithms)
	
	HandlerRow = Upper(HandlerRow);
	
	SearchTemplate = "ALGORITHMS.";
	
	PatternStringLength = StrLen(SearchTemplate);
	
	InitialChar = StrFind(HandlerRow, SearchTemplate);
	
	If InitialChar = 0 Then
		// There are no algorithms or all algorithms from this line have been taken into account.
		Return; 
	EndIf;
	
	// Checking whether this operator is commented.
	HandlerLineBeforeAlgorithmCall = Left(HandlerRow, InitialChar);
	
	If StrFind(HandlerLineBeforeAlgorithmCall, "//") <> 0  Then 
		// The current operator and all next operators are commented.
		// Exiting loop
		Return;
	EndIf; 
	
	HandlerRow = Mid(HandlerRow, InitialChar + PatternStringLength);
	
	EndChar = StrFind(HandlerRow, ")") - 1;
	
	AlgorithmName = Mid(HandlerRow, 1, EndChar); 
	
	HandlerAlgorithms.Add(TrimAll(AlgorithmName));
	
	// Going through the handler line to consider all algorithm calls
	// 
	GetHandlerStringAlgorithms(HandlerRow, HandlerAlgorithms);
	
EndProcedure 

// Returns the modified algorithm script taking nested algorithms into account. Instead of the 
// "Execute(Algorithms.Algorithm_1);" algorithm call operator, the calling algorithm script is 
// inserted with the PrefixString offset.
// Recursively calls itself to take into account all nested algorithms.
//
// Parameters:
//  Handler                 - String - initial algorithm script.
//  PrefixString             - String - inserting algorithm script offset mode.
//  AlgorithmOwner           - String - a name of the parent algorithm.
//                                        
//  RequestedItemsArray - Array - names of algorithms that were already processed in this recursion branch.
//                                        It is used to prevent endless function recursion and to 
//                                        display the error message.
//  
// Returns:
//  NewHandler - String - modified algorithm script that took nested ones into account.
// 
Function ReplaceAlgorithmCallsWithTheirHandlerScript(Handler, AlgorithmOwner, RequestedItemArray, Val PrefixString = "")
	
	RequestedItemArray.Add(Upper(AlgorithmOwner));
	
	// Initializing the return value.
	NewHandler = "";
	
	WriteAlgorithmBlockTitle(NewHandler, AlgorithmOwner, PrefixString, NStr("ru = '{НАЧАЛО АЛГОРИТМА}'; en = '{ALGORITHM START}'; pl = '{POCZĄTEK ALGORYTMU}';es_ES = '{INICIO DEL ALGORITMO}';es_CO = '{INICIO DEL ALGORITMO}';tr = '{ALGORİTMA BAŞLANGICI}';it = '{ALGORITHM START}';de = '{ALGORITHMUS-ANFANG}'"));
	
	For Index = 1 To StrLineCount(Handler) Do
		
		HandlerRow = StrGetLine(Handler, Index);
		
		HandlerAlgorithms = GetHandlerAlgorithms(HandlerRow);
		
		If HandlerAlgorithms.Count() <> 0 Then // There are algorithm calls in the line.
			
			// Receiving the initial algorithm code offset relative to the current code.
			PrefixStringForInlineCode = GetInlineAlgorithmPrefix(HandlerRow, PrefixString);
				
			// Extracting full scripts for all algorithms that were called from HandlerLine.
			// 
			For Each Algorithm In HandlerAlgorithms Do
				
				If RequestedItemArray.Find(Upper(Algorithm)) <> Undefined Then // recursive algorithm call.
					
					WriteAlgorithmBlockTitle(NewHandler, Algorithm, PrefixStringForInlineCode, NStr("ru = '{РЕКУРСИВНЫЙ ВЫЗОВ АЛГОРИТМА}'; en = '{RECURSIVE ALGORITHM CALL}'; pl = '{RECURSIVE ALGORITHM CALL}';es_ES = '{LLAMADA RECURSIVA DEL ALGORITMO}';es_CO = '{LLAMADA RECURSIVA DEL ALGORITMO}';tr = '{TEKRARLANAN ALGORİTMA ÇAĞRISI}';it = '{RECURSIVE ALGORITHM CALL}';de = '{RECURSIVE ALGORITHM CALL}'"));
					
					OperatorString = NStr("ru = 'CallException ""РЕКУРСИВНЫЙ ВЫЗОВ АЛГОРИТМА: %1"";'; en = 'CallException ""ALGORITHM RECURSIVE CALL: %1"";'; pl = 'CallException ""ALGORITHM RECURSIVE CALL: %1"";';es_ES = 'CallException ""LLAMADA RECURSIVA DEL ALGORITMO: %1"";';es_CO = 'CallException ""LLAMADA RECURSIVA DEL ALGORITMO: %1"";';tr = 'CallException ""TEKRARLANAN ALGORİTMA ÇAĞRISI: %1"";';it = 'CallException ""algoritmo chiamata ricorsiva: %1"";';de = 'AusnahmeAufrufen ""Rekursiver Algorithmus Aufruf: %1"";'");
					OperatorString = SubstituteParametersToString(OperatorString, Algorithm);
					
					NewHandler = NewHandler + Chars.LF + PrefixStringForInlineCode + OperatorString;
					
					WriteAlgorithmBlockTitle(NewHandler, Algorithm, PrefixStringForInlineCode, NStr("ru = '{РЕКУРСИВНЫЙ ВЫЗОВ АЛГОРИТМА}'; en = '{RECURSIVE ALGORITHM CALL}'; pl = '{RECURSIVE ALGORITHM CALL}';es_ES = '{LLAMADA RECURSIVA DEL ALGORITMO}';es_CO = '{LLAMADA RECURSIVA DEL ALGORITMO}';tr = '{TEKRARLANAN ALGORİTMA ÇAĞRISI}';it = '{RECURSIVE ALGORITHM CALL}';de = '{RECURSIVE ALGORITHM CALL}'"));
					
					RecordStructure = New Structure;
					RecordStructure.Insert("Algoritm_1", AlgorithmOwner);
					RecordStructure.Insert("Algoritm_2", Algorithm);
					
					WriteToExecutionProtocol(79, RecordStructure);
					
				Else
					
					NewHandler = NewHandler + ReplaceAlgorithmCallsWithTheirHandlerScript(Algorithms[Algorithm], Algorithm, CopyArray(RequestedItemArray), PrefixStringForInlineCode);
					
				EndIf; 
				
			EndDo;
			
		EndIf; 
		
		NewHandler = NewHandler + Chars.LF + PrefixString + HandlerRow; 
		
	EndDo;
	
	WriteAlgorithmBlockTitle(NewHandler, AlgorithmOwner, PrefixString, NStr("ru = '{КОНЕЦ АЛГОРИТМА}'; en = '{ALGORITHM END}'; pl = '{KONIEC ALGORYTMU}';es_ES = '{FIN DEL ALGORITMO}';es_CO = '{FIN DEL ALGORITMO}';tr = '{ALGORİTMA SONU}';it = '{ALGORITHM END}';de = '{ALGORITHMUS-ENDE}'"));
	
	Return NewHandler;
	
EndFunction

// Copies the passed array and returns a new one.
//
// Parameters:
//  SourceArray - Array - a source to receive a new array via copying.
//  
// Returns:
//  NewArray - Array - an array received by copying from the passed array.
// 
Function CopyArray(SourceArray)
	
	NewArray = New Array;
	
	For Each ArrayElement In SourceArray Do
		
		NewArray.Add(ArrayElement);
		
	EndDo; 
	
	Return NewArray;
EndFunction 

// Returns an array with names of algorithms that were found in the passed handler body.
//
// Parameters:
//  Handler - String - a handler body.
//  
// Returns:
//  HandlerAlgorithms - Array - an array with names of algorithms that the passed handler contains.
//
Function GetHandlerAlgorithms(Handler)
	
	// Initializing the return value.
	HandlerAlgorithms = New Array;
	
	For Index = 1 To StrLineCount(Handler) Do
		
		HandlerRow = TrimL(StrGetLine(Handler, Index));
		
		If StrStartsWith(HandlerRow, "//") Then //Skipping the commented string
			Continue;
		EndIf;
		
		GetHandlerStringAlgorithms(HandlerRow, HandlerAlgorithms);
		
	EndDo;
	
	Return HandlerAlgorithms;
EndFunction 

// Gets the prefix string to output nested algorithm code.
//
// Parameters:
//  HandlerLine - String - a source string where the call offset value will be retrieved from.
//                      
//  PrefixString    - String - the initial offset.
// Returns:
//  PrefixStringForInlineCode - String - algorithm script total offset mode.
// 
Function GetInlineAlgorithmPrefix(HandlerRow, PrefixString)
	
	HandlerRow = Upper(HandlerRow);
	
	TemplatePositionNumberExecute = StrFind(HandlerRow, "EXECUTE");
	
	PrefixStringForInlineCode = PrefixString + Left(HandlerRow, TemplatePositionNumberExecute - 1) + Chars.Tab;
	
	// If the handler line contained an algorithm call, clearing the handler line.
	HandlerRow = "";
	
	Return PrefixStringForInlineCode;
EndFunction 

#EndRegion

#Region FunctionsForGenerationUniqueNameOfEventHandlers

// Generates PCR or PGCR handler interface, that is a unique name of the procedure with parameters of the corresponding handler).
//
// Parameters:
//  OCR            - Value table row - contains the object conversion rule.
//  PGCR           - Value table row - contains the property group conversion rule.
//  Rule        - Values table row - contains the object property conversion rule.
//  HandlerName - String - an event handler name.
//
// Returns:
//  String - handler interface.
// 
Function GetPCRHandlerInterface(OCR, PGCR, Rule, HandlerName)
	
	AreaName = "CR" + ?(Rule.IsFolder, "G", "") + "P_" + HandlerName;
	
	OwnerName = "_" + TrimAll(OCR.Name);
	
	ParentName  = "";
	
	If PGCR <> Undefined Then
		
		If Not IsBlankString(PGCR.DestinationKind) Then 
			
			ParentName = "_" + TrimAll(PGCR.Destination);	
			
		EndIf; 
		
	EndIf; 
	
	DestinationName = "_" + TrimAll(Rule.Destination);
	DestinationKind = "_" + TrimAll(Rule.DestinationKind);
	
	PropertyCode = TrimAll(Rule.Name);
	
	FullHandlerName = AreaName + OwnerName + ParentName + DestinationName + DestinationKind + PropertyCode;
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

// Generates an OCR, DER, or DPR handler interface, that is a unique name of the procedure with the parameters of the corresponding handler.
//
// Parameters:
//  Rule            - an arbotrary value collection (OCR, DER, and DPR).
//  HandlerPrefix - String - possible values are: OCR, DER, DPR.
//  HandlerName     - String - the name handler events for this rules.
//
// Returns:
//  String - handler interface.
// 
Function GetHandlerInterface(Rule, HandlerPrefix, HandlerName)
	
	AreaName = HandlerPrefix + "_" + HandlerName;
	
	RuleName = "_" + TrimAll(Rule.Name);
	
	FullHandlerName = AreaName + RuleName;
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

// Generates the interface of the global conversion handler (Generates a unique name of the 
// procedure with parameters of the corresponding handler).
//
// Parameters:
//  HandlerName - String - a conversion event handler name.
//
// Returns:
//  String - handler interface.
// 
Function GetConversionHandlerInterface(HandlerName)
	
	AreaName = "Conversion_" + HandlerName;
	
	FullHandlerName = AreaName;
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

// Generates procedure interface (constructor or destructor) for an external data processor.
//
// Parameters:
//  ProcedureName - String - a name of procedure.
//
// Returns:
//  String - procedure interface.
// 
Function GetExternalDataProcessorProcedureInterface(ProcedureName)
	
	AreaName = "DataProcessor_" + ProcedureName;
	
	FullHandlerName = ProcedureName;
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

// Generates an algorithm interface for an external data processor.
// Getting the same parameter set by default for all algorithms.
//
// Parameters:
//  AlgorithmName - String - an algorithm name.
//
// Returns:
//  String - algorithm interface.
// 
Function GetAlgorithmInterface(AlgorithmName)
	
	FullHandlerName = "Algoritm_" + AlgorithmName;
	
	AreaName = "Algorithm_ByDefault";
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

Function GetHandlerCallString(Rule, HandlerName)
	
	Return "EventHandlersExternalDataProcessor." + Rule["HandlerInterface" + HandlerName] + ";";
	
EndFunction 

Function GetTextByAreaWithoutAreaTitle(Area)
	
	AreaText = Area.GetText();
	
	If StrFind(AreaText, "#Region") > 0 Then
	
		FirstLinefeed = StrFind(AreaText, Chars.LF);
		
		AreaText = Mid(AreaText, FirstLinefeed + 1);
		
	EndIf;
	
	Return AreaText;
	
EndFunction

Function GetHandlerParameters(AreaName)
	
	NewLineString = Chars.LF + "                                           ";
	
	HandlerParameters = "";
	
	TotalString = "";
	
	Area = mHandlerParameterTemplate.GetArea(AreaName);
	
	ParametersArea = Area.Areas[AreaName];
	
	For RowNumber = ParametersArea.Top To ParametersArea.Bottom Do
		
		CurrentArea = Area.GetArea(RowNumber, 2, RowNumber, 2);
		
		Parameter = TrimAll(CurrentArea.CurrentArea.Text);
		
		If Not IsBlankString(Parameter) Then
			
			HandlerParameters = HandlerParameters + Parameter + ", ";
			
			TotalString = TotalString + Parameter;
			
		EndIf; 
		
		If StrLen(TotalString) > 50 Then
			
			TotalString = "";
			
			HandlerParameters = HandlerParameters + NewLineString;
			
		EndIf; 
		
	EndDo;
	
	HandlerParameters = TrimAll(HandlerParameters);
	
	// Removing the last character "," and returning a row.
	
	Return Mid(HandlerParameters, 1, StrLen(HandlerParameters) - 1); 
EndFunction 

#EndRegion

#Region GeneratingHandlerCallInterfacesInExchangeRulesProcedures

// Complements the collection of data clearing rule values with handler interfaces.
//
// Parameters:
//  DPRTable   - ValueTree - contains the data clearing rules.
//  TreeRows - ValueTreeRowCollection object, contains data clearing rules of this value tree level.
//  
Procedure SupplementWithDataClearingRuleHandlerInterfaces(DPRTable, TreeRows)
	
	For Each Rule In TreeRows Do
		
		If Rule.IsFolder Then
			
			SupplementWithDataClearingRuleHandlerInterfaces(DPRTable, Rule.Rows); 
			
		Else
			
			For Each Item In HandlerNames.DPR Do
				
				AddHandlerInterface(DPRTable, Rule, "DPR", Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

// Complements the collection of data export rule values with handler interfaces.
//
// Parameters:
//  DERTable   - ValueTree - contains the data export rules.
//  TreeRows - ValueTreeRowCollection object, contains data export rule of this value tree level.
//  
Procedure SupplementDataExportRulesWithHandlerInterfaces(DERTable, TreeRows) 
	
	For Each Rule In TreeRows Do
		
		If Rule.IsFolder Then
			
			SupplementDataExportRulesWithHandlerInterfaces(DERTable, Rule.Rows); 
			
		Else
			
			For Each Item In HandlerNames.DER Do
				
				AddHandlerInterface(DERTable, Rule, "DER", Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

// Complements conversion structure with handler interfaces.
//
// Parameters:
//  ConversionStructure - Structure - contains the conversion rules and global handlers.
//  
Procedure SupplementWithConversionRuleInterfaceHandler(ConversionStructure) 
	
	For Each Item In HandlerNames.Conversion Do
		
		AddConversionHandlerInterface(ConversionStructure, Item.Key);
		
	EndDo; 
	
EndProcedure  

// Complements the collection of object conversion rule values with handler interfaces.
//
// Parameters:
//  OCRTable - ValueTable - contains object conversion rules.
//  
Procedure SupplementWithObjectConversionRuleHandlerInterfaces(OCRTable)
	
	For Each OCR In OCRTable Do
		
		For Each Item In HandlerNames.OCR Do
			
			AddOCRHandlerInterface(OCRTable, OCR, Item.Key);
			
		EndDo; 
		
		// Adding interfaces for PCR.
		SupplementWithPCRHandlersInterfaces(OCR, OCR.SearchProperties);
		SupplementWithPCRHandlersInterfaces(OCR, OCR.Properties);
		
	EndDo; 
	
EndProcedure

// Complements the collection of object property conversion rule values with handler interfaces.
//
// Parameters:
//  OCR - Values table row    - contains the object conversion rule.
//  ObjectPropertiesConversionRules - ValueTable - contains rules of conversion of properties or 
//                                                       property group of an object from the OCR rule.
//  PGCR - Value table row   - contains the property group conversion rule.
//  
Procedure SupplementWithPCRHandlersInterfaces(OCR, ObjectPropertyConversionRules, PGCR = Undefined)
	
	For Each PCR In ObjectPropertyConversionRules Do
		
		If PCR.IsFolder Then // PGCR
			
			For Each Item In HandlerNames.PGCR Do
				
				AddPCRHandlerInterface(ObjectPropertyConversionRules, OCR, PGCR, PCR, Item.Key);
				
			EndDo; 

			SupplementWithPCRHandlersInterfaces(OCR, PCR.GroupRules, PCR);
			
		Else
			
			For Each Item In HandlerNames.PCR Do
				
				AddPCRHandlerInterface(ObjectPropertyConversionRules, OCR, PGCR, PCR, Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

Procedure AddHandlerInterface(Table, Rule, HandlerPrefix, HandlerName) 
	
	If IsBlankString(Rule[HandlerName]) Then
		Return;
	EndIf;
	
	FieldName = "HandlerInterface" + HandlerName;
	
	AddMissingColumns(Table.Columns, FieldName);
		
	Rule[FieldName] = GetHandlerInterface(Rule, HandlerPrefix, HandlerName);
	
EndProcedure 

Procedure AddOCRHandlerInterface(Table, Rule, HandlerName) 
	
	If Not Rule["HasHandler" + HandlerName] Then
		Return;
	EndIf; 
	
	FieldName = "HandlerInterface" + HandlerName;
	
	AddMissingColumns(Table.Columns, FieldName);
	
	Rule[FieldName] = GetHandlerInterface(Rule, "OCR", HandlerName);
  
EndProcedure 

Procedure AddPCRHandlerInterface(Table, OCR, PGCR, PCR, HandlerName) 
	
	If Not PCR["HasHandler" + HandlerName] Then
		Return;
	EndIf; 
	
	FieldName = "HandlerInterface" + HandlerName;
	
	AddMissingColumns(Table.Columns, FieldName);
	
	PCR[FieldName] = GetPCRHandlerInterface(OCR, PGCR, PCR, HandlerName);
	
EndProcedure  

Procedure AddConversionHandlerInterface(ConversionStructure, HandlerName)
	
	HandlerAlgorithm = "";
	
	If ConversionStructure.Property(HandlerName, HandlerAlgorithm) AND Not IsBlankString(HandlerAlgorithm) Then
		
		FieldName = "HandlerInterface" + HandlerName;
		
		ConversionStructure.Insert(FieldName);
		
		ConversionStructure[FieldName] = GetConversionHandlerInterface(HandlerName); 
		
	EndIf;
	
EndProcedure  

#EndRegion

#Region ExchangeRulesOperationProcedures

Function GetPlatformByDestinationPlatformVersion(PlatformVersion)
	
	If StrFind(PlatformVersion, "8.") > 0 Then
		
		Return "V8";
		
	Else
		
		Return "V7";
		
	EndIf;	
	
EndFunction

// Restores rules from the internal format.
//
// Parameters:
// 
Procedure RestoreRulesFromInternalFormat() Export

	If SavedSettings = Undefined Then
		Return;
	EndIf;
	
	RulesStructure = SavedSettings.Get();

	ExportRuleTable      = RulesStructure.ExportRuleTable;
	ConversionRulesTable   = RulesStructure.ConversionRulesTable;
	Algorithms                  = RulesStructure.Algorithms;
	QueriesToRestore   = RulesStructure.Queries;
	Conversion                = RulesStructure.Conversion;
	mXMLRules                = RulesStructure.mXMLRules;
	ParameterSetupTable = RulesStructure.ParameterSetupTable;
	Parameters                  = RulesStructure.Parameters;
	
	SupplementServiceTablesWithColumns();
	
	RulesStructure.Property("DestinationPlatformVersion", DestinationPlatformVersion);
	
	DestinationPlatform = GetPlatformByDestinationPlatformVersion(DestinationPlatformVersion);
		
	HasBeforeExportObjectGlobalHandler    = Not IsBlankString(Conversion.BeforeExportObject);
	HasAfterExportObjectGlobalHandler     = Not IsBlankString(Conversion.AfterExportObject);
	HasBeforeImportObjectGlobalHandler    = Not IsBlankString(Conversion.BeforeImportObject);
	HasAfterImportObjectGlobalHandler     = Not IsBlankString(Conversion.AfterImportObject);
	HasBeforeConvertObjectGlobalHandler = Not IsBlankString(Conversion.BeforeConvertObject);

	// Restoring queries
	Queries.Clear();
	For Each StructureItem In QueriesToRestore Do
		Query = New Query(StructureItem.Value);
		Queries.Insert(StructureItem.Key, Query);
	EndDo;

	InitManagersAndMessages();
	
	Rules.Clear();
	ClearManagersOCR();
	
	If ExchangeMode = "DataExported" Then
	
		For Each TableRow In ConversionRulesTable Do
			Rules.Insert(TableRow.Name, TableRow);

			If TableRow.Source <> Undefined Then
				
				Try
					If TypeOf(TableRow.Source) = deStringType Then
						Managers[Type(TableRow.Source)].OCR = TableRow;
					Else
						Managers[TableRow.Source].OCR = TableRow;
					EndIf;			
				Except
					WriteErrorInfoToProtocol(11, ErrorDescription(), String(TableRow.Source));
				EndTry;
				
			EndIf;

		EndDo;
	
	EndIf;	
	
EndProcedure

// Initializes parameters by default values from the exchange rules.
//
// Parameters:
//  No.
// 
Procedure InitializeInitialParameterValues() Export
	
	For Each CurParameter In Parameters Do
		
		SetParameterValueInTable(CurParameter.Key, CurParameter.Value);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ClearingRuleProcessing

Procedure ExecuteObjectDeletion(Object, Properties, DeleteDirectly)
	
	TypeName = Properties.TypeName;
	
	If TypeName = "InformationRegister" Then
		
		Object.Delete();
		
	Else
		
		If (TypeName = "Catalog"
			Or TypeName = "ChartOfCharacteristicTypes"
			Or TypeName = "ChartOfAccounts"
			Or TypeName = "ChartOfCalculationTypes")
			AND Object.Predefined Then
			
			Return;
			
		EndIf;
		
		If DeleteDirectly Then
			
			Object.Delete();
			
		Else
			
			SetObjectDeletionMark(Object, True, Properties.TypeName);
			
		EndIf;
			
	EndIf;	
	
EndProcedure

// Clears data according to the specified rule.
//
// Parameters:
//  Rule - data clearing rule reference.
// 
Procedure ClearDataByRule(Rule)
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ApplicationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	// BeforeProcess handle

	Cancel			= False;
	DataSelection	= Undefined;

	OutgoingData	= Undefined;


	// BeforeProcessClearingRule handler
	If Not IsBlankString(Rule.BeforeProcess) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeProcess"));
				
			Else
				
				Execute(Rule.BeforeProcess);
				
			EndIf;
			
		Except
			
			WriteDataClearingHandlerErrorInfo(27, ErrorDescription(), Rule.Name, "", "BeforeProcessClearingRule");
						
		EndTry;
		
		If Cancel Then
		
			Return;
			
		EndIf;
		
	EndIf;
	
	// Standard selection
	
	Properties = Managers[Rule.SelectionObject];
	
	If Rule.DataFilterMethod = "StandardSelection" Then
		
		TypeName = Properties.TypeName;
		
		If TypeName = "AccountingRegister" 
			OR TypeName = "Constants" Then
			
			Return;
			
		EndIf;
		
		AllFieldsRequired  = Not IsBlankString(Rule.BeforeDelete);
		
		Selection = GetSelectionForDataClearingExport(Properties, TypeName, True, Rule.Directly, AllFieldsRequired);
		
		While Selection.Next() Do
			
			If TypeName =  "InformationRegister" Then
				
				RecordManager = Properties.Manager.CreateRecordManager(); 
				FillPropertyValues(RecordManager, Selection);
									
				SelectionObjectDeletion(RecordManager, Rule, Properties, OutgoingData);
					
			Else
					
				SelectionObjectDeletion(Selection.Ref.GetObject(), Rule, Properties, OutgoingData);
					
			EndIf;
				
		EndDo;
		
	ElsIf Rule.DataFilterMethod = "ArbitraryAlgorithm" Then
		
		If DataSelection <> Undefined Then
			
			Selection = GetExportWithArbitraryAlgorithmSelection(DataSelection);
			
			If Selection <> Undefined Then
				
				While Selection.Next() Do
										
					If TypeName =  "InformationRegister" Then
				
						RecordManager = Properties.Manager.CreateRecordManager(); 
						FillPropertyValues(RecordManager, Selection);
											
						SelectionObjectDeletion(RecordManager, Rule, Properties, OutgoingData);				
											
					Else
							
						SelectionObjectDeletion(Selection.Ref.GetObject(), Rule, Properties, OutgoingData);
							
					EndIf;					
					
				EndDo;	
				
			Else
				
				For each Object In DataSelection Do
					
					SelectionObjectDeletion(Object.GetObject(), Rule, Properties, OutgoingData);
					
				EndDo;
				
			EndIf;
			
		EndIf; 
			
	EndIf; 

	
	// AfterProcessClearingRule handler

	If Not IsBlankString(Rule.AfterProcess) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "AfterProcess"));
				
			Else
				
				Execute(Rule.AfterProcess);
				
			EndIf;
			
		Except
			
			WriteDataClearingHandlerErrorInfo(28, ErrorDescription(), Rule.Name, "", "AfterProcessClearingRule");
									
		EndTry;
		
	EndIf;
	
EndProcedure

// Iterates the tree of data clearing rules and executes clearing.
//
// Parameters:
//  Rows - value tree rows collection.
// 
Procedure ProcessClearingRules(Rows)
	
	For each ClearingRule In Rows Do
		
		If ClearingRule.Enable = 0 Then
			
			Continue;
			
		EndIf; 

		If ClearingRule.IsFolder Then
			
			ProcessClearingRules(ClearingRule.Rows);
			Continue;
			
		EndIf;
		
		ClearDataByRule(ClearingRule);
		
	EndDo; 
	
EndProcedure

#EndRegion

#Region DataImportProcedures

// Sets the Load parameter value for the DataExchange object property.
//
// Parameters:
//  Object - object whose property will be set.
//  Value - a value of the Import property being set.
// 
Procedure SetDataExchangeLoad(Object, Value = True) Export
	
	If Not ImportDataInExchangeMode Then
		Return;
	EndIf;
	
	Try
		Object.DataExchange.Load = Value;
	Except
		// Objects those take part in the exchange might not have the DataExchange property.
		// For example, ConstantsSet do not have such a property.
		// Using the Attempt construction... The exception is more profitable in terms of speed, rather than 
		// determining the type of object.
	EndTry;
	
EndProcedure

Function SetNewObjectRef(Object, Manager, SearchProperties)
	
	UUID = SearchProperties["{UUID}"];
	
	If UUID <> Undefined Then
		
		NewRef = Manager.GetRef(New UUID(UUID));
		
		Object.SetNewObjectRef(NewRef);
		
		SearchProperties.Delete("{UUID}");
		
	Else
		
		NewRef = Undefined;
		
	EndIf;
	
	Return NewRef;
	
EndFunction

// Searches for the object by its number in the list of already imported objects.
//
// Parameters:
//  NBSp          - a number of the object to be searched in the exchange file.
//
// Returns:
//  Reference to the found object. If object is not found, Undefined is returned.
// 
Function FindObjectByNumber(SN, MainObjectSearchMode = False)

	If SN = 0 Then
		Return Undefined;
	EndIf;
	
	ResultStructure = ImportedObjects[SN];
	
	If ResultStructure = Undefined Then
		Return Undefined;
	EndIf;
	
	If MainObjectSearchMode AND ResultStructure.DummyRef Then
		Return Undefined;
	Else
		Return ResultStructure.ObjectRef;
	EndIf; 

EndFunction

Function FindObjectByGlobalNumber(SN, MainObjectSearchMode = False)

	ResultStructure = ImportedGlobalObjects[SN];
	
	If ResultStructure = Undefined Then
		Return Undefined;
	EndIf;
	
	If MainObjectSearchMode AND ResultStructure.DummyRef Then
		Return Undefined;
	Else
		Return ResultStructure.ObjectRef;
	EndIf;
	
EndFunction

Procedure WriteObjectToIB(Object, Type)
		
	Try
		
		SetDataExchangeLoad(Object);
		Object.Write();
		
	Except
		
		ErrorMessageString = WriteErrorInfoToProtocol(26, ErrorDescription(), Object, Type);
		
		If Not DebugModeFlag Then
			Raise ErrorMessageString;
		EndIf;
		
	EndTry;
	
EndProcedure

// Creates a new object of the specified type, sets attributes that are specified in the 
// SearchProperties structure.
//
// Parameters:
//  Type - type of the object to be created.
//  SearchProperties - Structure - contains attributes of a new object to be set.
//
// Returns:
//  New infobase object.
// 
Function CreateNewObject(Type, SearchProperties, Object = Undefined, 
	WriteObjectImmediatelyAfterCreation = True, RegisterRecordSet = Undefined,
	NewRef = Undefined, SN = 0, GSN = 0, ObjectParameters = Undefined,
	SetAllObjectSearchProperties = True)

	MDProperties      = Managers[Type];
	TypeName         = MDProperties.TypeName;
	Manager        = MDProperties.Manager;
	DeletionMark = Undefined;

	If TypeName = "Catalog"
		OR TypeName = "ChartOfCharacteristicTypes" Then
		
		IsFolder = SearchProperties["IsFolder"];
		
		If IsFolder = True Then
			
			Object = Manager.CreateFolder();
						
		Else
			
			Object = Manager.CreateItem();
			
		EndIf;		
				
	ElsIf TypeName = "Document" Then
		
		Object = Manager.CreateDocument();
				
	ElsIf TypeName = "ChartOfAccounts" Then
		
		Object = Manager.CreateAccount();
				
	ElsIf TypeName = "ChartOfCalculationTypes" Then
		
		Object = Manager.CreateCalculationType();
				
	ElsIf TypeName = "InformationRegister" Then
		
		If WriteRegistersAsRecordSets Then
			
			RegisterRecordSet = Manager.CreateRecordSet();
			Object = RegisterRecordSet.Add();
			
		Else
			
			Object = Manager.CreateRecordManager();
						
		EndIf;
		
		Return Object;
		
	ElsIf TypeName = "ExchangePlan" Then
		
		Object = Manager.CreateNode();
				
	ElsIf TypeName = "Task" Then
		
		Object = Manager.CreateTask();
		
	ElsIf TypeName = "BusinessProcess" Then
		
		Object = Manager.CreateBusinessProcess();	
		
	ElsIf TypeName = "Enum" Then
		
		Object = MDProperties.EmptyRef;	
		Return Object;
		
	ElsIf TypeName = "BusinessProcessRoutePoint" Then
		
		Return Undefined;
				
	EndIf;
	
	NewRef = SetNewObjectRef(Object, Manager, SearchProperties);
	
	If SetAllObjectSearchProperties Then
		SetObjectSearchAttributes(Object, SearchProperties, Undefined, False, False);
	EndIf;
	
	// Checks
	If TypeName = "Document"
		OR TypeName = "Task"
		OR TypeName = "BusinessProcess" Then
		
		If NOT ValueIsFilled(Object.Date) Then
			
			Object.Date = CurrentSessionDate();
			
		EndIf;
		
	EndIf;
		
	// If Owner is not set, you need to add field to the possible search fields and specify fields 
	// without owners in the SEARCHFIELDS event if you do not need to search by it.
	
	If WriteObjectImmediatelyAfterCreation Then
		
		If NOT ImportReferencedObjectsWithoutDeletionMark Then
			Object.DeletionMark = True;
		EndIf;
		
		If GSN <> 0
			OR Not OptimizedObjectsWriting Then
		
			WriteObjectToIB(Object, Type);
			
		Else
			
			// The object is not written immediately. Instead of this, the object will be stored to the stack of 
			// objects to be written. Both the new reference and the object are returned, although the object is 
			// not written.
			If NewRef = Undefined Then
				
				// Generating the new reference.
				NewUUID = New UUID;
				NewRef = Manager.GetRef(NewUUID);
				Object.SetNewObjectRef(NewRef);
				
			EndIf;			
			
			SupplementNotWrittenObjectStack(SN, GSN, Object, NewRef, Type, ObjectParameters);
			
			Return NewRef;
			
		EndIf;
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	Return Object.Ref;
	
EndFunction

// Reads the object property node from the file and sets the property value.
//
// Parameters:
//  Type - property value type.
//  ObjectFound - False returned after function execution means that the property object is not 
//                   found in the infobase and the new object was created.
//
// Returns:
//  Property value
// 
Function ReadProperty(Type, OCRName = "")
	
	Value = Undefined;
	PropertyExistence = False;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Value" Then
			
			SearchByProperty = deAttribute(ExchangeFile, deStringType, "Property");
			Value         = deElementValue(ExchangeFile, Type, SearchByProperty, RemoveTrailingSpaces);
			PropertyExistence = True;
			
		ElsIf NodeName = "Ref" Then
			
			Value       = FindObjectByRef(Type, OCRName);
			PropertyExistence = True;
			
		ElsIf NodeName = "Sn" Then
			
			deSkip(ExchangeFile);
			
		ElsIf NodeName = "Gsn" Then
			
			ExchangeFile.Read();
			GSN = Number(ExchangeFile.Value);
			If GSN <> 0 Then
				Value  = FindObjectByGlobalNumber(GSN);
				PropertyExistence = True;
			EndIf;
			
			ExchangeFile.Read();
			
		ElsIf (NodeName = "Property" OR NodeName = "ParameterValue") AND (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
			
			If Not PropertyExistence
				AND ValueIsFilled(Type) Then
				
				// If there is no data, empty value.
				Value = deGetEmptyValue(Type);
				
			EndIf;
			
			Break;
			
		ElsIf NodeName = "Expression" Then
			
			Expression = deElementValue(ExchangeFile, deStringType, , False);
			Value  = EvalExpression(Expression);
			
			PropertyExistence = True;
			
		ElsIf NodeName = "Empty" Then
			
			Value = deGetEmptyValue(Type);
			PropertyExistence = True;		
			
		Else
			
			WriteToExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	Return Value;	
	
EndFunction

Function SetObjectSearchAttributes(FoundObject, SearchProperties, SearchPropertiesDontReplace, 
	ShouldCompareWithCurrentAttributes = True, DontReplacePropertiesNotToChange = True)
	
	ObjectAttributeChanged = False;
				
	For each Property In SearchProperties Do
					
		Name      = Property.Key;
		Value = Property.Value;
		
		If DontReplacePropertiesNotToChange
			AND SearchPropertiesDontReplace[Name] <> Undefined Then
			
			Continue;
			
		EndIf;
					
		If Name = "IsFolder" 
			OR Name = "{UUID}" 
			OR Name = "{PredefinedItemName}" Then
						
			Continue;
						
		ElsIf Name = "DeletionMark" Then
						
			If NOT ShouldCompareWithCurrentAttributes
				OR FoundObject.DeletionMark <> Value Then
							
				FoundObject.DeletionMark = Value;
				ObjectAttributeChanged = True;
							
			EndIf;
						
		Else
				
			// Setting attributes that are different.
			If FoundObject[Name] <> NULL Then
			
				If NOT ShouldCompareWithCurrentAttributes
					OR FoundObject[Name] <> Value Then
						
					FoundObject[Name] = Value;
					ObjectAttributeChanged = True;
						
				EndIf;
				
			EndIf;
				
		EndIf;
					
	EndDo;
	
	Return ObjectAttributeChanged;
	
EndFunction

Function FindOrCreateObjectByProperty(PropertyStructure, ObjectType, SearchProperties, SearchPropertiesDontReplace,
	ObjectTypeName, SearchProperty, SearchPropertyValue, ObjectFound,
	CreateNewItemIfNotFound, FoundOrCreatedObject,
	MainObjectSearchMode, ObjectPropertyModified, SN, GSN,
	ObjectParameters, NewUUIDRef = Undefined)
	
	IsEnum = PropertyStructure.TypeName = "Enum";
	
	If IsEnum Then
		
		SearchString = "";
		
	Else
		
		SearchString = PropertyStructure.SearchString;
		
	EndIf;
	
	If MainObjectSearchMode Or IsBlankString(SearchString) Then
		SearchByUUIDQueryString = "";
	Else
		SearchByUUIDQueryString = SearchByUUIDQueryString;
	EndIf;
	
	Object = FindObjectByProperty(PropertyStructure.Manager, SearchProperty, SearchPropertyValue,
		FoundOrCreatedObject, , , SearchByUUIDQueryString);
		
	ObjectFound = NOT (Object = Undefined OR Object.IsEmpty());
		
	If Not ObjectFound Then
		If CreateNewItemIfNotFound Then
		
			Object = CreateNewObject(ObjectType, SearchProperties, FoundOrCreatedObject, 
				NOT MainObjectSearchMode,,NewUUIDRef, SN, GSN, ObjectParameters);
				
			ObjectPropertyModified = True;
		EndIf;
		Return Object;
	
	EndIf;
	
	If IsEnum Then
		Return Object;
	EndIf;			
	
	If MainObjectSearchMode Then
		
		If FoundOrCreatedObject = Undefined Then
			FoundOrCreatedObject = Object.GetObject();
		EndIf;
			
		ObjectPropertyModified = SetObjectSearchAttributes(FoundOrCreatedObject, SearchProperties, SearchPropertiesDontReplace);
				
	EndIf;
		
	Return Object;
	
EndFunction

Function GetPropertyType()
	
	PropertyTypeString = deAttribute(ExchangeFile, deStringType, "Type");
	If IsBlankString(PropertyTypeString) Then
		Return Undefined;
	EndIf;
	
	Return Type(PropertyTypeString);
	
EndFunction

Function GetPropertyTypeByAdditionalData(TypesInformation, PropertyName)
	
	PropertyType = GetPropertyType();
				
	If PropertyType = Undefined
		AND TypesInformation <> Undefined Then
		
		PropertyType = TypesInformation[PropertyName];
		
	EndIf;
	
	Return PropertyType;
	
EndFunction

Procedure ReadSearchPropertiesFromFile(SearchProperties, SearchPropertiesDontReplace, TypesInformation, 
	SearchByEqualDate = False, ObjectParameters = Undefined)
	
	SearchByEqualDate = False;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
				
		If NodeName = "Property"
			OR NodeName = "ParameterValue" Then
					
			IsParameter = (NodeName = "ParameterValue");
			
			Name = deAttribute(ExchangeFile, deStringType, "Name");
			
			If Name = "{UUID}" 
				OR Name = "{PredefinedItemName}" Then
				
				PropertyType = deStringType;
				
			Else
			
				PropertyType = GetPropertyTypeByAdditionalData(TypesInformation, Name);
			
			EndIf;
			
			DontReplaceProperty = deAttribute(ExchangeFile, deBooleanType, "DoNotReplace");
			SearchByEqualDate = SearchByEqualDate 
					OR deAttribute(ExchangeFile, deBooleanType, "SearchByEqualDate");
			//
			OCRName = deAttribute(ExchangeFile, deStringType, "OCRName");
			
			PropertyValue = ReadProperty(PropertyType, OCRName);
			
			If (Name = "IsFolder") AND (PropertyValue <> True) Then
				
				PropertyValue = False;
												
			EndIf;
			
			If IsParameter Then
				
				
				AddParameterIfNecessary(ObjectParameters, Name, PropertyValue);
				
			Else
			
				SearchProperties[Name] = PropertyValue;
				
				If DontReplaceProperty Then
					
					SearchPropertiesDontReplace[Name] = True;
					
				EndIf;
				
			EndIf;
			
		ElsIf (NodeName = "Ref") AND (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		Else
			
			WriteToExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;	
	
EndProcedure

Function UnlimitedLengthField(TypeManager, ParameterName)
	
	LongStrings = Undefined;
	If NOT TypeManager.Property("LongStrings", LongStrings) Then
		
		LongStrings = New Map;
		For Each Attribute In TypeManager.MetadateObject.Attributes Do
			
			If Attribute.Type.ContainsType(deStringType) 
				AND (Attribute.Type.StringQualifiers.Length = 0) Then
				
				LongStrings.Insert(Attribute.Name, Attribute.Name);	
				
			EndIf;
			
		EndDo;
		
		TypeManager.Insert("LongStrings", LongStrings);
		
	EndIf;
	
	Return (LongStrings[ParameterName] <> Undefined);
		
EndFunction

Function IsUnlimitedLengthParameter(TypeManager, ParameterValue, ParameterName)
	
	Try
			
		If TypeOf(ParameterValue) = deStringType Then
			UnlimitedLengthString = UnlimitedLengthField(TypeManager, ParameterName);
		Else
			UnlimitedLengthString = False;
		EndIf;		
												
	Except
				
		UnlimitedLengthString = False;
				
	EndTry;
	
	Return UnlimitedLengthString;	
	
EndFunction

Function FindItemUsingRequest(PropertyStructure, SearchProperties, ObjectType = Undefined, 
	TypeManager = Undefined, RealPropertyForSearchCount = Undefined)
	
	PropertyCountForSearch = ?(RealPropertyForSearchCount = Undefined, SearchProperties.Count(), RealPropertyForSearchCount);
	
	If PropertyCountForSearch = 0
		AND PropertyStructure.TypeName = "Enum" Then
		
		Return PropertyStructure.EmptyRef;
		
	EndIf;	
	
	QueryText       = PropertyStructure.SearchString;
	
	If IsBlankString(QueryText) Then
		Return PropertyStructure.EmptyRef;
	EndIf;
	
	SearchQuery       = New Query();
	PropertyUsedInSearchCount = 0;
			
	For each Property In SearchProperties Do
				
		ParameterName      = Property.Key;
		
		// The following parameters cannot be search fields.
		If ParameterName = "{UUID}"
			OR ParameterName = "{PredefinedItemName}" Then
						
			Continue;
						
		EndIf;
		
		ParameterValue = Property.Value;
		SearchQuery.SetParameter(ParameterName, ParameterValue);
				
		Try
			
			UnlimitedLengthString = IsUnlimitedLengthParameter(PropertyStructure, ParameterValue, ParameterName);		
													
		Except
					
			UnlimitedLengthString = False;
					
		EndTry;
		
		PropertyUsedInSearchCount = PropertyUsedInSearchCount + 1;
				
		If UnlimitedLengthString Then
					
			QueryText = QueryText + ?(PropertyUsedInSearchCount > 1, " AND ", "") + ParameterName + " LIKE &" + ParameterName;
					
		Else
					
			QueryText = QueryText + ?(PropertyUsedInSearchCount > 1, " AND ", "") + ParameterName + " = &" + ParameterName;
					
		EndIf;
								
	EndDo;
	
	If PropertyUsedInSearchCount = 0 Then
		Return Undefined;
	EndIf;
	
	SearchQuery.Text = QueryText;
	Result = SearchQuery.Execute();
			
	If Result.IsEmpty() Then
		
		Return Undefined;
								
	Else
		
		// Returning the first found object.
		Selection = Result.Select();
		Selection.Next();
		ObjectRef = Selection.Ref;
				
	EndIf;
	
	Return ObjectRef;
	
EndFunction

Function GetAdditionalSearchBySearchFieldsUsageByObjectType(RefTypeString)
	
	MapValue = mExtendedSearchParameterMap.Get(RefTypeString);
	
	If MapValue <> Undefined Then
		Return MapValue;
	EndIf;
	
	Try
	
		For Each Item In Rules Do
			
			If Item.Value.Destination = RefTypeString Then
				
				If Item.Value.SynchronizeByID = True Then
					
					MustContinueSearch = (Item.Value.SearchBySearchFieldsIfNotFoundByID = True);
					mExtendedSearchParameterMap.Insert(RefTypeString, MustContinueSearch);
					
					Return MustContinueSearch;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		mExtendedSearchParameterMap.Insert(RefTypeString, False);
		Return False;
	
	Except
		
		mExtendedSearchParameterMap.Insert(RefTypeString, False);
		Return False;
	
    EndTry;
	
EndFunction

// Determines the object conversion rule (OCR) by destination object type.
//
// Parameters:
//  RefTypeAsString - String - an object type as a string, for example, CatalogRef.Products.
// 
// Returns:
//  MapValue = object conversion rule.
// 
Function GetConversionRuleWithSearchAlgorithmByDestinationObjectType(RefTypeString)
	
	MapValue = mConversionRuleMap.Get(RefTypeString);
	
	If MapValue <> Undefined Then
		Return MapValue;
	EndIf;
	
	Try
	
		For Each Item In Rules Do
			
			If Item.Value.Destination = RefTypeString Then
				
				If Item.Value.HasSearchFieldSequenceHandler = True Then
					
					Rule = Item.Value;
					
					mConversionRuleMap.Insert(RefTypeString, Rule);
					
					Return Rule;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		mConversionRuleMap.Insert(RefTypeString, Undefined);
		Return Undefined;
	
	Except
		
		mConversionRuleMap.Insert(RefTypeString, Undefined);
		Return Undefined;
	
	EndTry;
	
EndFunction

Function FindObjectRefBySingleProperty(SearchProperties, PropertyStructure)
	
	For each Property In SearchProperties Do
					
		ParameterName      = Property.Key;
					
		// The following parameters cannot be search fields.
		If ParameterName = "{UUID}"
			OR ParameterName = "{PredefinedItemName}" Then
						
			Continue;
						
		EndIf;
					
		ParameterValue = Property.Value;
		ObjectRef = FindObjectByProperty(PropertyStructure.Manager, ParameterName, ParameterValue, Undefined, PropertyStructure, SearchProperties);
		
	EndDo;
	
	Return ObjectRef;
	
EndFunction

Function FindDocumentRef(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery, SearchByEqualDate)
	
	// Attempting to search for the document by the date and number.
	SearchWithQuery = SearchByEqualDate OR (RealPropertyForSearchCount <> 2);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	DocumentNumber = SearchProperties["Number"];
	DocumentDate  = SearchProperties["Date"];
					
	If (DocumentNumber <> Undefined) AND (DocumentDate <> Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByNumber(DocumentNumber, DocumentDate);
																		
	Else
						
		// Cannot find by date and number. Search using a query.
		SearchWithQuery = True;
		ObjectRef = Undefined;
						
	EndIf;
	
	Return ObjectRef;
	
EndFunction

Function FindRefToCatalog(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Owner     = SearchProperties["Owner"];
	Parent     = SearchProperties["Parent"];
	Code          = SearchProperties["Code"];
	Description = SearchProperties["Description"];
				
	Qty          = 0;
				
	If Owner <> Undefined Then	Qty = 1 + Qty; EndIf;
	If Parent <> Undefined Then	Qty = 1 + Qty; EndIf;
	If Code <> Undefined Then Qty = 1 + Qty; EndIf;
	If Description <> Undefined Then	Qty = 1 + Qty; EndIf;
				
	SearchWithQuery = (Qty <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	If (Code <> Undefined) AND (Description = Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByCode(Code, , Parent, Owner);
																		
	ElsIf (Code = Undefined) AND (Description <> Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByDescription(Description, TRUE, Parent, Owner);
											
	Else
						
		SearchWithQuery = True;
		ObjectRef = Undefined;
						
	EndIf;
															
	Return ObjectRef;
	
EndFunction

Function FindRefToCCT(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Parent     = SearchProperties["Parent"];
	Code          = SearchProperties["Code"];
	Description = SearchProperties["Description"];
	Qty          = 0;
				
	If Parent     <> Undefined Then	Qty = 1 + Qty EndIf;
	If Code          <> Undefined Then Qty = 1 + Qty EndIf;
	If Description <> Undefined Then	Qty = 1 + Qty EndIf;
				
	SearchWithQuery = (Qty <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	If     (Code <> Undefined) AND (Description = Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByCode(Code, Parent);
												
	ElsIf (Code = Undefined) AND (Description <> Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByDescription(Description, TRUE, Parent);
																	
	Else
						
		SearchWithQuery = True;
		ObjectRef = Undefined;
			
	EndIf;
															
	Return ObjectRef;
	
EndFunction

Function FindRefToExchangePlan(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Code          = SearchProperties["Code"];
	Description = SearchProperties["Description"];
	Qty          = 0;
				
	If Code          <> Undefined Then Qty = 1 + Qty EndIf;
	If Description <> Undefined Then	Qty = 1 + Qty EndIf;
				
	SearchWithQuery = (Qty <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	If     (Code <> Undefined) AND (Description = Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByCode(Code);
												
	ElsIf (Code = Undefined) AND (Description <> Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByDescription(Description, TRUE);
																	
	Else
						
		SearchWithQuery = True;
		ObjectRef = Undefined;
						
	EndIf;
															
	Return ObjectRef;
	
EndFunction

Function FindTaskRef(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Code          = SearchProperties["Number"];
	Description = SearchProperties["Description"];
	Qty          = 0;
				
	If Code          <> Undefined Then Qty = 1 + Qty EndIf;
	If Description <> Undefined Then	Qty = 1 + Qty EndIf;
				
	SearchWithQuery = (Qty <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
	
					
	If     (Code <> Undefined) AND (Description = Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByNumber(Code);
												
	ElsIf (Code = Undefined) AND (Description <> Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByDescription(Description, TRUE);
																	
	Else
						
		SearchWithQuery = True;
		ObjectRef = Undefined;
						
	EndIf;
															
	Return ObjectRef;
	
EndFunction

Function FindRefToBusinessProcess(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Code          = SearchProperties["Number"];
	Qty          = 0;
				
	If Code <> Undefined Then Qty = 1 + Qty EndIf;
								
	SearchWithQuery = (Qty <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	If  (Code <> Undefined) Then
						
		ObjectRef = PropertyStructure.Manager.FindByNumber(Code);
												
	Else
						
		SearchWithQuery = True;
		ObjectRef = Undefined;
						
	EndIf;
															
	Return ObjectRef;
	
EndFunction

Procedure AddRefToImportedObjectList(GSNRef, RefSN, ObjectRef, DummyRef = False)
	
	// Remembering the object reference.
	If NOT RememberImportedObjects 
		OR ObjectRef = Undefined Then
		
		Return;
		
	EndIf;
	
	RecordStructure = New Structure("ObjectRef, DummyRef", ObjectRef, DummyRef);
	
	// Remembering the object reference.
	If GSNRef <> 0 Then
		
		ImportedGlobalObjects[GSNRef] = RecordStructure;
		
	ElsIf RefSN <> 0 Then
		
		ImportedObjects[RefSN] = RecordStructure;
						
	EndIf;	
	
EndProcedure

Function FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, 
	PropertyStructure, SearchPropertyNameString, SearchByEqualDate)
	
	// Searching by predefined item name or by unique reference link is not required. Searching by 
	// properties that are in the property name string. If this parameter is empty, searching by all available search properties. 
	// If it is empty, then search by all existing search properties.
		
	SearchWithQuery = False;	
	
	If IsBlankString(SearchPropertyNameString) Then
		
		TemporarySearchProperties = SearchProperties;
		
	Else
		
		ResultingStringForParsing = StrReplace(SearchPropertyNameString, " ", "");
		StringLength = StrLen(ResultingStringForParsing);
		If Mid(ResultingStringForParsing, StringLength, 1) <> "," Then
			
			ResultingStringForParsing = ResultingStringForParsing + ",";
			
		EndIf;
		
		TemporarySearchProperties = New Map;
		For Each PropertyItem In SearchProperties Do
			
			ParameterName = PropertyItem.Key;
			If StrFind(ResultingStringForParsing, ParameterName + ",") > 0 Then
				
				TemporarySearchProperties.Insert(ParameterName, PropertyItem.Value); 	
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	UUIDProperty = TemporarySearchProperties["{UUID}"];
	PredefinedNameProperty = TemporarySearchProperties["{PredefinedItemName}"];
	
	RealPropertyForSearchCount = TemporarySearchProperties.Count();
	RealPropertyForSearchCount = RealPropertyForSearchCount - ?(UUIDProperty <> Undefined, 1, 0);
	RealPropertyForSearchCount = RealPropertyForSearchCount - ?(PredefinedNameProperty <> Undefined, 1, 0);
	
	
	If RealPropertyForSearchCount = 1 Then
				
		ObjectRef = FindObjectRefBySingleProperty(TemporarySearchProperties, PropertyStructure);
																						
	ElsIf ObjectTypeName = "Document" Then
				
		ObjectRef = FindDocumentRef(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery, SearchByEqualDate);
											
	ElsIf ObjectTypeName = "Catalog" Then
				
		ObjectRef = FindRefToCatalog(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
								
	ElsIf ObjectTypeName = "ChartOfCharacteristicTypes" Then
				
		ObjectRef = FindRefToCCT(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
							
	ElsIf ObjectTypeName = "ExchangePlan" Then
				
		ObjectRef = FindRefToExchangePlan(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
							
	ElsIf ObjectTypeName = "Task" Then
				
		ObjectRef = FindTaskRef(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
												
	ElsIf ObjectTypeName = "BusinessProcess" Then
				
		ObjectRef = FindRefToBusinessProcess(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
									
	Else
				
		SearchWithQuery = True;
				
	EndIf;
		
	If SearchWithQuery Then
			
		ObjectRef = FindItemUsingRequest(PropertyStructure, TemporarySearchProperties, ObjectType, , RealPropertyForSearchCount);
				
	EndIf;
	
	Return ObjectRef;
	
EndFunction

Procedure ProcessObjectSearchPropertySetting(SetAllObjectSearchProperties, ObjectType, SearchProperties, 
	SearchPropertiesDontReplace, ObjectRef, CreatedObject, WriteNewObjectToInfobase = True, ObjectAttributeChanged = False)
	
	If SetAllObjectSearchProperties <> True Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(ObjectRef) Then
		Return;
	EndIf;
	
	If CreatedObject = Undefined Then
		CreatedObject = ObjectRef.GetObject();
	EndIf;
	
	ObjectAttributeChanged = SetObjectSearchAttributes(CreatedObject, SearchProperties, SearchPropertiesDontReplace);
	
	// Rewriting the object if changes were made.
	If ObjectAttributeChanged
		AND WriteNewObjectToInfobase Then
		
		WriteObjectToIB(CreatedObject, ObjectType);
		
	EndIf;
	
EndProcedure

Function ProcessObjectSearchByStructure(ObjectNumber, ObjectType, CreatedObject,
	MainObjectSearchMode, ObjectPropertyModified, ObjectFound,
	IsGlobalNumber, ObjectParameters)
	
	DataStructure = mNotWrittenObjectGlobalStack[ObjectNumber];
	
	If DataStructure <> Undefined Then
		
		ObjectPropertyModified = True;
		CreatedObject = DataStructure.Object;
		
		If DataStructure.KnownRef = Undefined Then
			
			SetObjectRef(DataStructure);
			
		EndIf;
			
		ObjectRef = DataStructure.KnownRef;
		ObjectParameters = DataStructure.ObjectParameters;
		
		ObjectFound = False;
		
	Else
		
		CreatedObject = Undefined;
		
		If IsGlobalNumber Then
			ObjectRef = FindObjectByGlobalNumber(ObjectNumber, MainObjectSearchMode);
		Else
			ObjectRef = FindObjectByNumber(ObjectNumber, MainObjectSearchMode);
		EndIf;
		
	EndIf;
	
	If ObjectRef <> Undefined Then
		
		If MainObjectSearchMode Then
			
			SearchProperties = "";
			SearchPropertiesDontReplace = "";
			ReadSearchPropertyInfo(ObjectType, SearchProperties, SearchPropertiesDontReplace, , ObjectParameters);
			
			// Verifying search fields.
			If CreatedObject = Undefined Then
				
				CreatedObject = ObjectRef.GetObject();
				
			EndIf;
			
			ObjectPropertyModified = SetObjectSearchAttributes(CreatedObject, SearchProperties, SearchPropertiesDontReplace);
			
		Else
			
			deSkip(ExchangeFile);
			
		EndIf;
		
		Return ObjectRef;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

Procedure ReadSearchPropertyInfo(ObjectType, SearchProperties, SearchPropertiesDontReplace, 
	SearchByEqualDate = False, ObjectParameters = Undefined)
	
	If SearchProperties = "" Then
		SearchProperties = New Map;		
	EndIf;
	
	If SearchPropertiesDontReplace = "" Then
		SearchPropertiesDontReplace = New Map;		
	EndIf;	
	
	TypesInformation = mDataTypeMapForImport[ObjectType];
	ReadSearchPropertiesFromFile(SearchProperties, SearchPropertiesDontReplace, TypesInformation, SearchByEqualDate, ObjectParameters);	
	
EndProcedure

// Searches an object in the infobase and creates a new object, if it is not found.
//
// Parameters:
//  ObjectType - type of the object to be found.
//  SearchProperties - structure with properties to be used for object searching.
//  ObjectFound - False means that the object is not found and a new object is created.
//
// Returns:
//  New or found infobase object.
//  
Function FindObjectByRef(ObjectType,
							OCRName = "",
							SearchProperties = "", 
							SearchPropertiesDontReplace = "", 
							ObjectFound = True, 
							CreatedObject = Undefined, 
							DontCreateObjectIfNotFound = Undefined,
							MainObjectSearchMode = False, 
							ObjectPropertyModified = False,
							GlobalRefSn = 0,
							RefSN = 0,
							KnownUUIDRef = Undefined,
							ObjectParameters = Undefined)

	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ApplicationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	SearchByEqualDate = False;
	ObjectRef = Undefined;
	PropertyStructure = Undefined;
	ObjectTypeName = Undefined;
	IsDocumentObject = False;
	DummyObjectRef = False;
	OCR = Undefined;
	SearchAlgorithm = "";
	
	If RememberImportedObjects Then
		
		// Searching by the serial number if it is available in the file.
		GlobalRefSn = deAttribute(ExchangeFile, deNumberType, "Gsn");
		
		If GlobalRefSn <> 0 Then
			
			ObjectRef = ProcessObjectSearchByStructure(GlobalRefSn, ObjectType, CreatedObject,
				MainObjectSearchMode, ObjectPropertyModified, ObjectFound, True, ObjectParameters);
			
			If ObjectRef <> Undefined Then
				Return ObjectRef;
			EndIf;
			
		EndIf;
		
		// Searching by the serial number if it is available in the file.
		RefSN = deAttribute(ExchangeFile, deNumberType, "Sn");
		
		If RefSN <> 0 Then
		
			ObjectRef = ProcessObjectSearchByStructure(RefSN, ObjectType, CreatedObject,
				MainObjectSearchMode, ObjectPropertyModified, ObjectFound, False, ObjectParameters);
				
			If ObjectRef <> Undefined Then
				Return ObjectRef;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	DontCreateObjectIfNotFound = deAttribute(ExchangeFile, deBooleanType, "DoNotCreateIfNotFound");
	OnExchangeObjectByRefSetGIUDOnly = NOT MainObjectSearchMode 
		AND deAttribute(ExchangeFile, deBooleanType, "OnMoveObjectByRefSetGIUDOnly");
	
	// Creating object search property.
	ReadSearchPropertyInfo(ObjectType, SearchProperties, SearchPropertiesDontReplace, SearchByEqualDate, ObjectParameters);
		
	CreatedObject = Undefined;
	
	If Not ObjectFound Then
		
		ObjectRef = CreateNewObject(ObjectType, SearchProperties, CreatedObject, , , , RefSN, GlobalRefSn);
		AddRefToImportedObjectList(GlobalRefSn, RefSN, ObjectRef);
		Return ObjectRef;
		
	EndIf;	
		
	PropertyStructure   = Managers[ObjectType];
	ObjectTypeName     = PropertyStructure.TypeName;
		
	UUIDProperty = SearchProperties["{UUID}"];
	PredefinedNameProperty = SearchProperties["{PredefinedItemName}"];
	
	OnExchangeObjectByRefSetGIUDOnly = OnExchangeObjectByRefSetGIUDOnly
		AND UUIDProperty <> Undefined;
		
	// Searching by name if the item is predefined.
	If PredefinedNameProperty <> Undefined Then
		
		CreateNewObjectAutomatically = NOT DontCreateObjectIfNotFound
			AND NOT OnExchangeObjectByRefSetGIUDOnly;
		
		ObjectRef = FindOrCreateObjectByProperty(PropertyStructure, ObjectType, SearchProperties, SearchPropertiesDontReplace,
			ObjectTypeName, "{PredefinedItemName}", PredefinedNameProperty, ObjectFound, 
			CreateNewObjectAutomatically, CreatedObject, MainObjectSearchMode, ObjectPropertyModified,
			RefSN, GlobalRefSn, ObjectParameters);
			
	ElsIf (UUIDProperty <> Undefined) Then
			
		// Creating the new item by the unique ID is not always necessary. Perhaps, the search must be continued.
		MustContinueSearchIfItemNotFoundByGUID = GetAdditionalSearchBySearchFieldsUsageByObjectType(PropertyStructure.RefTypeString);
		
		CreateNewObjectAutomatically = (NOT DontCreateObjectIfNotFound
			AND NOT MustContinueSearchIfItemNotFoundByGUID)
			AND NOT OnExchangeObjectByRefSetGIUDOnly;
			
		ObjectRef = FindOrCreateObjectByProperty(PropertyStructure, ObjectType, SearchProperties, SearchPropertiesDontReplace,
			ObjectTypeName, "{UUID}", UUIDProperty, ObjectFound, 
			CreateNewObjectAutomatically, CreatedObject, 
			MainObjectSearchMode, ObjectPropertyModified,
			RefSN, GlobalRefSn, ObjectParameters, KnownUUIDRef);
			
		If Not MustContinueSearchIfItemNotFoundByGUID Then

			If Not ValueIsFilled(ObjectRef)
				AND OnExchangeObjectByRefSetGIUDOnly Then
				
				ObjectRef = PropertyStructure.Manager.GetRef(New UUID(UUIDProperty));
				ObjectFound = False;
				DummyObjectRef = True;
			
			EndIf;
			
			If ObjectRef <> Undefined 
				AND ObjectRef.IsEmpty() Then
						
				ObjectRef = Undefined;
						
			EndIf;
			
			If ObjectRef <> Undefined
				OR CreatedObject <> Undefined Then

				AddRefToImportedObjectList(GlobalRefSn, RefSN, ObjectRef, DummyObjectRef);
				
			EndIf;
			
			Return ObjectRef;	
			
		EndIf;
		
	EndIf;
		
	If ObjectRef <> Undefined 
		AND ObjectRef.IsEmpty() Then
		
		ObjectRef = Undefined;
		
	EndIf;
		
	// ObjectRef is not found yet.
	If ObjectRef <> Undefined
		OR CreatedObject <> Undefined Then
		
		AddRefToImportedObjectList(GlobalRefSn, RefSN, ObjectRef);
		Return ObjectRef;
		
	EndIf;
	
	SearchVariantNumber = 1;
	SearchPropertyNameString = "";
	PreviousSearchString = Undefined;
	StopSearch = False;
	SetAllObjectSearchProperties = True;
	
	If Not IsBlankString(OCRName) Then
		
		OCR = Rules[OCRName];
		
	EndIf;
	
	If OCR = Undefined Then
		
		OCR = GetConversionRuleWithSearchAlgorithmByDestinationObjectType(PropertyStructure.RefTypeString);
		
	EndIf;
	
	If OCR <> Undefined Then
		
		SearchAlgorithm = OCR.SearchFieldSequence;
		
	EndIf;
	
	HasSearchAlgorithm = Not IsBlankString(SearchAlgorithm);
	
	While SearchVariantNumber <= 10
		AND HasSearchAlgorithm Do
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "SearchFieldSequence"));
					
			Else
				
				Execute(SearchAlgorithm);
			
			EndIf;
			
		Except
			
			WriteInfoOnOCRHandlerImportError(73, ErrorDescription(), "", "",
				ObjectType, Undefined, NStr("ru = 'Последовательность полей поиска'; en = 'Search field sequence'; pl = 'Sekwencja pól wyszukiwania';es_ES = 'Secuencia de los campos de búsqueda';es_CO = 'Secuencia de los campos de búsqueda';tr = 'Arama alanlarının dizisi';it = 'La sequenza dei campi di ricerca';de = 'Reihenfolge der Suchfelder'"));
			
		EndTry;
		
		DontSearch = StopSearch = True 
			OR SearchPropertyNameString = PreviousSearchString
			OR ValueIsFilled(ObjectRef);
		
		If NOT DontSearch Then
		
			// The search
			ObjectRef = FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, PropertyStructure, 
				SearchPropertyNameString, SearchByEqualDate);
				
			DontSearch = ValueIsFilled(ObjectRef);
			
			If ObjectRef <> Undefined
				AND ObjectRef.IsEmpty() Then
				ObjectRef = Undefined;
			EndIf;
			
		EndIf;
			
		If DontSearch Then
			
			If MainObjectSearchMode AND SetAllObjectSearchProperties = True Then
				
				ProcessObjectSearchPropertySetting(SetAllObjectSearchProperties, ObjectType, SearchProperties, SearchPropertiesDontReplace,
					ObjectRef, CreatedObject, NOT MainObjectSearchMode, ObjectPropertyModified);
				
			EndIf;
			
			Break;
			
		EndIf;
		
		SearchVariantNumber = SearchVariantNumber + 1;
		PreviousSearchString = SearchPropertyNameString;
		
	EndDo;
	
	If Not HasSearchAlgorithm Then
		
		// The search with no search algorithm.
		ObjectRef = FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, PropertyStructure, 
					SearchPropertyNameString, SearchByEqualDate);
		
	EndIf;
	
	ObjectFound = ValueIsFilled(ObjectRef);
	
	If MainObjectSearchMode
		AND ValueIsFilled(ObjectRef)
		AND (ObjectTypeName = "Document" 
		OR ObjectTypeName = "Task"
		OR ObjectTypeName = "BusinessProcess") Then
		
		// Setting the date if it is in the document search fields.
		EmptyDate = Not ValueIsFilled(SearchProperties["Date"]);
		CanReplace = (Not EmptyDate) 
			AND (SearchPropertiesDontReplace["Date"] = Undefined);
			
		If CanReplace Then
			
			If CreatedObject = Undefined Then
				CreatedObject = ObjectRef.GetObject();
			EndIf;
			
			CreatedObject.Date = SearchProperties["Date"];
			
		EndIf;
		
	EndIf;
	
	// Creating a new object is not always necessary.
	If Not ValueIsFilled(ObjectRef)
		AND CreatedObject = Undefined Then 
		
		If OnExchangeObjectByRefSetGIUDOnly Then
			
			ObjectRef = PropertyStructure.Manager.GetRef(New UUID(UUIDProperty));	
			DummyObjectRef = True;
			
		ElsIf NOT DontCreateObjectIfNotFound Then
		
			ObjectRef = CreateNewObject(ObjectType, SearchProperties, CreatedObject, NOT MainObjectSearchMode, , KnownUUIDRef, RefSN, 
				GlobalRefSn, ,SetAllObjectSearchProperties);
				
			ObjectPropertyModified = True;
				
		EndIf;
			
		ObjectFound = False;
		
	Else
		
		ObjectFound = ValueIsFilled(ObjectRef);
		
	EndIf;
	
	If ObjectRef <> Undefined
		AND ObjectRef.IsEmpty() Then
		
		ObjectRef = Undefined;
		
	EndIf;
	
	AddRefToImportedObjectList(GlobalRefSn, RefSN, ObjectRef, DummyObjectRef);
		
	Return ObjectRef;
	
EndFunction

// Sets object (record) properties.
//
// Parameters:
//  Record         - an object whose properties are set.
//                   For example, a tabular section row or a register record.
//
Procedure SetRecordProperties(Object, Record, TypesInformation,
	ObjectParameters, BranchName, SearchDataInTS, TSCopyForSearch, RecordNumber)
	
	MustSearchInTS = (SearchDataInTS <> Undefined)
								AND (TSCopyForSearch <> Undefined)
								AND TSCopyForSearch.Count() <> 0;
								
	If MustSearchInTS Then
		
		PropertyReadingStructure = New Structure();
		ExtDimensionReadingStructure = New Structure();
		
	EndIf;
		
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Property"
			OR NodeName = "ParameterValue" Then
			
			IsParameter = (NodeName = "ParameterValue");
			
			Name    = deAttribute(ExchangeFile, deStringType, "Name");
			OCRName = deAttribute(ExchangeFile, deStringType, "OCRName");
			
			If Name = "RecordType" AND StrFind(Metadata.FindByType(TypeOf(Record)).FullName(), "AccumulationRegister") Then
				
				PropertyType = deAccumulationRecordTypeType;
				
			Else
				
				PropertyType = GetPropertyTypeByAdditionalData(TypesInformation, Name);
				
			EndIf;
			
			PropertyValue = ReadProperty(PropertyType, OCRName);
			
			If IsParameter Then
				AddComplexParameterIfNecessary(ObjectParameters, BranchName, RecordNumber, Name, PropertyValue);			
			ElsIf MustSearchInTS Then 
				PropertyReadingStructure.Insert(Name, PropertyValue);	
			Else
				
				Try
					
					Record[Name] = PropertyValue;
					
				Except
					
					WP = GetProtocolRecordStructure(26, ErrorDescription());
					WP.OCRName           = OCRName;
					WP.Object           = Object;
					WP.ObjectType       = TypeOf(Object);
					WP.Property         = String(Record) + "." + Name;
					WP.Value         = PropertyValue;
					WP.ValueType      = TypeOf(PropertyValue);
					ErrorMessageString = WriteToExecutionProtocol(26, WP, True);
					
					If Not DebugModeFlag Then
						Raise ErrorMessageString;
					EndIf;
				EndTry;
				
			EndIf;
			
		ElsIf NodeName = "ExtDimensionsDr" OR NodeName = "ExtDimensionsCr" Then
			
			// The search by extra dimensions is not implemented.
			
			varKey = Undefined;
			Value = Undefined;
			
			While ExchangeFile.Read() Do
				
				NodeName = ExchangeFile.LocalName;
								
				If NodeName = "Property" Then
					
					Name    = deAttribute(ExchangeFile, deStringType, "Name");
					OCRName = deAttribute(ExchangeFile, deStringType, "OCRName");
					PropertyType = GetPropertyTypeByAdditionalData(TypesInformation, Name);
										
					If Name = "Key" Then
						
						varKey = ReadProperty(PropertyType);
						
					ElsIf Name = "Value" Then
						
						Value = ReadProperty(PropertyType, OCRName);
						
					EndIf;
					
				ElsIf (NodeName = "ExtDimensionsDr" OR NodeName = "ExtDimensionsCr") AND (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
					
					Break;
					
				Else
					
					WriteToExecutionProtocol(9);
					Break;
					
				EndIf;
				
			EndDo;
			
			If varKey <> Undefined 
				AND Value <> Undefined Then
				
				If NOT MustSearchInTS Then
				
					Record[NodeName][varKey] = Value;
					
				Else
					
					RecordMap = Undefined;
					If NOT ExtDimensionReadingStructure.Property(NodeName, RecordMap) Then
						RecordMap = New Map;
						ExtDimensionReadingStructure.Insert(NodeName, RecordMap);
					EndIf;
					
					RecordMap.Insert(varKey, Value);
					
				EndIf;
				
			EndIf;
				
		ElsIf (NodeName = "Record") AND (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		Else
			
			WriteToExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	If MustSearchInTS Then
		
		SearchStructure = New Structure();
		
		For Each SearchItem In  SearchDataInTS.TSSearchFields Do
			
			ItemValue = Undefined;
			PropertyReadingStructure.Property(SearchItem, ItemValue);
			
			SearchStructure.Insert(SearchItem, ItemValue);		
			
		EndDo;		
		
		SearchResultArray = TSCopyForSearch.FindRows(SearchStructure);
		
		RecordFound = SearchResultArray.Count() > 0;
		If RecordFound Then
			FillPropertyValues(Record, SearchResultArray[0]);
		EndIf;
		
		// Filling with properties and extra dimension value.
		For Each KeyAndValue In PropertyReadingStructure Do
			
			Record[KeyAndValue.Key] = KeyAndValue.Value;
			
		EndDo;
		
		For Each ItemName In ExtDimensionReadingStructure Do
			
			For Each ItemKey In ItemName.Value Do
			
				Record[ItemName.Key][ItemKey.Key] = ItemKey.Value;
				
			EndDo;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Imports an object tabular section.
//
// Parameters:
//  Object         - an object whose tabular section is imported.
//  Name            - tabular section name.
//  Clear       - if True, a tabular section is cleared beforehand.
// 
Procedure ImportTabularSection(Object, Name, Clear, DocumentTypeCommonInformation, NeedToWriteObject, 
	ObjectParameters, Rule)

	TabularSectionName = Name + "TabularSection";
	If DocumentTypeCommonInformation <> Undefined Then
		TypesInformation = DocumentTypeCommonInformation[TabularSectionName];
	Else
	    TypesInformation = Undefined;
	EndIf;
			
	SearchDataInTS = Undefined;
	If Rule <> Undefined Then
		SearchDataInTS = Rule.SearchInTabularSections.Find("TabularSection." + Name, "ItemName");
	EndIf;
	
	TSCopyForSearch = Undefined;
	
	TS = Object[Name];

	If Clear
		AND TS.Count() <> 0 Then
		
		NeedToWriteObject = True;
		
		If SearchDataInTS <> Undefined Then
			TSCopyForSearch = TS.Unload();
		EndIf;
		TS.Clear();
		
	ElsIf SearchDataInTS <> Undefined Then
		
		TSCopyForSearch = TS.Unload();
		
	EndIf;
	
	RecordNumber = 0;
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Record" Then
			Try
				
				NeedToWriteObject = True;
				Record = TS.Add();
				
			Except
				Record = Undefined;
			EndTry;
			
			If Record = Undefined Then
				deSkip(ExchangeFile);
			Else
				SetRecordProperties(Object, Record, TypesInformation, ObjectParameters, TabularSectionName, SearchDataInTS, TSCopyForSearch, RecordNumber);
			EndIf;
			
			RecordNumber = RecordNumber + 1;
			
		ElsIf (NodeName = "TabularSection") AND (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		Else
			
			WriteToExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure 

// Imports object records.
//
// Parameters:
//  Object         - an object whose records are imported.
//  Name - a register name.
//  Clear - if True, register records are cleared beforehand.
// 
Procedure ImportRegisterRecords(Object, Name, Clear, DocumentTypeCommonInformation, NeedToWriteObject, 
	ObjectParameters, Rule)
	
	RegisterRecordName = Name + "RecordSet";
	If DocumentTypeCommonInformation <> Undefined Then
		TypesInformation = DocumentTypeCommonInformation[RegisterRecordName];
	Else
	    TypesInformation = Undefined;
	EndIf;
	
	SearchDataInTS = Undefined;
	If Rule <> Undefined Then
		SearchDataInTS = Rule.SearchInTabularSections.Find("RecordSet." + Name, "ItemName");
	EndIf;
	
	TSCopyForSearch = Undefined;
	
	RegisterRecords = Object.RegisterRecords[Name];
	RegisterRecords.Write = True;
	
	If RegisterRecords.Count()=0 Then
		RegisterRecords.Read();
	EndIf;
	
	If Clear
		AND RegisterRecords.Count() <> 0 Then
		
		NeedToWriteObject = True;
		
		If SearchDataInTS <> Undefined Then 
			TSCopyForSearch = RegisterRecords.Unload();
		EndIf;
		
        RegisterRecords.Clear();
		
	ElsIf SearchDataInTS <> Undefined Then
		
		TSCopyForSearch = RegisterRecords.Unload();	
		
	EndIf;
	
	RecordNumber = 0;
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
			
		If NodeName = "Record" Then
			
			Record = RegisterRecords.Add();
			NeedToWriteObject = True;
			SetRecordProperties(Object, Record, TypesInformation, ObjectParameters, RegisterRecordName, SearchDataInTS, TSCopyForSearch, RecordNumber);
			RecordNumber = RecordNumber + 1;
			
		ElsIf (NodeName = "RecordSet") AND (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		Else
			
			WriteToExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports an object of the TypeDescription type from the specified XML source.
//
// Parameters:
//  Source - an XML source.
// 
Function ImportObjectTypes(Source)
	
	// DateQualifiers
	
	DateComposition =  deAttribute(Source, deStringType,  "DateComposition");
	
	// КвалификаторыСтроки
	
	Length           =  deAttribute(Source, deNumberType,  "Length");
	AllowedLength =  deAttribute(Source, deStringType, "AllowedLength");
	
	// NumberQualifiers
	
	NumberOfDigits             = deAttribute(Source, deNumberType,  "Digits");
	DigitsInFractionalPart = deAttribute(Source, deNumberType,  "FractionDigits");
	AllowedFlag          = deAttribute(Source, deStringType, "AllowedSign");
	
	// Reading the array of types
	
	TypesArray = New Array;
	
	While Source.Read() Do
		NodeName = Source.LocalName;
		
		If      NodeName = "Type" Then
			TypesArray.Add(Type(deElementValue(Source, deStringType)));
		ElsIf (NodeName = "Types") AND ( Source.NodeType = deXMLNodeType_EndElement) Then
			Break;
		Else
			WriteToExecutionProtocol(9);
			Break;
		EndIf;
		
	EndDo;
	
	If TypesArray.Count() > 0 Then
		
		// DateQualifiers
		
		If DateComposition = "Date" Then
			DateQualifiers   = New DateQualifiers(DateFractions.Date);
		ElsIf DateComposition = "DateTime" Then
			DateQualifiers   = New DateQualifiers(DateFractions.DateTime);
		ElsIf DateComposition = "Time" Then
			DateQualifiers   = New DateQualifiers(DateFractions.Time);
		Else
			DateQualifiers   = New DateQualifiers(DateFractions.DateTime);
		EndIf;
		
		// NumberQualifiers
		
		If NumberOfDigits > 0 Then
			If AllowedFlag = "Nonnegative" Then
				Sign = AllowedSign.Nonnegative;
			Else
				Sign = AllowedSign.Any;
			EndIf; 
			NumberQualifiers  = New NumberQualifiers(NumberOfDigits, DigitsInFractionalPart, Sign);
		Else
			NumberQualifiers  = New NumberQualifiers();
		EndIf;
		
		// КвалификаторыСтроки
		
		If Length > 0 Then
			If AllowedLength = "Fixed" Then
				AllowedLength = AllowedLength.Fixed;
			Else
				AllowedLength = AllowedLength.Variable;
			EndIf;
			КвалификаторыСтроки = New StringQualifiers(Length, AllowedLength);
		Else
			КвалификаторыСтроки = New StringQualifiers();
		EndIf;
		
		Return New TypeDescription(TypesArray, NumberQualifiers, КвалификаторыСтроки, DateQualifiers);
	EndIf;
	
	Return Undefined;
	
EndFunction

Procedure SetObjectDeletionMark(Object, DeletionMark, ObjectTypeName)
	
	If (DeletionMark = Undefined)
		AND (Object.DeletionMark <> True) Then
		
		Return;
		
	EndIf;
	
	MarkToSet = ?(DeletionMark <> Undefined, DeletionMark, False);
	
	SetDataExchangeLoad(Object);
		
	// For hierarchical object the deletion mark is set only for the current object.
	If ObjectTypeName = "Catalog"
		OR ObjectTypeName = "ChartOfCharacteristicTypes"
		OR ObjectTypeName = "ChartOfAccounts" Then
			
		Object.SetDeletionMark(MarkToSet, False);
			
	Else	
		
		Object.SetDeletionMark(MarkToSet);
		
	EndIf;
	
EndProcedure

Procedure WriteDocumentInSafeMode(Document, ObjectType)
	
	If Document.Posted Then
						
		Document.Posted = False;
			
	EndIf;		
								
	WriteObjectToIB(Document, ObjectType);
	
EndProcedure

Function GetObjectByRefAndAdditionalInformation(CreatedObject, Ref)
	
	// If you have created an object, work with it, if you have found an object, receive it.
	If CreatedObject <> Undefined Then
		Object = CreatedObject;
	Else
		If Ref.IsEmpty() Then
			Object = Undefined;
		Else
			Object = Ref.GetObject();
		EndIf;		
	EndIf;
	
	Return Object;
	
EndFunction

Procedure ObjectImportComments(SN, RuleName, Source, ObjectType, GSN = 0)
	
	If CommentObjectProcessingFlag Then
		
		If SN <> 0 Then
			MessageString = SubstituteParametersToString(NStr("ru = 'Загрузка объекта № %1'; en = 'Importing object #%1'; pl = 'Pobieranie obiektu nr %1';es_ES = 'Carga del objeto № %1';es_CO = 'Carga del objeto № %1';tr = '%1 sayılı nesneyi içe aktar';it = 'Importazione oggetto #%1';de = 'Import von Objektnummer %1'"), SN);
		Else
			MessageString = SubstituteParametersToString(NStr("ru = 'Загрузка объекта № %1'; en = 'Importing object #%1'; pl = 'Pobieranie obiektu nr %1';es_ES = 'Carga del objeto № %1';es_CO = 'Carga del objeto № %1';tr = '%1 sayılı nesneyi içe aktar';it = 'Importazione oggetto #%1';de = 'Import von Objektnummer %1'"), GSN);
		EndIf;
		
		WP = GetProtocolRecordStructure();
		
		If Not IsBlankString(RuleName) Then
			
			WP.OCRName = RuleName;
			
		EndIf;
		
		If Not IsBlankString(Source) Then
			
			WP.Source = Source;
			
		EndIf;
		
		WP.ObjectType = ObjectType;
		WriteToExecutionProtocol(MessageString, WP, False);
		
	EndIf;	
	
EndProcedure

Procedure AddParameterIfNecessary(DataParameters, ParameterName, ParameterValue)
	
	If DataParameters = Undefined Then
		DataParameters = New Map;
	EndIf;
	
	DataParameters.Insert(ParameterName, ParameterValue);
	
EndProcedure

Procedure AddComplexParameterIfNecessary(DataParameters, ParameterBranchName, RowNumber, ParameterName, ParameterValue)
	
	If DataParameters = Undefined Then
		DataParameters = New Map;
	EndIf;
	
	CurrentParameterData = DataParameters[ParameterBranchName];
	
	If CurrentParameterData = Undefined Then
		
		CurrentParameterData = New ValueTable;
		CurrentParameterData.Columns.Add("LineNumber");
		CurrentParameterData.Columns.Add("ParameterName");
		CurrentParameterData.Indexes.Add("LineNumber");
		
		DataParameters.Insert(ParameterBranchName, CurrentParameterData);	
		
	EndIf;
	
	If CurrentParameterData.Columns.Find(ParameterName) = Undefined Then
		CurrentParameterData.Columns.Add(ParameterName);
	EndIf;		
	
	RowData = CurrentParameterData.Find(RowNumber, "LineNumber");
	If RowData = Undefined Then
		RowData = CurrentParameterData.Add();
		RowData.LineNumber = RowNumber;
	EndIf;		
	
	RowData[ParameterName] = ParameterValue;
	
EndProcedure

Procedure SetObjectRef(NotWrittenObjectStackRow)
	
	// The is not written yet but need a reference.
	ObjectToWrite = NotWrittenObjectStackRow.Object;
	
	MDProperties      = Managers[NotWrittenObjectStackRow.ObjectType];
	Manager        = MDProperties.Manager;
		
	NewUUID = New UUID;
	NewRef = Manager.GetRef(NewUUID);
		
	ObjectToWrite.SetNewObjectRef(NewRef);
	NotWrittenObjectStackRow.KnownRef = NewRef;
	
EndProcedure

Procedure SupplementNotWrittenObjectStack(SN, GSN, Object, KnownRef, ObjectType, ObjectParameters)
	
	NumberForStack = ?(SN = 0, GSN, SN);
	
	StackString = mNotWrittenObjectGlobalStack[NumberForStack];
	If StackString <> Undefined Then
		Return;
	EndIf;
	ParametersStructure = New Structure();
	ParametersStructure.Insert("Object", Object);
	ParametersStructure.Insert("KnownRef", KnownRef);
	ParametersStructure.Insert("ObjectType", ObjectType);
	ParametersStructure.Insert("ObjectParameters", ObjectParameters);

	mNotWrittenObjectGlobalStack.Insert(NumberForStack, ParametersStructure);
	
EndProcedure

Procedure DeleteFromNotWrittenObjectStack(SN, GSN)
	
	NumberForStack = ?(SN = 0, GSN, SN);
	StackString = mNotWrittenObjectGlobalStack[NumberForStack];
	If StackString = Undefined Then
		Return;
	EndIf;
	
	mNotWrittenObjectGlobalStack.Delete(NumberForStack);	
	
EndProcedure

Procedure ExecuteWriteNotWrittenObjects()
	
	If mNotWrittenObjectGlobalStack = Undefined Then
		Return;
	EndIf;
	
	For Each DataString In mNotWrittenObjectGlobalStack Do
		
		// Deferred objects writing
		Object = DataString.Value.Object;
		RefSN = DataString.Key;
		
		WriteObjectToIB(Object, DataString.Value.ObjectType);
		
		AddRefToImportedObjectList(0, RefSN, Object.Ref);
		
	EndDo;
	
	mNotWrittenObjectGlobalStack.Clear();
	
EndProcedure

Procedure ExecuteNumberCodeGenerationIfNecessary(GenerateNewNumberOrCodeIfNotSet, Object, ObjectTypeName, NeedToWriteObject, 
	DataExchangeMode)
	
	If Not GenerateNewNumberOrCodeIfNotSet
		OR NOT DataExchangeMode Then
		
		// If the number does not need to be generated, or generated not in the data exchange mode, then 
		// nothing needs to be done. The platform will generate everything itself.
		Return;
	EndIf;
	
	// Checking whether the code or number are filled (depends on the object type).
	If ObjectTypeName = "Document"
		OR ObjectTypeName =  "BusinessProcess"
		OR ObjectTypeName = "Task" Then
		
		If NOT ValueIsFilled(Object.Number) Then
			
			Object.SetNewNumber();
			NeedToWriteObject = True;
			
		EndIf;
		
	ElsIf ObjectTypeName = "Catalog"
		OR ObjectTypeName = "ChartOfCharacteristicTypes"
		OR ObjectTypeName = "ExchangePlan" Then
		
		If NOT ValueIsFilled(Object.Code) Then
			
			Object.SetNewCode();
			NeedToWriteObject = True;
			
		EndIf;	
		
	EndIf;
	
EndProcedure

// Reads the next object from the exchange file and imports it.
//
// Parameters:
//  No.
// 
Function ReadObject()

	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ApplicationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	SN						= deAttribute(ExchangeFile, deNumberType,  "Sn");
	GSN					= deAttribute(ExchangeFile, deNumberType,  "Gsn");
	Source				= deAttribute(ExchangeFile, deStringType, "Source");
	RuleName				= deAttribute(ExchangeFile, deStringType, "RuleName");
	DontReplaceObject 		= deAttribute(ExchangeFile, deBooleanType, "DoNotReplace");
	AutonumberingPrefix	= deAttribute(ExchangeFile, deStringType, "AutonumberingPrefix");
	ObjectTypeString       = deAttribute(ExchangeFile, deStringType, "Type");
	ObjectType 				= Type(ObjectTypeString);
	TypesInformation = mDataTypeMapForImport[ObjectType];

	ObjectImportComments(SN, RuleName, Source, ObjectType, GSN);    
	
	PropertyStructure = Managers[ObjectType];
	ObjectTypeName   = PropertyStructure.TypeName;

	If ObjectTypeName = "Document" Then
		
		WriteMode     = deAttribute(ExchangeFile, deStringType, "WriteMode");
		PostingMode = deAttribute(ExchangeFile, deStringType, "PostingMode");
		
	EndIf;	
	
	Ref          = Undefined;
	Object          = Undefined;
	ObjectFound    = True;
	DeletionMark = Undefined;
	
	SearchProperties  = New Map;
	SearchPropertiesDontReplace  = New Map;
	
	NeedToWriteObject = NOT WriteToInfobaseOnlyChangedObjects;
	


	If Not IsBlankString(RuleName) Then
		
		Rule = Rules[RuleName];
		HasBeforeImportHandler = Rule.HasBeforeImportHandler;
		HasOnImportHandler    = Rule.HasOnImportHandler;
		HasAfterImportHandler  = Rule.HasAfterImportHandler;
		GenerateNewNumberOrCodeIfNotSet = Rule.GenerateNewNumberOrCodeIfNotSet;
		
	Else
		
		HasBeforeImportHandler = False;
		HasOnImportHandler    = False;
		HasAfterImportHandler  = False;
		GenerateNewNumberOrCodeIfNotSet = False;
		
	EndIf;


    // BeforeImportObject global event handler.
	If HasBeforeImportObjectGlobalHandler Then
		
		Cancel = False;
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "BeforeImportObject"));
				
			Else
				
				Execute(Conversion.BeforeImportObject);
				
			EndIf;
			
		Except
			
			WriteInfoOnOCRHandlerImportError(53, ErrorDescription(), RuleName, Source,
				ObjectType, Undefined, NStr("ru = 'BeforeImportObject (глобальный)'; en = 'BeforeImportObject (global)'; pl = 'BeforeImportObject (globalny)';es_ES = 'BeforeObjectImport (global)';es_CO = 'BeforeObjectImport (global)';tr = 'BeforeImportObject (global)';it = 'BeforeImportObject (global)';de = 'VorDemObjektimport (global)'"));
							
		EndTry;
						
		If Cancel Then	//	Canceling the object import
			
			deSkip(ExchangeFile, "Object");
			Return Undefined;
			
		EndIf;
		
	EndIf;
	
	
    // BeforeImportObject event handler.
	If HasBeforeImportHandler Then
		
		Cancel = False;
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeImport"));
				
			Else
				
				Execute(Rule.BeforeImport);
				
			EndIf;
			
		Except
			
			WriteInfoOnOCRHandlerImportError(19, ErrorDescription(), RuleName, Source,
				ObjectType, Undefined, "BeforeImportObject");
			
		EndTry;
		
		If Cancel Then // Canceling the object import
			
			deSkip(ExchangeFile, "Object");
			Return Undefined;
			
		EndIf;
		
	EndIf;
	
	ObjectPropertyModified = False;
	RecordSet = Undefined;
	GlobalRefSn = 0;
	RefSN = 0;
	ObjectParameters = Undefined;
		
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
				
		If NodeName = "Property"
			OR NodeName = "ParameterValue" Then
			
			IsParameterForObject = (NodeName = "ParameterValue");
			
			If NOT IsParameterForObject
				AND Object = Undefined Then
				
				// The object was not found and was not created, attempting to do it now.
				ObjectFound = False;

			    // OnImportObject event handler.
				If HasOnImportHandler Then
					
					// Rewriting the object if OnImporthandler exists, because of possible changes.
					WriteObjectWasRequired = NeedToWriteObject;
      				ObjectIsModified = True;
										
					Try
						
						If HandlersDebugModeFlag Then
							
							Execute(GetHandlerCallString(Rule, "OnImport"));
							
						Else
							
							Execute(Rule.OnImport);
						
						EndIf;
						NeedToWriteObject = ObjectIsModified OR WriteObjectWasRequired;
						
					Except
						
						WriteInfoOnOCRHandlerImportError(20, ErrorDescription(), RuleName, Source,
							ObjectType, Object, "OnImportObject");
						
					EndTry;
					
				EndIf;

				// Failed to create the object in the event, creating it separately.
				If Object = Undefined Then
					
					NeedToWriteObject = True;
					
					If ObjectTypeName = "Constants" Then
						
						Object = Constants.CreateSet();
						Object.Read();
						
					Else
						
						CreateNewObject(ObjectType, SearchProperties, Object, False, RecordSet, , RefSN, GlobalRefSn, ObjectParameters);
												
					EndIf;
					
				EndIf;
				
			EndIf;
			
			Name                = deAttribute(ExchangeFile, deStringType, "Name");
			DontReplaceProperty = deAttribute(ExchangeFile, deBooleanType, "DoNotReplace");
			OCRName             = deAttribute(ExchangeFile, deStringType, "OCRName");
			
			If NOT IsParameterForObject
				AND ((ObjectFound AND DontReplaceProperty) 
				OR (Name = "IsFolder")
				OR (Object[Name] = NULL)) Then
				
				// Unknown property
				deSkip(ExchangeFile, NodeName);
				Continue;
				
			EndIf; 

			
			// Reading and setting the property value.
			PropertyType = GetPropertyTypeByAdditionalData(TypesInformation, Name);
			Value    = ReadProperty(PropertyType, OCRName);
			
			If IsParameterForObject Then
				
				// Supplementing the object parameter collection.
				AddParameterIfNecessary(ObjectParameters, Name, Value);
				
			Else
			
				If Name = "DeletionMark" Then
					
					DeletionMark = Value;
					
					If Object.DeletionMark <> DeletionMark Then
						Object.DeletionMark = DeletionMark;
						NeedToWriteObject = True;
					EndIf;
										
				Else
					
					Try
						
						If Not NeedToWriteObject Then
							
							NeedToWriteObject = (Object[Name] <> Value);
							
						EndIf;
						
						Object[Name] = Value;
						
					Except
						
						WP = GetProtocolRecordStructure(26, ErrorDescription());
						WP.OCRName           = RuleName;
						WP.Sn              = SN;
						WP.Gsn             = GSN;
						WP.Source         = Source;
						WP.Object           = Object;
						WP.ObjectType       = ObjectType;
						WP.Property         = Name;
						WP.Value         = Value;
						WP.ValueType      = TypeOf(Value);
						ErrorMessageString = WriteToExecutionProtocol(26, WP, True);
						
						If Not DebugModeFlag Then
							Raise ErrorMessageString;
						EndIf;
						
					EndTry;					
									
				EndIf;
				
			EndIf;
			
		ElsIf NodeName = "Ref" Then
			
			// Reference to item. First receiving an object by reference, and then setting properties.
			CreatedObject = Undefined;
			DontCreateObjectIfNotFound = Undefined;
			KnownUUIDRef = Undefined;
			
			Ref = FindObjectByRef(ObjectType,
								RuleName, 
								SearchProperties,
								SearchPropertiesDontReplace,
								ObjectFound,
								CreatedObject,
								DontCreateObjectIfNotFound,
								True,
								ObjectPropertyModified,
								GlobalRefSn,
								RefSN,
								KnownUUIDRef,
								ObjectParameters);
			
			NeedToWriteObject = NeedToWriteObject OR ObjectPropertyModified;
			
			If Ref = Undefined
				AND DontCreateObjectIfNotFound = True Then
				
				deSkip(ExchangeFile, "Object");
				Break;
			
			ElsIf ObjectTypeName = "Enum" Then
				
				Object = Ref;
			
			Else
				
				Object = GetObjectByRefAndAdditionalInformation(CreatedObject, Ref);
				
				If ObjectFound AND DontReplaceObject AND (Not HasOnImportHandler) Then
					
					deSkip(ExchangeFile, "Object");
					Break;
					
				EndIf;
				
				If Ref = Undefined Then
					
					SupplementNotWrittenObjectStack(SN, GSN, CreatedObject, KnownUUIDRef, ObjectType, ObjectParameters);
					
				EndIf;
							
			EndIf; 
			
		    // OnImportObject event handler.
			If HasOnImportHandler Then
				
				WriteObjectWasRequired = NeedToWriteObject;
      			ObjectIsModified = True;
				
				Try
					
					If HandlersDebugModeFlag Then
						
						Execute(GetHandlerCallString(Rule, "OnImport"));
						
					Else
						
						Execute(Rule.OnImport);
						
					EndIf;
					
					NeedToWriteObject = ObjectIsModified OR WriteObjectWasRequired;
					
				Except
					DeleteFromNotWrittenObjectStack(SN, GSN);
					WriteInfoOnOCRHandlerImportError(20, ErrorDescription(), RuleName, Source, 
							ObjectType, Object, "OnImportObject");
					
				EndTry;
				
				If ObjectFound AND DontReplaceObject Then
					
					deSkip(ExchangeFile, "Object");
					Break;
					
				EndIf;
				
			EndIf;
			
		ElsIf NodeName = "TabularSection"
			OR NodeName = "RecordSet" Then

			If Object = Undefined Then
				
				ObjectFound = False;

			    // OnImportObject event handler.
				
				If HasOnImportHandler Then
					
					WriteObjectWasRequired = NeedToWriteObject;
      				ObjectIsModified = True;
					
					Try
						
						If HandlersDebugModeFlag Then
							
							Execute(GetHandlerCallString(Rule, "OnImport"));
							
						Else
							
							Execute(Rule.OnImport);
							
						EndIf;
						
						NeedToWriteObject = ObjectIsModified OR WriteObjectWasRequired;
						
					Except
						DeleteFromNotWrittenObjectStack(SN, GSN);
						WriteInfoOnOCRHandlerImportError(20, ErrorDescription(), RuleName, Source, 
							ObjectType, Object, "OnImportObject");
						
					EndTry;
					
				EndIf;
				
			EndIf;
			
			Name                = deAttribute(ExchangeFile, deStringType, "Name");
			DontReplaceProperty = deAttribute(ExchangeFile, deBooleanType, "DoNotReplace");
			DontClear          = deAttribute(ExchangeFile, deBooleanType, "DoNotClear");

			If ObjectFound AND DontReplaceProperty Then
				
				deSkip(ExchangeFile, NodeName);
				Continue;
				
			EndIf;
			
			If Object = Undefined Then
					
				CreateNewObject(ObjectType, SearchProperties, Object, False, RecordSet, , RefSN, GlobalRefSn, ObjectParameters);
				NeedToWriteObject = True;
									
			EndIf;
			
			If NodeName = "TabularSection" Then
				
				// Importing items from the tabular section
				ImportTabularSection(Object, Name, Not DontClear, TypesInformation, NeedToWriteObject, ObjectParameters, Rule);
				
			ElsIf NodeName = "RecordSet" Then
				
				// Importing register
				ImportRegisterRecords(Object, Name, Not DontClear, TypesInformation, NeedToWriteObject, ObjectParameters, Rule);
				
			EndIf;			
			
		ElsIf (NodeName = "Object") AND (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
			
			Cancel = False;
			
		    // AfterImportObject global event handler.
			If HasAfterImportObjectGlobalHandler Then
				
				WriteObjectWasRequired = NeedToWriteObject;
      			ObjectIsModified = True;
				
				Try
					
					If HandlersDebugModeFlag Then
						
						Execute(GetHandlerCallString(Conversion, "AfterImportObject"));
						
					Else
						
						Execute(Conversion.AfterImportObject);
						
					EndIf;
					
					NeedToWriteObject = ObjectIsModified OR WriteObjectWasRequired;
					
				Except
					DeleteFromNotWrittenObjectStack(SN, GSN);
					WriteInfoOnOCRHandlerImportError(54, ErrorDescription(), RuleName, Source,
							ObjectType, Object, NStr("ru = 'AfterImportObject (глобальный)'; en = 'AfterImportObject (global)'; pl = 'AfterImportObject (globalny)';es_ES = 'AftertObjectImport (global)';es_CO = 'AftertObjectImport (global)';tr = 'AfterImportObject (global)';it = 'AfterImportObject (global)';de = 'NachDemObjektimport (global)'"));
					
				EndTry;
				
			EndIf;
			
			// AfterImportObject event handler.
			If HasAfterImportHandler Then
				
				WriteObjectWasRequired = NeedToWriteObject;
				ObjectIsModified = True;
				
				Try
					
					If HandlersDebugModeFlag Then
						
						Execute(GetHandlerCallString(Rule, "AfterImport"));
						
					Else
						
						Execute(Rule.AfterImport);
				
					EndIf;
					
					NeedToWriteObject = ObjectIsModified OR WriteObjectWasRequired;
					
				Except
					DeleteFromNotWrittenObjectStack(SN, GSN);
					WriteInfoOnOCRHandlerImportError(21, ErrorDescription(), RuleName, Source,
												ObjectType, Object, "AfterImportObject");
						
				EndTry;
				
			EndIf;
			
			If ObjectTypeName <> "InformationRegister"
				AND ObjectTypeName <> "Constants"
				AND ObjectTypeName <> "Enum" Then
				// Checking the restriction date for all objects except for information registers and constants.
				Cancel = Cancel Or DisableDataChangeByDate(Object);
			EndIf;
			
			If Cancel Then
				
				AddRefToImportedObjectList(GlobalRefSn, RefSN, Undefined);
				DeleteFromNotWrittenObjectStack(SN, GSN);
				Return Undefined;
				
			EndIf;
			
			If ObjectTypeName = "Document" Then
				
				If WriteMode = "Posting" Then
					
					WriteMode = DocumentWriteMode.Posting;
					
				Else
					
					WriteMode = ?(WriteMode = "UndoPosting", DocumentWriteMode.UndoPosting, DocumentWriteMode.Write);
					
				EndIf;
				
				
				PostingMode = ?(PostingMode = "RealTime", DocumentPostingMode.RealTime, DocumentPostingMode.Regular);
				

				// Clearing the deletion mark to post the marked for deletion object.
				If Object.DeletionMark
					AND (WriteMode = DocumentWriteMode.Posting) Then
					
					Object.DeletionMark = False;
					NeedToWriteObject = True;
					
					// The deletion mark is deleted anyway.
					DeletionMark = False;
									
				EndIf;				
				
				Try
					
					NeedToWriteObject = NeedToWriteObject OR (WriteMode <> DocumentWriteMode.Write);
					
					DataExchangeMode = WriteMode = DocumentWriteMode.Write;
					
					ExecuteNumberCodeGenerationIfNecessary(GenerateNewNumberOrCodeIfNotSet, Object, 
						ObjectTypeName, NeedToWriteObject, DataExchangeMode);
					
					If NeedToWriteObject Then
					
						SetDataExchangeLoad(Object, DataExchangeMode);
						If Object.Posted Then
							Object.DeletionMark = False;
						EndIf;
						
						Object.Write(WriteMode, PostingMode);
						
					EndIf;					
						
				Except
						
					// Failed to execute actions required for the document.
					WriteDocumentInSafeMode(Object, ObjectType);
						
						
					WP                        = GetProtocolRecordStructure(25, ErrorDescription());
					WP.OCRName                 = RuleName;
						
					If Not IsBlankString(Source) Then
							
						WP.Source           = Source;
							
					EndIf;
						
					WP.ObjectType             = ObjectType;
					WP.Object                 = String(Object);
					WriteToExecutionProtocol(25, WP);
						
				EndTry;
				
				AddRefToImportedObjectList(GlobalRefSn, RefSN, Object.Ref);
									
				DeleteFromNotWrittenObjectStack(SN, GSN);
				
			ElsIf ObjectTypeName <> "Enum" Then
				
				If ObjectTypeName = "InformationRegister" Then
					
					NeedToWriteObject = NOT WriteToInfobaseOnlyChangedObjects;
					
					If PropertyStructure.Periodic 
						AND Not ValueIsFilled(Object.Period) Then
						
						Object.Period = CurrentSessionDate();
						NeedToWriteObject = True;							
												
					EndIf;
					
					If WriteRegistersAsRecordSets Then
						
						MustCheckDataForTempSet = 
							(WriteToInfobaseOnlyChangedObjects
								AND NOT NeedToWriteObject) 
							OR DontReplaceObject;
						
						If MustCheckDataForTempSet Then
							
							TemporaryRecordSet = InformationRegisters[PropertyStructure.Name].CreateRecordSet();
							
						EndIf;
						
						// The register requires the filter to be set.
						For Each FilterItem In RecordSet.Filter Do
							
							FilterItem.Set(Object[FilterItem.Name]);
							If MustCheckDataForTempSet Then
								TemporaryRecordSet.Filter[FilterItem.Name].Set(Object[FilterItem.Name]);
							EndIf;
							
						EndDo;
						
						If MustCheckDataForTempSet Then
							
							TemporaryRecordSet.Read();
							
							If TemporaryRecordSet.Count() = 0 Then
								NeedToWriteObject = True;
							Else
								
								// Existing set is not be replaced.
								If DontReplaceObject Then
									Return Undefined;
								EndIf;
								
								NeedToWriteObject = False;
								NewTable = RecordSet.Unload();
								TableOld = TemporaryRecordSet.Unload(); 
								
								RowNew = NewTable[0]; 
								OldRow = TableOld[0]; 
								
								For Each TableColumn In NewTable.Columns Do
									
									NeedToWriteObject = RowNew[TableColumn.Name] <>  OldRow[TableColumn.Name];
									If NeedToWriteObject Then
										Break;
									EndIf;
									
								EndDo;
								
							EndIf;
							
						EndIf;
						
						Object = RecordSet;
						
						If PropertyStructure.Periodic Then
							// Checking the change restriction date for a record set.
							// If it does not pass, do not write the set.
							If DisableDataChangeByDate(Object) Then
								Return Undefined;
							EndIf;
						EndIf;
						
					Else
						
						// Checking whether the current record set must be replaced.
						If DontReplaceObject Or PropertyStructure.Periodic Then
							
							// Probably we do not want to replace the existing record or need a check by the date of restriction.
							TemporaryRecordSet = InformationRegisters[PropertyStructure.Name].CreateRecordSet();
							
							// The register requires the filter to be set.
							For Each FilterItem In TemporaryRecordSet.Filter Do
							
								FilterItem.Set(Object[FilterItem.Name]);
																
							EndDo;
							
							TemporaryRecordSet.Read();
							
							If TemporaryRecordSet.Count() > 0
								Or DisableDataChangeByDate(TemporaryRecordSet) Then
								Return Undefined;
							EndIf;
							
						Else
							// We consider that the object needs to be recorded.
							NeedToWriteObject = True;
						EndIf;
						
					EndIf;
					
				EndIf;
				
				IsReferenceObjectType = NOT( ObjectTypeName = "InformationRegister"
					OR ObjectTypeName = "Constants"
					OR ObjectTypeName = "Enum");
					
				If IsReferenceObjectType Then 	
					
					ExecuteNumberCodeGenerationIfNecessary(GenerateNewNumberOrCodeIfNotSet, Object, ObjectTypeName, NeedToWriteObject, ImportDataInExchangeMode);
					
					If DeletionMark = Undefined Then
						DeletionMark = False;
					EndIf;
					
					If Object.DeletionMark <> DeletionMark Then
						Object.DeletionMark = DeletionMark;
						NeedToWriteObject = True;
					EndIf;
					
				EndIf;
				
				// Writing the object directly.
				If NeedToWriteObject Then
				
					WriteObjectToIB(Object, ObjectType);
					
				EndIf;
				
				If IsReferenceObjectType Then
					
					AddRefToImportedObjectList(GlobalRefSn, RefSN, Object.Ref);
					
				EndIf;
				
				DeleteFromNotWrittenObjectStack(SN, GSN);
								
			EndIf;
			
			Break;
			
		ElsIf NodeName = "SequenceRecordSet" Then
			
			deSkip(ExchangeFile);
			
		ElsIf NodeName = "Types" Then

			If Object = Undefined Then
				
				ObjectFound = False;
				Ref       = CreateNewObject(ObjectType, SearchProperties, Object, , , , RefSN, GlobalRefSn, ObjectParameters);
								
			EndIf; 

			ObjectTypesDetails = ImportObjectTypes(ExchangeFile);

			If ObjectTypesDetails <> Undefined Then
				
				Object.ValueType = ObjectTypesDetails;
				
			EndIf; 
			
		Else
			
			WriteToExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	Return Object;

EndFunction

// Checks whether the import restriction by date is enabled.
//
// Parameters:
//   DataElement	  - CatalogObject, DocumentObject, InformationRegisterRecordSet and other data.
//                      Data that is read from the exchange message but is not yet written to the infobase.
//   GetItem - GetDataItem.
//
// Returns:
//   Boolean - True - change restriction date is set and the object to import has date that is less than the set one, else False.
//
Function DisableDataChangeByDate(DataItem)
	
	DataChangesDenied = False;
	
	If ModulePeriodClosingDates <> Undefined
		AND Not Metadata.Constants.Contains(DataItem.Metadata()) Then
		Try
			If ModulePeriodClosingDates.DataChangesDenied(DataItem) Then
				DataChangesDenied = True;
			EndIf;
		Except
			DataChangesDenied = False;
		EndTry;
	EndIf;
	
	DataItem.AdditionalProperties.Insert("SkipPeriodClosingCheck");
	
	Return DataChangesDenied;
	
EndFunction

Function CheckRefExists(Ref, Manager, FoundByUUIDObject,
	SearchByUUIDQueryString)
	
	Try
			
		If IsBlankString(SearchByUUIDQueryString) Then
			
			FoundByUUIDObject = Ref.GetObject();
			
			If FoundByUUIDObject = Undefined Then
			
				Return Manager.EmptyRef();
				
			EndIf;
			
		Else
			// It is the Search by reference mode - It is enough to execute a query by the following pattern: 
			// PropertiesStructure.SearchString.
			
			Query = New Query();
			Query.Text = SearchByUUIDQueryString + "  Ref = &Ref ";
			Query.SetParameter("Ref", Ref);
			
			QueryResult = Query.Execute();
			
			If QueryResult.IsEmpty() Then
			
				Return Manager.EmptyRef();
				
			EndIf;
			
		EndIf;
		
		Return Ref;	
		
	Except
			
		Return Manager.EmptyRef();
		
	EndTry;
	
EndFunction

Function EvalExpression(Val Expression)
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ApplicationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	// You do not need to call the CalculateInSafeMode because the safe mode is set without using SSL.
	Return Eval(Expression);
	
EndFunction

#EndRegion

#Region DataExportProcedures

Function GetDocumentRegisterRecordSet(DocumentRefSSL, SourceKind, RegisterName)
	
	If SourceKind = "AccumulationRegisterRecordSet" Then
		
		DocumentRegisterRecordSet = AccumulationRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "InformationRegisterRecordSet" Then
		
		DocumentRegisterRecordSet = InformationRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "AccountingRegisterRecordSet" Then
		
		DocumentRegisterRecordSet = AccountingRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "CalculationRegisterRecordSet" Then	
		
		DocumentRegisterRecordSet = CalculationRegisters[RegisterName].CreateRecordSet();
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	DocumentRegisterRecordSet.Filter.Recorder.Set(DocumentRefSSL);
	DocumentRegisterRecordSet.Read();
	
	Return DocumentRegisterRecordSet;
	
EndFunction

Procedure WriteStructureToXML(DataStructure, PropertyCollectionNode)
	
	PropertyCollectionNode.WriteStartElement("Property");
	
	For Each CollectionItem In DataStructure Do
		
		If CollectionItem.Key = "Expression"
			OR CollectionItem.Key = "Value"
			OR CollectionItem.Key = "Sn"
			OR CollectionItem.Key = "Gsn" Then
			
			deWriteElement(PropertyCollectionNode, CollectionItem.Key, CollectionItem.Value);
			
		ElsIf CollectionItem.Key = "Ref" Then
			
			PropertyCollectionNode.WriteRaw(CollectionItem.Value);
			
		Else
			
			SetAttribute(PropertyCollectionNode, CollectionItem.Key, CollectionItem.Value);
			
		EndIf;
		
	EndDo;
	
	PropertyCollectionNode.WriteEndElement();		
	
EndProcedure

Procedure CreateObjectsForXMLWriter(DataStructure, PropertyNode, XMLNodeRequired, NodeName, XMLNodeDescription = "Property")
	
	If XMLNodeRequired Then
		
		PropertyNode = CreateNode(XMLNodeDescription);
		SetAttribute(PropertyNode, "Name", NodeName);
		
	Else
		
		DataStructure = New Structure("Name", NodeName);	
		
	EndIf;		
	
EndProcedure

Procedure AddAttributeForXMLWriter(PropertyNodeStructure, PropertyNode, AttributeName, AttributeValue)
	
	If PropertyNodeStructure <> Undefined Then
		PropertyNodeStructure.Insert(AttributeName, AttributeValue);
	Else
		SetAttribute(PropertyNode, AttributeName, AttributeValue);
	EndIf;
	
EndProcedure

Procedure WriteDataToMasterNode(PropertyCollectionNode, PropertyNodeStructure, PropertyNode)
	
	If PropertyNodeStructure <> Undefined Then
		WriteStructureToXML(PropertyNodeStructure, PropertyCollectionNode);
	Else
		AddSubordinateNode(PropertyCollectionNode, PropertyNode);
	EndIf;
	
EndProcedure

// Generates destination object property nodes according to the specified property conversion rule collection.
//
// Parameters:
//  Source		 - an arbitrary data source.
//  Destination		 - a destination object XML node.
//  IncomingData	 - arbitrary auxiliary data that is passed to the conversion rule.
//                         
//  OutgoingData - arbitrary auxiliary data that is passed to the property object conversion rules.
//                         
//  OCR				     - a reference to the object conversion rule (property conversion rule collection parent).
//  PGCR                 - a reference to the property group conversion rule.
//  PropertyCollectionNode - property collection XML node.
// 
Procedure ExportPropertyGroup(Source, Destination, IncomingData, OutgoingData, OCR, PGCR, PropertyCollectionNode, 
	ExportRefOnly, TempFileList = Undefined)
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ApplicationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	ObjectCollection = Undefined;
	DontReplace        = PGCR.DoNotReplace;
	DontClear         = False;
	ExportGroupToFile = PGCR.ExportGroupToFile;
	
	// BeforeProcessExport handler
	If PGCR.HasBeforeProcessExportHandler Then
		
		Cancel = False;
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(PGCR, "BeforeProcessExport"));
				
			Else
				
				Execute(PGCR.BeforeProcessExport);
				
			EndIf;
			
		Except
			
			WriteErrorInfoPCRHandlers(48, ErrorDescription(), OCR, PGCR,
				Source, "BeforeProcessPropertyGroupExport",, False);
		
		EndTry;
		
		If Cancel Then // Canceling property group processing.
			
			Return;
			
		EndIf;
		
	EndIf;

	
    DestinationKind = PGCR.DestinationKind;
	SourceKind = PGCR.SourceKind;
	
	
    // Creating a node of subordinate object collection.
	PropertyNodeStructure = Undefined;
	ObjectCollectionNode = Undefined;
	MasterNodeName = "";
	
	If DestinationKind = "TabularSection" Then
		
		MasterNodeName = "TabularSection";
		
		CreateObjectsForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, TRUE, PGCR.Destination, MasterNodeName);
		
		If DontReplace Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, "DoNotReplace", "true");
						
		EndIf;
		
		If DontClear Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, "DoNotClear", "true");
						
		EndIf;
		
	ElsIf DestinationKind = "SubordinateCatalog" Then
				
		
	ElsIf DestinationKind = "SequenceRecordSet" Then
		
		MasterNodeName = "RecordSet";
		
		CreateObjectsForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, TRUE, PGCR.Destination, MasterNodeName);
		
	ElsIf StrFind(DestinationKind, "RecordSet") > 0 Then
		
		MasterNodeName = "RecordSet";
		
		CreateObjectsForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, TRUE, PGCR.Destination, MasterNodeName);
		
		If DontReplace Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, "DoNotReplace", "true");
						
		EndIf;
		
		If DontClear Then
			
			AddAttributeForXMLWriter(PropertyNodeStructure, ObjectCollectionNode, "DoNotClear", "true");
						
		EndIf;
		
	Else  // Simple group
		
		ExportProperties(Source, Destination, IncomingData, OutgoingData, OCR, PGCR.GroupRules, 
		     PropertyCollectionNode, , , OCR.DoNotExportPropertyObjectsByRefs OR ExportRefOnly);
			
		If PGCR.HasAfterProcessExportHandler Then
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PGCR, "AfterProcessExport"));
					
				Else
					
					Execute(PGCR.AfterProcessExport);
			
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(49, ErrorDescription(), OCR, PGCR,
					Source, "AfterProcessPropertyGroupExport",, False);
				
			EndTry;
			
		EndIf;
		
		Return;
		
	EndIf;
	
	// Getting the collection of subordinate objects.
	
	If ObjectCollection <> Undefined Then
		
		// The collection was initialized in the BeforeProcess handler.
		
	ElsIf PGCR.GetFromIncomingData Then
		
		Try
			
			ObjectCollection = IncomingData[PGCR.Destination];
			
			If TypeOf(ObjectCollection) = Type("QueryResult") Then
				
				ObjectCollection = ObjectCollection.Unload();
				
			EndIf;
			
		Except
			
			WriteErrorInfoPCRHandlers(66, ErrorDescription(), OCR, PGCR, Source,,,False);
			
			Return;
		EndTry;
		
	ElsIf SourceKind = "TabularSection" Then
		
		ObjectCollection = Source[PGCR.Source];
		
		If TypeOf(ObjectCollection) = Type("QueryResult") Then
			
			ObjectCollection = ObjectCollection.Unload();
			
		EndIf;
		
	ElsIf SourceKind = "SubordinateCatalog" Then
		
	ElsIf StrFind(SourceKind, "RecordSet") > 0 Then
		
		ObjectCollection = GetDocumentRegisterRecordSet(Source, SourceKind, PGCR.Source);
				
	ElsIf IsBlankString(PGCR.Source) Then
		
		ObjectCollection = Source[PGCR.Destination];
		
		If TypeOf(ObjectCollection) = Type("QueryResult") Then
			
			ObjectCollection = ObjectCollection.Unload();
			
		EndIf;
		
	EndIf;
	
	ExportGroupToFile = ExportGroupToFile Or (ObjectCollection.Count() > 1000);
	ExportGroupToFile = ExportGroupToFile AND (DirectReadingInDestinationIB = False);
	
	If ExportGroupToFile Then
		
		PGCR.XMLNodeRequiredOnExport = False;
		
		If TempFileList = Undefined Then
			TempFileList = New Array;
		EndIf;
		
		RecordsTemporaryFile = WriteTextToTemporaryFile(TempFileList);
		
		InformationToWriteToFile = ObjectCollectionNode.Close();
		RecordsTemporaryFile.WriteLine(InformationToWriteToFile);
		
	EndIf;
	
	For Each CollectionObject In ObjectCollection Do
		
		// BeforeExport handler
		If PGCR.HasBeforeExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PGCR, "BeforeExport"));
					
				Else
					
					Execute(PGCR.BeforeExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(50, ErrorDescription(), OCR, PGCR,
					Source, "BeforeExportPropertyGroup",, False);
				
				Break;
				
			EndTry;
			
			If Cancel Then	//	Canceling subordinate object export.
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		// OnExport handler
		
		If PGCR.XMLNodeRequiredOnExport OR ExportGroupToFile Then
			CollectionObjectNode = CreateNode("Record");
		Else
			ObjectCollectionNode.WriteStartElement("Record");
			CollectionObjectNode = ObjectCollectionNode;
		EndIf;
		
		StandardProcessing	= True;
		
		If PGCR.HasOnExportHandler Then
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PGCR, "OnExport"));
					
				Else
					
					Execute(PGCR.OnExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(51, ErrorDescription(), OCR, PGCR,
					Source, "OnExportPropertyGroup",, False);
				
				Break;
				
			EndTry;
			
		EndIf;

		//	Exporting the collection object properties.
		
		If StandardProcessing Then
			
			If PGCR.GroupRules.Count() > 0 Then
				
		 		ExportProperties(Source, Destination, IncomingData, OutgoingData, OCR, PGCR.GroupRules, 
		 			CollectionObjectNode, CollectionObject, , OCR.DoNotExportPropertyObjectsByRefs OR ExportRefOnly);
				
			EndIf;
			
		EndIf;
		
		// AfterExport handler
		
		If PGCR.HasAfterExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PGCR, "AfterExport"));
					
				Else
					
					Execute(PGCR.AfterExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(52, ErrorDescription(), OCR, PGCR,
					Source, "AfterExportPropertyGroup",, False);
				
				Break;
			EndTry; 
			
			If Cancel Then	//	Canceling subordinate object export.
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		If PGCR.XMLNodeRequiredOnExport Then
			AddSubordinateNode(ObjectCollectionNode, CollectionObjectNode);
		EndIf;
		
		// Filling the file with node objects.
		If ExportGroupToFile Then
			
			CollectionObjectNode.WriteEndElement();
			InformationToWriteToFile = CollectionObjectNode.Close();
			RecordsTemporaryFile.WriteLine(InformationToWriteToFile);
			
		Else
			
			If Not PGCR.XMLNodeRequiredOnExport Then
				
				ObjectCollectionNode.WriteEndElement();
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	
    // AfterProcessExport handler

	If PGCR.HasAfterProcessExportHandler Then
		
		Cancel = False;
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(PGCR, "AfterProcessExport"));
				
			Else
				
				Execute(PGCR.AfterProcessExport);
				
			EndIf;
			
		Except
			
			WriteErrorInfoPCRHandlers(49, ErrorDescription(), OCR, PGCR,
				Source, "AfterProcessPropertyGroupExport",, False);
			
		EndTry;
		
		If Cancel Then	//	Canceling subordinate object collection writing.
			
			Return;
			
		EndIf;
		
	EndIf;
	
	If ExportGroupToFile Then
		RecordsTemporaryFile.WriteLine("</" + MasterNodeName + ">"); // Closing the node
		RecordsTemporaryFile.Close(); 	// Closing the file
	Else
		WriteDataToMasterNode(PropertyCollectionNode, PropertyNodeStructure, ObjectCollectionNode);
	EndIf;

EndProcedure

Procedure GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source)
	
	If Value <> Undefined Then
		Return;
	EndIf;
	
	If PCR.GetFromIncomingData Then
			
			ObjectForReceivingData = IncomingData;
			
			If Not IsBlankString(PCR.Destination) Then
			
				PropertyName = PCR.Destination;
				
			Else
				
				PropertyName = PCR.ParameterForTransferName;
				
			EndIf;
			
			ErrorCode = ?(CollectionObject <> Undefined, 67, 68);
	
	ElsIf CollectionObject <> Undefined Then
		
		ObjectForReceivingData = CollectionObject;
		
		If Not IsBlankString(PCR.Source) Then
			
			PropertyName = PCR.Source;
			ErrorCode = 16;
						
		Else
			
			PropertyName = PCR.Destination;
			ErrorCode = 17;
			
		EndIf;
		
	Else
		
		ObjectForReceivingData = Source;
		
		If Not IsBlankString(PCR.Source) Then
		
			PropertyName = PCR.Source;
			ErrorCode = 13;
		
		Else
			
			PropertyName = PCR.Destination;
			ErrorCode = 14;
			
		EndIf;
		
	EndIf;
	
	Try
		
		Value = ObjectForReceivingData[PropertyName];
		
	Except
		
		If ErrorCode <> 14 Then
			WriteErrorInfoPCRHandlers(ErrorCode, ErrorDescription(), OCR, PCR, Source, "");
		EndIf;
		
	EndTry;
	
EndProcedure

Procedure ExportItemPropertyType(PropertyNode, PropertyType)
	
	SetAttribute(PropertyNode, "Type", PropertyType);	
	
EndProcedure

Procedure ExportExtDimension(Source,
							Destination,
							IncomingData,
							OutgoingData,
							OCR,
							PCR,
							PropertyCollectionNode ,
							CollectionObject,
							Val ExportRefOnly)
	
	//
	// Variables for supporting the event handler script debugging mechanism. (supporting the wrapper 
	// procedure interface).
	Var DestinationType, Empty, Expression, DontReplace, PropertyNode, PropertiesOCR;
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ApplicationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	// Initializing the value
	Value = Undefined;
	OCRName = "";
	OCRNameExtDimensionType = "";
	
	// BeforeExport handler
	If PCR.HasBeforeExportHandler Then
		
		Cancel = False;
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(PCR, "BeforeExport"));
				
			Else
				
				Execute(PCR.BeforeExport);
				
			EndIf;
			
		Except
			
			WriteErrorInfoPCRHandlers(55, ErrorDescription(), OCR, PCR, Source, 
				"BeforeExportProperty", Value);
				
		EndTry;
			
		If Cancel Then // Canceling the export
			
			Return;
			
		EndIf;
		
	EndIf;
	
	GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source);
	
	If PCR.CastToLength <> 0 Then
		
		CastValueToLength(Value, PCR);
		
	EndIf;
		
	For each KeyAndValue In Value Do
		
		ExtDimensionType = KeyAndValue.Key;
		ExtDimensionDimension = KeyAndValue.Value;
		OCRName = "";
		
		// OnExport handler
		If PCR.HasOnExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "OnExport"));
					
				Else
					
					Execute(PCR.OnExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(56, ErrorDescription(), OCR, PCR, Source, 
					"OnExportProperty", Value);
				
			EndTry;
				
			If Cancel Then // Canceling extra dimension exporting
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		If ExtDimensionDimension = Undefined
			OR FindRule(ExtDimensionDimension, OCRName) = Undefined Then
			
			Continue;
			
		EndIf;
			
		ExtDimensionNode = CreateNode(PCR.Destination);
		
		// Key
		PropertyNode = CreateNode("Property");
		
		If IsBlankString(OCRNameExtDimensionType) Then
			
			OCRKey = FindRule(ExtDimensionType, OCRNameExtDimensionType);
			
		Else
			
			OCRKey = FindRule(, OCRNameExtDimensionType);
			
		EndIf;
		
		SetAttribute(PropertyNode, "Name", "Key");
		ExportItemPropertyType(PropertyNode, OCRKey.Destination);
			
		RefNode = ExportByRule(ExtDimensionType,, OutgoingData,, OCRNameExtDimensionType,, ExportRefOnly, OCRKey);
			
		If RefNode <> Undefined Then
			
			IsRuleWithGlobalExport = False;
			RefNodeType = TypeOf(RefNode);
			AddPropertiesForExport(RefNode, RefNodeType, PropertyNode, IsRuleWithGlobalExport);
			
		EndIf;
		
		AddSubordinateNode(ExtDimensionNode, PropertyNode);
		
		// Value
		PropertyNode = CreateNode("Property");
		
		OCRValue = FindRule(ExtDimensionDimension, OCRName);
		
		DestinationType = OCRValue.Destination;
		
		IsNULL = False;
		Empty = deEmpty(ExtDimensionDimension, IsNULL);
		
		If Empty Then
			
			If IsNULL 
				Or ExtDimensionDimension = Undefined Then
				
				Continue;
				
			EndIf;
			
			If IsBlankString(DestinationType) Then
				
				DestinationType = GetDataTypeForDestination(ExtDimensionDimension);
				
			EndIf;
			
			SetAttribute(PropertyNode, "Name", "Value");
			
			If Not IsBlankString(DestinationType) Then
				SetAttribute(PropertyNode, "Type", DestinationType);
			EndIf;
			
			// If it is a variable of multiple type, it must be exported with the specified type, perhaps this is an empty reference.
			deWriteElement(PropertyNode, "Empty");
			
			AddSubordinateNode(ExtDimensionNode, PropertyNode);
			
		Else
			
			IsRuleWithGlobalExport = False;
			RefNode = ExportByRule(ExtDimensionDimension,, OutgoingData, , OCRName, , ExportRefOnly, OCRValue, IsRuleWithGlobalExport);
			
			SetAttribute(PropertyNode, "Name", "Value");
			ExportItemPropertyType(PropertyNode, DestinationType);
			
			If RefNode = Undefined Then
				
				Continue;
				
			EndIf;
			
			RefNodeType = TypeOf(RefNode);
			
			AddPropertiesForExport(RefNode, RefNodeType, PropertyNode, IsRuleWithGlobalExport);
			
			AddSubordinateNode(ExtDimensionNode, PropertyNode);
			
		EndIf;
		
		// AfterExport handler
		If PCR.HasAfterExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "AfterExport"));
					
				Else
					
					Execute(PCR.AfterExport);
					
				EndIf;
					
			Except
					
				WriteErrorInfoPCRHandlers(57, ErrorDescription(), OCR, PCR, Source,
					"AfterExportProperty", Value);
					
			EndTry;
			
			If Cancel Then // Canceling the export
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		AddSubordinateNode(PropertyCollectionNode, ExtDimensionNode);
		
	EndDo;
	
EndProcedure

Procedure AddPropertiesForExport(RefNode, RefNodeType, PropertyNode, IsRuleWithGlobalExport)
	
	If RefNodeType = deStringType Then
				
		If StrFind(RefNode, "<Ref") > 0 Then
					
			PropertyNode.WriteRaw(RefNode);
					
		Else
			
			deWriteElement(PropertyNode, "Value", RefNode);
					
		EndIf;
				
	ElsIf RefNodeType = deNumberType Then
		
		If IsRuleWithGlobalExport Then
		
			deWriteElement(PropertyNode, "Gsn", RefNode);
			
		Else     		
			
			deWriteElement(PropertyNode, "Sn", RefNode);
			
		EndIf;
				
	Else
				
		AddSubordinateNode(PropertyNode, RefNode);
				
	EndIf;	
	
EndProcedure

Procedure AddPropertyValueToNode(Value, ValueType, DestinationType, PropertyNode, PropertySet)
	
	PropertySet = True;
		
	If ValueType = deStringType Then
				
		If DestinationType = "String"  Then
		ElsIf DestinationType = "Number"  Then
					
			Value = Number(Value);
					
		ElsIf DestinationType = "Boolean"  Then
					
			Value = Boolean(Value);
					
		ElsIf DestinationType = "Date"  Then
					
			Value = Date(Value);
					
		ElsIf DestinationType = "ValueStorage"  Then
					
			Value = New ValueStorage(Value);
					
		ElsIf DestinationType = "UUID" Then
					
			Value = New UUID(Value);
					
		ElsIf IsBlankString(DestinationType) Then
					
			SetAttribute(PropertyNode, "Type", "String");
					
		EndIf;
				
		deWriteElement(PropertyNode, "Value", Value);
				
	ElsIf ValueType = deNumberType Then
				
		If DestinationType = "Number"  Then
		ElsIf DestinationType = "Boolean"  Then
					
			Value = Boolean(Value);
					
		ElsIf DestinationType = "String"  Then
		ElsIf IsBlankString(DestinationType) Then
					
			SetAttribute(PropertyNode, "Type", "Number");
					
		Else
					
			Return;
					
		EndIf;
				
		deWriteElement(PropertyNode, "Value", Value);
				
	ElsIf ValueType = deDateType Then
				
		If DestinationType = "Date"  Then
		ElsIf DestinationType = "String"  Then
					
			Value = Left(String(Value), 10);
					
		ElsIf IsBlankString(DestinationType) Then
					
			SetAttribute(PropertyNode, "Type", "Date");
					
		Else
					
			Return;
					
		EndIf;
				
		deWriteElement(PropertyNode, "Value", Value);
				
	ElsIf ValueType = deBooleanType Then
				
		If DestinationType = "Boolean"  Then
		ElsIf DestinationType = "Number"  Then
					
			Value = Number(Value);
					
		ElsIf IsBlankString(DestinationType) Then
					
			SetAttribute(PropertyNode, "Type", "Boolean");
					
		Else
					
			Return;
					
		EndIf;
				
		deWriteElement(PropertyNode, "Value", Value);
				
	ElsIf ValueType = deValueStorageType Then
				
		If IsBlankString(DestinationType) Then
					
			SetAttribute(PropertyNode, "Type", "ValueStorage");
					
		ElsIf DestinationType <> "ValueStorage"  Then
					
			Return;
					
		EndIf;
				
		deWriteElement(PropertyNode, "Value", Value);
				
	ElsIf ValueType = deUUIDType Then
		
		If DestinationType = "UUID" Then
		ElsIf DestinationType = "String"  Then
					
			Value = String(Value);
					
		ElsIf IsBlankString(DestinationType) Then
					
			SetAttribute(PropertyNode, "Type", "UUID");
					
		Else
					
			Return;
					
		EndIf;
		
		deWriteElement(PropertyNode, "Value", Value);
		
	ElsIf ValueType = deAccumulationRecordTypeType Then
				
		deWriteElement(PropertyNode, "Value", String(Value));		
		
	Else	
		
		PropertySet = False;
		
	EndIf;	
	
EndProcedure

Function ExportRefObjectData(Value, OutgoingData, OCRName, PropertiesOCR, DestinationType, PropertyNode, Val ExportRefOnly)
	
	IsRuleWithGlobalExport = False;
	RefNode    = ExportByRule(Value, , OutgoingData, , OCRName, , ExportRefOnly, PropertiesOCR, IsRuleWithGlobalExport);
	RefNodeType = TypeOf(RefNode);

	If IsBlankString(DestinationType) Then
				
		DestinationType  = PropertiesOCR.Destination;
		SetAttribute(PropertyNode, "Type", DestinationType);
				
	EndIf;
			
	If RefNode = Undefined Then
				
		Return Undefined;
				
	EndIf;
				
	AddPropertiesForExport(RefNode, RefNodeType, PropertyNode, IsRuleWithGlobalExport);	
	
	Return RefNode;
	
EndFunction

Function GetDataTypeForDestination(Value)
	
	DestinationType = deValueTypeAsString(Value);
	
	// Checking for any OCR with the DestinationType destination type. If no rule is found, then "". If 
	// a rule is found, it is left.
	TableRow = ConversionRulesTable.Find(DestinationType, "Destination");
	
	If TableRow = Undefined Then
		DestinationType = "";
	EndIf;
	
	Return DestinationType;
	
EndFunction

Procedure CastValueToLength(Value, PCR)
	
	Value = CastNumberToLength(String(Value), PCR.CastToLength);
		
EndProcedure

// Generates destination object property nodes according to the specified property conversion rule collection.
//
// Parameters:
//  Source		 - an arbitrary data source.
//  Destination		 - a destination object XML node.
//  IncomingData	 - arbitrary auxiliary data that is passed to the conversion rule.
//                         
//  OutgoingData - arbitrary auxiliary data that is passed to the property object conversion rules.
//                         
//  OCR				     - a reference to the object conversion rule (property conversion rule collection parent).
//  PCRCollection         - property conversion rule collection.
//  PropertyCollectionNode - property collection XML node.
//  CollectionObject - if this parameter is specified, collection object properties are exported, otherwise source object properties are exported.
//  PredefinedItemName - if this parameter is specified, the predefined item name is written to the properties.
//  PGCR                 - a reference to property group conversion rule (PCR collection parent folder).
//                         For example a document tabular section.
// 
Procedure ExportProperties(Source, Destination, IncomingData, OutgoingData, OCR, PCRCollection, PropertyCollectionNode = Undefined, 
	CollectionObject = Undefined, PredefinedItemName = Undefined, Val ExportRefOnly = False, 
	TempFileList = Undefined)
	
	Var KeyAndValue, ExtDimensionType, ExtDimensionDimension, OCRNameExtDimensionType, ExtDimensionNode; // for correct handler execution.
	                                                                             // 
	
	If PropertyCollectionNode = Undefined Then
		
		PropertyCollectionNode = Destination;
		
	EndIf;
	
	// Exporting the predefined item name if it is specified.
	If PredefinedItemName <> Undefined Then
		
		PropertyCollectionNode.WriteStartElement("Property");
		SetAttribute(PropertyCollectionNode, "Name", "{PredefinedItemName}");
		If NOT ExecuteDataExchangeInOptimizedFormat Then
			SetAttribute(PropertyCollectionNode, "Type", "String");
		EndIf;
		deWriteElement(PropertyCollectionNode, "Value", PredefinedItemName);
		PropertyCollectionNode.WriteEndElement();		
		
	EndIf;
		
	For each PCR In PCRCollection Do
		
		If PCR.SimplifiedPropertyExport Then
						
			 //	Creating the property node
			 
			PropertyCollectionNode.WriteStartElement("Property");
			SetAttribute(PropertyCollectionNode, "Name", PCR.Destination);
			
			If NOT ExecuteDataExchangeInOptimizedFormat
				AND Not IsBlankString(PCR.DestinationType) Then
			
				SetAttribute(PropertyCollectionNode, "Type", PCR.DestinationType);
				
			EndIf;
			
			If PCR.DoNotReplace Then
				
				SetAttribute(PropertyCollectionNode, "DoNotReplace",	"true");
				
			EndIf;
			
			If PCR.SearchByEqualDate  Then
				
				SetAttribute(PropertyCollectionNode, "SearchByEqualDate", "true");
				
			EndIf;
			
			Value = Undefined;
			GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source);
			
			If PCR.CastToLength <> 0 Then
				
				CastValueToLength(Value, PCR);
								
			EndIf;
			
			IsNULL = False;
			Empty = deEmpty(Value, IsNULL);
						
			If Empty Then
				
				// Writing the empty value.
				If NOT ExecuteDataExchangeInOptimizedFormat Then
					deWriteElement(PropertyCollectionNode, "Empty");
				EndIf;
				
				PropertyCollectionNode.WriteEndElement();
				Continue;
				
			EndIf;
			
			deWriteElement(PropertyCollectionNode,	"Value", Value);
			
			PropertyCollectionNode.WriteEndElement();
			Continue;	
			
		ElsIf PCR.DestinationKind = "AccountExtDimensionTypes" Then
			
			ExportExtDimension(Source, Destination, IncomingData, OutgoingData, OCR,
				PCR, PropertyCollectionNode, CollectionObject, ExportRefOnly);
			
			Continue;
			
		ElsIf PCR.Name = "{UUID}" 
			AND PCR.Source = "{UUID}" 
			AND PCR.Destination = "{UUID}" Then
			
			If Source = Undefined Then
				Continue;
			EndIf;
			
			If RefTypeValue(Source) Then
				UUID = Source.UUID();
			Else
				
				InitialValue = New UUID();
				StructureToCheckPropertyAvailability = New Structure("Ref", InitialValue);
				FillPropertyValues(StructureToCheckPropertyAvailability, Source);
				
				If InitialValue <> StructureToCheckPropertyAvailability.Ref
					AND RefTypeValue(StructureToCheckPropertyAvailability.Ref) Then
					UUID = Source.Ref.UUID();
				EndIf;
				
			EndIf;
			
			PropertyCollectionNode.WriteStartElement("Property");
			SetAttribute(PropertyCollectionNode, "Name", "{UUID}");
			
			If NOT ExecuteDataExchangeInOptimizedFormat Then 
				SetAttribute(PropertyCollectionNode, "Type", "String");
			EndIf;
			
			deWriteElement(PropertyCollectionNode, "Value", UUID);
			PropertyCollectionNode.WriteEndElement();
			Continue;
			
		ElsIf PCR.IsFolder Then
			
			ExportPropertyGroup(Source, Destination, IncomingData, OutgoingData, OCR, PCR, PropertyCollectionNode, ExportRefOnly, TempFileList);
			Continue;
			
		EndIf;

		
		//	Initializing the value to be converted.
		Value 	 = Undefined;
		OCRName		 = PCR.ConversionRule;
		DontReplace   = PCR.DoNotReplace;
		
		Empty		 = False;
		Expression	 = Undefined;
		DestinationType = PCR.DestinationType;

		IsNULL      = False;

		
		// BeforeExport handler
		If PCR.HasBeforeExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "BeforeExport"));
					
				Else
					
					Execute(PCR.BeforeExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(55, ErrorDescription(), OCR, PCR, Source, 
						"BeforeExportProperty", Value);
														
			EndTry;
				                             
			If Cancel Then	//	Canceling property export
				
				Continue;
				
			EndIf;
			
		EndIf;

        		
        //	Creating the property node
		If IsBlankString(PCR.ParameterForTransferName) Then
			
			PropertyNode = CreateNode("Property");
			SetAttribute(PropertyNode, "Name", PCR.Destination);
			
		Else
			
			PropertyNode = CreateNode("ParameterValue");
			SetAttribute(PropertyNode, "Name", PCR.ParameterForTransferName);
			
		EndIf;
		
		If DontReplace Then
			
			SetAttribute(PropertyNode, "DoNotReplace",	"true");
			
		EndIf;
		
		If PCR.SearchByEqualDate  Then
			
			SetAttribute(PropertyCollectionNode, "SearchByEqualDate", "true");
			
		EndIf;

        		
		//	Perhaps, the conversion rule is already defined.
		If Not IsBlankString(OCRName) Then
			
			PropertiesOCR = Rules[OCRName];
			
		Else
			
			PropertiesOCR = Undefined;
			
		EndIf;


		//	Attempting to define a destination property type.
		If IsBlankString(DestinationType)	AND PropertiesOCR <> Undefined Then
			
			DestinationType = PropertiesOCR.Destination;
			SetAttribute(PropertyNode, "Type", DestinationType);
			
		ElsIf NOT ExecuteDataExchangeInOptimizedFormat 
			AND Not IsBlankString(DestinationType) Then
			
			SetAttribute(PropertyNode, "Type", DestinationType);
						
		EndIf;
		
		If Not IsBlankString(OCRName)
			AND PropertiesOCR <> Undefined
			AND PropertiesOCR.HasSearchFieldSequenceHandler = True Then
			
			SetAttribute(PropertyNode, "OCRName", OCRName);
			
		EndIf;
		
        //	Determining the value to be converted.
		If Expression <> Undefined Then
			
			deWriteElement(PropertyNode, "Expression", Expression);
			AddSubordinateNode(PropertyCollectionNode, PropertyNode);
			Continue;
			
		ElsIf Empty Then
			
			If IsBlankString(DestinationType) Then
				
				Continue;
				
			EndIf;
			
			If NOT ExecuteDataExchangeInOptimizedFormat Then 
				deWriteElement(PropertyNode, "Empty");
			EndIf;
			
			AddSubordinateNode(PropertyCollectionNode, PropertyNode);
			Continue;
			
		Else
			
			GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source);
			
			If PCR.CastToLength <> 0 Then
				
				CastValueToLength(Value, PCR);
								
			EndIf;
						
		EndIf;


		OldValueBeforeOnExportHandler = Value;
		Empty = deEmpty(Value, IsNULL);

		
		// OnExport handler
		If PCR.HasOnExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "OnExport"));
					
				Else
					
					Execute(PCR.OnExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(56, ErrorDescription(), OCR, PCR, Source, 
						"OnExportProperty", Value);
														
			EndTry;
				
			If Cancel Then	//	Canceling property export
				
				Continue;
				
			EndIf;
			
		EndIf;


		// Initializing the Empty variable one more time, perhaps its value has been changed in the OnExport 
		// handler.
		If OldValueBeforeOnExportHandler <> Value Then
			
			Empty = deEmpty(Value, IsNULL);
			
		EndIf;

		If Empty Then
			
			If IsNULL 
				Or Value = Undefined Then
				
				Continue;
				
			EndIf;
			
			If IsBlankString(DestinationType) Then
				
				DestinationType = GetDataTypeForDestination(Value);
				
				If Not IsBlankString(DestinationType) Then				
				
					SetAttribute(PropertyNode, "Type", DestinationType);
				
				EndIf;
				
			EndIf;			
				
			// If it is a variable of multiple type, it must be exported with the specified type, perhaps this is an empty reference.
			If NOT ExecuteDataExchangeInOptimizedFormat Then
				deWriteElement(PropertyNode, "Empty");
			EndIf;
			
			AddSubordinateNode(PropertyCollectionNode, PropertyNode);
			Continue;
			
		EndIf;

      		
		RefNode = Undefined;
		
		If (PropertiesOCR <> Undefined) 
			Or (Not IsBlankString(OCRName)) Then
			
			RefNode = ExportRefObjectData(Value, OutgoingData, OCRName, PropertiesOCR, DestinationType, PropertyNode, ExportRefOnly);
			
			If RefNode = Undefined Then
				Continue;				
			EndIf;				
										
		Else
			
			PropertySet = False;
			ValueType = TypeOf(Value);
			AddPropertyValueToNode(Value, ValueType, DestinationType, PropertyNode, PropertySet);
						
			If NOT PropertySet Then
				
				ValueManager = Managers[ValueType];
				
				If ValueManager = Undefined Then
					Continue;
				EndIf;
				
				PropertiesOCR = ValueManager.OCR;
				
				If PropertiesOCR = Undefined Then
					Continue;
				EndIf;
				
				OCRName = PropertiesOCR.Name;
				
				RefNode = ExportRefObjectData(Value, OutgoingData, OCRName, PropertiesOCR, DestinationType, PropertyNode, ExportRefOnly);
			
				If RefNode = Undefined Then
					Continue;				
				EndIf;				
												
			EndIf;
			
		EndIf;


		
		// AfterExport handler

		If PCR.HasAfterExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "AfterExport"));
					
				Else
					
					Execute(PCR.AfterExport);
					
				EndIf;
				
			Except
				
				WriteErrorInfoPCRHandlers(57, ErrorDescription(), OCR, PCR, Source, 
						"AfterExportProperty", Value);					
				
			EndTry;
				
			If Cancel Then	//	Canceling property export
				
				Continue;
				
			EndIf;
			
		EndIf;

		
		AddSubordinateNode(PropertyCollectionNode, PropertyNode);
		
	EndDo;		//	by PCR

EndProcedure

// Exports the selection object according to the specified rule.
//
// Parameters:
//  Object - selection object to be exported.
//  Rule - data export rule reference.
//  Properties - metadata object properties of the object to be exported.
//  IncomingData - arbitrary auxiliary data.
// 
Procedure ExportSelectionObject(Object, Rule, Properties=Undefined, IncomingData=Undefined, SelectionForDataExport = Undefined)

	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ApplicationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	If CommentObjectProcessingFlag Then
		
		TypesDetails = New TypeDescription("String");
		RowObject  = TypesDetails.AdjustValue(Object);
		If Not IsBlankString(RowObject) Then
			ObjectRul   = RowObject + "  (" + TypeOf(Object) + ")";
		Else
			ObjectRul   = TypeOf(Object);
		EndIf;
		
		MessageString = SubstituteParametersToString(NStr("ru = 'Выгрузка объекта: %1'; en = 'Exporting object: %1'; pl = 'Eksportuj obiekt: %1';es_ES = 'Exportar el objeto: %1';es_CO = 'Exportar el objeto: %1';tr = 'Nesne dışa aktarımı: %1';it = 'Upload oggetto: %1';de = 'Objekt exportieren: %1'"), ObjectRul);
		WriteToExecutionProtocol(MessageString, , False, 1, 7);
		
	EndIf;
	
	OCRName			= Rule.ConversionRule;
	Cancel			= False;
	OutgoingData	= Undefined;
	
	// BeforeExportObject global handler.
	If HasBeforeExportObjectGlobalHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "BeforeExportObject"));
				
			Else
				
				Execute(Conversion.BeforeExportObject);
				
			EndIf;
			
		Except
			WriteErrorInfoDERHandlers(65, ErrorDescription(), Rule.Name, NStr("ru = 'BeforeExportSelectionObject (глобальный)'; en = 'BeforeExportSelectionObject (global)'; pl = 'BeforeExportSelectionObject (globalny)';es_ES = 'BeforeExportSelectionObject (global)';es_CO = 'BeforeExportSelectionObject (global)';tr = 'BeforeExportSelectionObject (global)';it = 'BeforeExportSelectionObject (globale)';de = 'BeforeExportSelectionObject (global)'"), Object);
		EndTry;
			
		If Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
	// BeforeExport handler
	If Not IsBlankString(Rule.BeforeExport) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeExport"));
				
			Else
				
				Execute(Rule.BeforeExport);
				
			EndIf;
			
		Except
			WriteErrorInfoDERHandlers(33, ErrorDescription(), Rule.Name, "BeforeExportSelectionObject", Object);
		EndTry;
		
		If Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
	RefNode = Undefined;
	
	ExportByRule(Object, , OutgoingData, , OCRName, RefNode, , , , SelectionForDataExport);
	
	// AfterExportObject global handler.
	If HasAfterExportObjectGlobalHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "AfterExportObject"));
				
			Else
				
				Execute(Conversion.AfterExportObject);
			
			EndIf;
			
		Except
			WriteErrorInfoDERHandlers(69, ErrorDescription(), Rule.Name, NStr("ru = 'AfterExportSelectionObject (глобальный)'; en = 'AfterExportSelectionObject (global)'; pl = 'AfterExportSelectionObject (globalny)';es_ES = 'AfterSelectionObjectExport (Global)';es_CO = 'AfterSelectionObjectExport (Global)';tr = 'AfterExportSelectionObject (Global)';it = 'AfterExportSelectionObject (globale)';de = 'AfterExportSelectionObject (global)'"), Object);
		EndTry;
		
	EndIf;
	
	// AfterExport handler
	If Not IsBlankString(Rule.AfterExport) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "AfterExport"));
				
			Else
				
				Execute(Rule.AfterExport);
				
			EndIf;
			
		Except
			WriteErrorInfoDERHandlers(34, ErrorDescription(), Rule.Name, "AfterExportSelectionObject", Object);
		EndTry;
		
	EndIf;
	
EndProcedure

Function GetFirstMetadataAttributeName(ObjectMetadata)
	
	If ObjectMetadata.Attributes.Count() = 0 Then
		Return "";
	EndIf;
	
	Return ObjectMetadata.Attributes[0].Name;
	
EndFunction

Function GetSelectionForExportWithRestrictions(Rule, SelectionForSubstitutionToOCR = Undefined, Properties = Undefined)
	
	MetadataName           = Rule.ObjectForQueryName;
	
	PermissionRow = ?(ExportAllowedObjectsOnly, " ALLOWED ", "");
	
	SelectionFields = "";
	
	IsRegisterExport = (Rule.ObjectForQueryName = Undefined);
	
	If IsRegisterExport Then
		
		Nonperiodical = NOT Properties.Periodic;
		SubordinatedToRecorder = Properties.SubordinateToRecorder;
		
		SelectionFieldSupplementionStringSubordinateToRegistrar = ?(NOT SubordinatedToRecorder, ", NULL AS Active,
		|	NULL AS Recorder,
		|	NULL AS LineNumber", "");
		
		SelectionFieldSupplementionStringPeriodicity = ?(Nonperiodical, ", NULL AS Period", "");
		
		ResultingDateRestriction = GetRestrictionByDateStringForQuery(Properties, Properties.TypeName, Rule.ObjectNameForRegisterQuery, False);
		
		ReportBuilder.Text = "SELECT " + PermissionRow 
			+ "|	*
				 |
				 | " + SelectionFieldSupplementionStringSubordinateToRegistrar 
			 + " | " + SelectionFieldSupplementionStringPeriodicity 
			 + " |
				 | FROM " + Rule.ObjectNameForRegisterQuery
			+ " |
				 |" + ResultingDateRestriction;		
				 
		ReportBuilder.FillSettings();
				
	Else
		
		If Rule.SelectExportDataInSingleQuery Then
		
			// Selecting all object fields.
			SelectionFields = "*";
			
		Else
			
			SelectionFields = "Ref AS Ref";
			
		EndIf;
		
		ResultingDateRestriction = GetRestrictionByDateStringForQuery(Properties, Properties.TypeName,, False);
		
		ReportBuilder.Text = "SELECT " + PermissionRow + " " + SelectionFields + " FROM " + MetadataName + "
		|
		|" + ResultingDateRestriction + "
		|
		|{WHERE Ref.* AS " + StrReplace(MetadataName, ".", "_") + "}";
		
	EndIf;
	
	ReportBuilder.Filter.Reset();
	If Rule.BuilderSettings <> Undefined Then
		ReportBuilder.SetSettings(Rule.BuilderSettings);
	EndIf;
	
	ReportBuilder.Parameters.Insert("StartDate", StartDate);
	ReportBuilder.Parameters.Insert("EndDate", EndDate);

	ReportBuilder.Execute();
	Selection = ReportBuilder.Result.Select();
	
	If Rule.SelectExportDataInSingleQuery Then
		SelectionForSubstitutionToOCR = Selection;
	EndIf;
		
	Return Selection;
		
EndFunction

Function GetExportWithArbitraryAlgorithmSelection(DataSelection)
	
	Selection = Undefined;
	
	SelectionType = TypeOf(DataSelection);
			
	If SelectionType = Type("QueryResultSelection") Then
				
		Selection = DataSelection;
		
	ElsIf SelectionType = Type("QueryResult") Then
				
		Selection = DataSelection.Select();
					
	ElsIf SelectionType = Type("Query") Then
				
		QueryResult = DataSelection.Execute();
		Selection          = QueryResult.Select();
									
	EndIf;
		
	Return Selection;	
	
EndFunction

Function GetConstantSetRowForExport(ConstantDataTableForExport)
	
	ConstantSetString = "";
	
	For Each TableRow In ConstantDataTableForExport Do
		
		If Not IsBlankString(TableRow.Source) Then
		
			ConstantSetString = ConstantSetString + ", " + TableRow.Source;
			
		EndIf;
		
	EndDo;	
	
	If Not IsBlankString(ConstantSetString) Then
		
		ConstantSetString = Mid(ConstantSetString, 3);
		
	EndIf;
	
	Return ConstantSetString;
	
EndFunction

Procedure ExportConstantsSet(Rule, Properties, OutgoingData)
	
	If Properties.OCR <> Undefined Then
	
		ConstantSetNameString = GetConstantSetRowForExport(Properties.OCR.Properties);
		
	Else
		
		ConstantSetNameString = "";
		
	EndIf;
			
	ConstantsSet = Constants.CreateSet(ConstantSetNameString);
	ConstantsSet.Read();
	ExportSelectionObject(ConstantsSet, Rule, Properties, OutgoingData);	
	
EndProcedure

Function MustSelectAllFields(Rule)
	
	AllFieldsRequiredForSelection = NOT IsBlankString(Conversion.BeforeExportObject)
		OR NOT IsBlankString(Rule.BeforeExport)
		OR NOT IsBlankString(Conversion.AfterExportObject)
		OR NOT IsBlankString(Rule.AfterExport);		
		
	Return AllFieldsRequiredForSelection;	
	
EndFunction

// Exports data according to the specified rule.
//
// Parameters:
//  Rule - data export rule reference.
// 
Procedure ExportDataByRule(Rule)
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ApplicationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	OCRName = Rule.ConversionRule;
	
	If Not IsBlankString(OCRName) Then
		
		OCR = Rules[OCRName];
		
	EndIf;
	
	If CommentObjectProcessingFlag Then
		
		MessageString = SubstituteParametersToString(NStr("ru = 'Правило выгрузки данных: %1 (%2)'; en = 'Data export rule: %1 (%2)'; pl = 'Reguła wyładunku danych: %1(%2)';es_ES = 'Regla de exportación de datos: %1 (%2)';es_CO = 'Regla de exportación de datos: %1 (%2)';tr = 'Veri dışa aktarma kuralı : %1 (%2)';it = 'Regola esportazione dati: %1 (%2)';de = 'Datenexport-regel: %1 (%2)'"), TrimAll(Rule.Name), TrimAll(Rule.Description));
		WriteToExecutionProtocol(MessageString, , False, , 4);
		
	EndIf;
	
	// BeforeProcess handle
	Cancel			= False;
	OutgoingData	= Undefined;
	DataSelection	= Undefined;
	
	If Not IsBlankString(Rule.BeforeProcess) Then
	
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeProcess"));
				
			Else
				
				Execute(Rule.BeforeProcess);
				
			EndIf;
			
		Except
			
			WriteErrorInfoDERHandlers(31, ErrorDescription(), Rule.Name, "BeforeProcessDataExport");
			
		EndTry;
		
		If Cancel Then
			
			Return;
			
		EndIf;
		
	EndIf;
	
	// Standard selection with filter.
	If Rule.DataFilterMethod = "StandardSelection" AND Rule.UseFilter Then
		
		Properties	= Managers[Rule.SelectionObject];
		TypeName		= Properties.TypeName;
		
		SelectionForOCR = Undefined;
		Selection = GetSelectionForExportWithRestrictions(Rule, SelectionForOCR, Properties);
		
		IsNotReferenceType = TypeName =  "InformationRegister" Or TypeName = "AccountingRegister";
		
		While Selection.Next() Do
			
			If IsNotReferenceType Then
				ExportSelectionObject(Selection, Rule, Properties, OutgoingData);
			Else					
				ExportSelectionObject(Selection.Ref, Rule, Properties, OutgoingData, SelectionForOCR);
			EndIf;
			
		EndDo;
		
	// Standard selection without filter.
	ElsIf (Rule.DataFilterMethod = "StandardSelection") Then
		
		Properties	= Managers[Rule.SelectionObject];
		TypeName		= Properties.TypeName;
		
		If TypeName = "Constants" Then
			
			ExportConstantsSet(Rule, Properties, OutgoingData);
			
		Else
			
			IsNotReferenceType = TypeName =  "InformationRegister" 
				OR TypeName = "AccountingRegister";
			
			If IsNotReferenceType Then
					
				SelectAllFields = MustSelectAllFields(Rule);
				
			Else
				
				// Getting only the reference
				SelectAllFields = Rule.SelectExportDataInSingleQuery;	
				
			EndIf;
			
			Selection = GetSelectionForDataClearingExport(Properties, TypeName, , , SelectAllFields);
			SelectionForOCR = ?(Rule.SelectExportDataInSingleQuery, Selection, Undefined);
			
			If Selection = Undefined Then
				Return;
			EndIf;
			
			While Selection.Next() Do
				
				If IsNotReferenceType Then
					
					ExportSelectionObject(Selection, Rule, Properties, OutgoingData);
					
				Else
					
					ExportSelectionObject(Selection.Ref, Rule, Properties, OutgoingData, SelectionForOCR);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	ElsIf Rule.DataFilterMethod = "ArbitraryAlgorithm" Then

		If DataSelection <> Undefined Then
			
			Selection = GetExportWithArbitraryAlgorithmSelection(DataSelection);
			
			If Selection <> Undefined Then
				
				While Selection.Next() Do
					
					ExportSelectionObject(Selection, Rule, , OutgoingData);
					
				EndDo;
				
			Else
				
				For each Object In DataSelection Do
					
					ExportSelectionObject(Object, Rule, , OutgoingData);
					
				EndDo;
				
			EndIf;
			
		EndIf;
			
	EndIf;

	
	// AfterProcess handler

	If Not IsBlankString(Rule.AfterProcess) Then
	
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "AfterProcess"));
				
			Else
				
				Execute(Rule.AfterProcess);
				
			EndIf;
			
		Except
			
			WriteErrorInfoDERHandlers(32, ErrorDescription(), Rule.Name, "AfterProcessDataExport");
			
		EndTry;
		
	 EndIf;	
	
EndProcedure

// Iterates the tree of data export rules and executes export.
//
// Parameters:
//  Rows - value tree rows collection.
// 
Procedure ProcessExportRules(Rows, ExchangePlanNodesAndExportRowsMap)
	
	For each ExportRule In Rows Do
		
		If ExportRule.Enable = 0 Then
			
			Continue;
			
		EndIf; 
		
		If (ExportRule.ExchangeNodeRef <> Undefined 
				AND NOT ExportRule.ExchangeNodeRef.IsEmpty()) Then
			
			ExportRuleArray = ExchangePlanNodesAndExportRowsMap.Get(ExportRule.ExchangeNodeRef);
			
			If ExportRuleArray = Undefined Then
				
				ExportRuleArray = New Array();	
				
			EndIf;
			
			ExportRuleArray.Add(ExportRule);
			
			ExchangePlanNodesAndExportRowsMap.Insert(ExportRule.ExchangeNodeRef, ExportRuleArray);
			
			Continue;
			
		EndIf;

		If ExportRule.IsFolder Then
			
			ProcessExportRules(ExportRule.Rows, ExchangePlanNodesAndExportRowsMap);
			Continue;
			
		EndIf;
		
		ExportDataByRule(ExportRule);
		
	EndDo; 
	
EndProcedure

Function CopyExportRuleArray(SourceArray)
	
	ResultingArray = New Array();
	
	For Each Item In SourceArray Do
		
		ResultingArray.Add(Item);	
		
	EndDo;
	
	Return ResultingArray;
	
EndFunction

Function FindExportRuleTreeRowByExportType(RowsArray, ExportType)
	
	For Each ArrayRow In RowsArray Do
		
		If ArrayRow.SelectionObject = ExportType Then
			
			Return ArrayRow;
			
		EndIf;
			
	EndDo;
	
	Return Undefined;
	
EndFunction

Procedure DeleteExportRuleTreeRowByExportTypeFromArray(RowsArray, ItemToDelete)
	
	Counter = RowsArray.Count() - 1;
	While Counter >= 0 Do
		
		ArrayRow = RowsArray[Counter];
		
		If ArrayRow = ItemToDelete Then
			
			RowsArray.Delete(Counter);
			Return;
			
		EndIf; 
		
		Counter = Counter - 1;	
		
	EndDo;
	
EndProcedure

Procedure GetExportRuleRowByExchangeObject(Data, LastObjectMetadata, ExportObjectMetadata, 
	LastExportRulesString, CurrentExportRuleRow, TempConversionRuleArray, ObjectForExportRules, 
	ExportingRegister, ExportingConstants, ConstantsWereExported)
	
	CurrentExportRuleRow = Undefined;
	ObjectForExportRules = Undefined;
	ExportingRegister = False;
	ExportingConstants = False;
	
	If LastObjectMetadata = ExportObjectMetadata
		AND LastExportRulesString = Undefined Then
		
		Return;
		
	EndIf;
	
	DataStructure = ManagersForExchangePlans[ExportObjectMetadata];
	
	If DataStructure = Undefined Then
		
		ExportingConstants = Metadata.Constants.Contains(ExportObjectMetadata);
		
		If ConstantsWereExported 
			OR NOT ExportingConstants Then
			
			Return;
			
		EndIf;
		
		// Searching for the rule for constants.
		If LastObjectMetadata <> ExportObjectMetadata Then
		
			CurrentExportRuleRow = FindExportRuleTreeRowByExportType(TempConversionRuleArray, Type("ConstantsSet"));
			
		Else
			
			CurrentExportRuleRow = LastExportRulesString;
			
		EndIf;
		
		Return;
		
	EndIf;
	
	If DataStructure.IsReferenceType = True Then
		
		If LastObjectMetadata <> ExportObjectMetadata Then
		
			CurrentExportRuleRow = FindExportRuleTreeRowByExportType(TempConversionRuleArray, DataStructure.RefType);
			
		Else
			
			CurrentExportRuleRow = LastExportRulesString;
			
		EndIf;
		
		ObjectForExportRules = Data.Ref;
		
	ElsIf DataStructure.IsRegister = True Then
		
		If LastObjectMetadata <> ExportObjectMetadata Then
		
			CurrentExportRuleRow = FindExportRuleTreeRowByExportType(TempConversionRuleArray, DataStructure.RefType);
			
		Else
			
			CurrentExportRuleRow = LastExportRulesString;	
			
		EndIf;
		
		ObjectForExportRules = Data;
		
		ExportingRegister = True;
		
	EndIf;
	
EndProcedure

Function ExecuteExchangeNodeChangedDataExport(ExchangeNode, ConversionRuleArray, StructureForChangeRecordDeletion)
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ApplicationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	StructureForChangeRecordDeletion.Insert("OCRArray", Undefined);
	StructureForChangeRecordDeletion.Insert("MessageNo", Undefined);
	
	XMLWriter = New XMLWriter();
	XMLWriter.SetString();
	
	// Creating a new message.
	WriteMessage = ExchangePlans.CreateMessageWriter();
		
	WriteMessage.BeginWrite(XMLWriter, ExchangeNode);
	
	// Counting the number of written objects.
	FoundObjectToWriteCount = 0;
	
	LastMetadataObject = Undefined;
	LastExportRuleString = Undefined;
	
	CurrentMetadataObject = Undefined;
	CurrentExportRuleRow = Undefined;
	
	OutgoingData = Undefined;
	
	TempConversionRuleArray = CopyExportRuleArray(ConversionRuleArray);
	
	Cancel			= False;
	OutgoingData	= Undefined;
	DataSelection	= Undefined;
	
	ObjectForExportRules = Undefined;
	ConstantsWereExported = False;
	// Beginning a transaction
	If UseTransactionsOnExportForExchangePlans Then
		BeginTransaction();
	EndIf;
	
	Try
	
		// Getting changed data selection.
		MetadataToExportArray = New Array();
				
		// Complement the array with only this metadata for which there are rules for export. Other metadata does not matter.
		For Each ExportRuleString In TempConversionRuleArray Do
			
			DERMetadata = Metadata.FindByType(ExportRuleString.SelectionObject);
			MetadataToExportArray.Add(DERMetadata);
			
		EndDo;
		
		ChangesSelection = ExchangePlans.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo, MetadataToExportArray);
		
		StructureForChangeRecordDeletion.MessageNo = WriteMessage.MessageNo;
		
		While ChangesSelection.Next() Do
					
			Data = ChangesSelection.Get();
			FoundObjectToWriteCount = FoundObjectToWriteCount + 1;
			
			ExportDataType = TypeOf(Data); 
			
			Delete = (ExportDataType = deObjectDeletionType);
			
			// Skipping deletion.
			If Delete Then
				Continue;
			EndIf;
			
			CurrentMetadataObject = Data.Metadata();
			
			// Processing data received from the exchange node. Using this data, determining the conversion rule 
			// and exporting data.
			
			ExportingRegister = False;
			ExportingConstants = False;
			
			GetExportRuleRowByExchangeObject(Data, LastMetadataObject, CurrentMetadataObject,
				LastExportRuleString, CurrentExportRuleRow, TempConversionRuleArray, ObjectForExportRules,
				ExportingRegister, ExportingConstants, ConstantsWereExported);
				
			If LastMetadataObject <> CurrentMetadataObject Then
				
				// after processing
				If LastExportRuleString <> Undefined Then
			
					If Not IsBlankString(LastExportRuleString.AfterProcess) Then
					
						Try
							
							If HandlersDebugModeFlag Then
								
								Execute(GetHandlerCallString(LastExportRuleString, "AfterProcess"));
								
							Else
								
								Execute(LastExportRuleString.AfterProcess);
								
							EndIf;
							
						Except
							
							WriteErrorInfoDERHandlers(32, ErrorDescription(), LastExportRuleString.Name, "AfterProcessDataExport");
							
						EndTry;
						
					EndIf;
					
				EndIf;
				
				// before processing
				If CurrentExportRuleRow <> Undefined Then
					
					If CommentObjectProcessingFlag Then
						
						MessageString = SubstituteParametersToString(NStr("ru = 'Правило выгрузки данных: %1 (%2)'; en = 'Data export rule: %1 (%2)'; pl = 'Reguła wyładunku danych: %1(%2)';es_ES = 'Regla de exportación de datos: %1 (%2)';es_CO = 'Regla de exportación de datos: %1 (%2)';tr = 'Veri dışa aktarma kuralı : %1 (%2)';it = 'Regola esportazione dati: %1 (%2)';de = 'Datenexport-regel: %1 (%2)'"),
							TrimAll(CurrentExportRuleRow.Name), TrimAll(CurrentExportRuleRow.Description));
						WriteToExecutionProtocol(MessageString, , False, , 4);
						
					EndIf;
					
					// BeforeProcess handle
					Cancel			= False;
					OutgoingData	= Undefined;
					DataSelection	= Undefined;
					
					If Not IsBlankString(CurrentExportRuleRow.BeforeProcess) Then
					
						Try
							
							If HandlersDebugModeFlag Then
								
								Execute(GetHandlerCallString(CurrentExportRuleRow, "BeforeProcess"));
								
							Else
								
								Execute(CurrentExportRuleRow.BeforeProcess);
								
							EndIf;
							
						Except
							
							WriteErrorInfoDERHandlers(31, ErrorDescription(), CurrentExportRuleRow.Name, "BeforeProcessDataExport");
							
						EndTry;
						
					EndIf;
					
					If Cancel Then
						
						// Deleting the rule from rule array.
						CurrentExportRuleRow = Undefined;
						DeleteExportRuleTreeRowByExportTypeFromArray(TempConversionRuleArray, CurrentExportRuleRow);
						ObjectForExportRules = Undefined;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
			// There is a rule to export data.
			If CurrentExportRuleRow <> Undefined Then
				
				If ExportingRegister Then
					
					For Each RegisterLine In ObjectForExportRules Do
						ExportSelectionObject(RegisterLine, CurrentExportRuleRow, , OutgoingData);
					EndDo;
					
				ElsIf ExportingConstants Then
					
					Properties	= Managers[CurrentExportRuleRow.SelectionObject];
					ExportConstantsSet(CurrentExportRuleRow, Properties, OutgoingData);
					
				Else
				
					ExportSelectionObject(ObjectForExportRules, CurrentExportRuleRow, , OutgoingData);
				
				EndIf;
				
			EndIf;
			
			LastMetadataObject = CurrentMetadataObject;
			LastExportRuleString = CurrentExportRuleRow; 
			
			If ProcessedObjectsCountToUpdateStatus > 0 
				AND FoundObjectToWriteCount % ProcessedObjectsCountToUpdateStatus = 0 Then
				
				Try
					MetadataName = CurrentMetadataObject.FullName();
				Except
					MetadataName = "";
				EndTry;
				
			EndIf;
			
			If UseTransactionsOnExportForExchangePlans 
				AND (TransactionItemsCountOnExportForExchangePlans > 0)
				AND (FoundObjectToWriteCount = TransactionItemsCountOnExportForExchangePlans) Then
				
				// Completing the subtransaction and beginning a new one.
				CommitTransaction();
				BeginTransaction();
				
				FoundObjectToWriteCount = 0;
			EndIf;
			
		EndDo;
		
		// Finishing writing the message.
		WriteMessage.EndWrite();
		
		XMLWriter.Close();
		
		If UseTransactionsOnExportForExchangePlans Then
			CommitTransaction();
		EndIf;
		
	Except
		
		If UseTransactionsOnExportForExchangePlans Then
			RollbackTransaction();
		EndIf;
		
		WP = GetProtocolRecordStructure(72, ErrorDescription());
		WP.ExchangePlanNode  = ExchangeNode;
		WP.Object = Data;
		WP.ObjectType = ExportDataType;
		
		ErrorMessageString = WriteToExecutionProtocol(72, WP, True);
						
		XMLWriter.Close();
		
		Return False;
		
	EndTry;
	
	// Event after processing
	If LastExportRuleString <> Undefined Then
	
		If Not IsBlankString(LastExportRuleString.AfterProcess) Then
		
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(LastExportRuleString, "AfterProcess"));
					
				Else
					
					Execute(LastExportRuleString.AfterProcess);
					
				EndIf;
				
			Except
				WriteErrorInfoDERHandlers(32, ErrorDescription(), LastExportRuleString.Name, "AfterProcessDataExport");
				
			EndTry;
			
		EndIf;
		
	EndIf;
	
	StructureForChangeRecordDeletion.OCRArray = TempConversionRuleArray;
	
	Return Not Cancel;
	
EndFunction

Function ProcessExportForExchangePlans(NodeAndExportRuleMap, StructureForChangeRecordDeletion)
	
	ExportSuccessful = True;
	
	For Each MapRow In NodeAndExportRuleMap Do
		
		ExchangeNode = MapRow.Key;
		ConversionRuleArray = MapRow.Value;
		
		LocalStructureForChangeRecordDeletion = New Structure();
		
		CurrentExportSuccessful = ExecuteExchangeNodeChangedDataExport(ExchangeNode, ConversionRuleArray, LocalStructureForChangeRecordDeletion);
		
		ExportSuccessful = ExportSuccessful AND CurrentExportSuccessful;
		
		If LocalStructureForChangeRecordDeletion.OCRArray <> Undefined
			AND LocalStructureForChangeRecordDeletion.OCRArray.Count() > 0 Then
			
			StructureForChangeRecordDeletion.Insert(ExchangeNode, LocalStructureForChangeRecordDeletion);	
			
		EndIf;
		
	EndDo;
	
	Return ExportSuccessful;
	
EndFunction

Procedure ProcessExchangeNodeRecordChangeEditing(NodeAndExportRuleMap)
	
	For Each Item In NodeAndExportRuleMap Do
	
		If ChangesRegistrationDeletionTypeForExportedExchangeNodes = 0 Then
			
			Return;
			
		ElsIf ChangesRegistrationDeletionTypeForExportedExchangeNodes = 1 Then
			
			// Deleting registration of all changes that are in the exchange plan.
			ExchangePlans.DeleteChangeRecords(Item.Key, Item.Value.MessageNo);
			
		ElsIf ChangesRegistrationDeletionTypeForExportedExchangeNodes = 2 Then	
			
			// Deleting changes of metadata of the first level exported objects.
			
			For Each ExportedOCR In Item.Value.OCRArray Do
				
				Rule = Rules[ExportedOCR.ConversionRule];
				
				If ValueIsFilled(Rule.Source) Then
					
					Manager = Managers[Rule.Source];
					
					ExchangePlans.DeleteChangeRecords(Item.Key, Manager.MetadateObject);
					
				EndIf;
				
			EndDo;
			
		EndIf;
	
	EndDo;
	
EndProcedure

Function DeleteProhibitedXMLChars(Val Text)
	
	Return ReplaceProhibitedXMLChars(Text, "");
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsToExport

// Opens an exchange file and reads attributes of file master node according to the exchange format.
//
// Parameters:
//  ReadHeaderOnly - Boolean. If True, then file closes after reading the exchange file header 
//  (master node).
//
Procedure OpenImportFile(ReadHeaderOnly=False, ExchangeFileData = "") Export

	If IsBlankString(ExchangeFileName) AND ReadHeaderOnly Then
		StartDate         = "";
		EndDate      = "";
		DataExportDate = "";
		ExchangeRulesVersion = "";
		Comment        = "";
		Return;
	EndIf;


    DataImportFileName = ExchangeFileName;
	
	
	// Archive files are recognized by the ZIP extension.
	If StrFind(ExchangeFileName, ".zip") > 0 Then
		
		DataImportFileName = UnpackZipFile(ExchangeFileName);		 
		
	EndIf; 
	
	
	ErrorFlag = False;
	ExchangeFile = New XMLReader();

	Try
		If NOT IsBlankString(ExchangeFileData) Then
			ExchangeFile.SetString(ExchangeFileData);
		Else
			ExchangeFile.OpenFile(DataImportFileName);
		EndIf;
	Except
		WriteToExecutionProtocol(5);
		Return;
	EndTry;
	
	ExchangeFile.Read();


	mExchangeFileAttributes = New Structure;
	
	
	If ExchangeFile.LocalName = "ExchangeFile" Then
		
		mExchangeFileAttributes.Insert("FormatVersion",            deAttribute(ExchangeFile, deStringType, "FormatVersion"));
		mExchangeFileAttributes.Insert("ExportDate",             deAttribute(ExchangeFile, deDateType,   "ExportDate"));
		mExchangeFileAttributes.Insert("ExportPeriodStart",    deAttribute(ExchangeFile, deDateType,   "ExportPeriodStart"));
		mExchangeFileAttributes.Insert("ExportPeriodEnd", deAttribute(ExchangeFile, deDateType,   "ExportPeriodEnd"));
		mExchangeFileAttributes.Insert("SourceConfigurationName", deAttribute(ExchangeFile, deStringType, "SourceConfigurationName"));
		mExchangeFileAttributes.Insert("DestinationConfigurationName", deAttribute(ExchangeFile, deStringType, "DestinationConfigurationName"));
		mExchangeFileAttributes.Insert("ConversionRuleIDs",      deAttribute(ExchangeFile, deStringType, "ConversionRuleIDs"));
		
		StartDate         = mExchangeFileAttributes.ExportPeriodStart;
		EndDate      = mExchangeFileAttributes.ExportPeriodEnd;
		DataExportDate = mExchangeFileAttributes.ExportDate;
		Comment        = deAttribute(ExchangeFile, deStringType, "Comment");
		
	Else
		
		WriteToExecutionProtocol(9);
		Return;
		
	EndIf;


	ExchangeFile.Read();
			
	NodeName = ExchangeFile.LocalName;
		
	If NodeName = "ExchangeRules" Then
		If SafeImport AND ValueIsFilled(ExchangeRuleFileName) Then
			ImportExchangeRules(ExchangeRuleFileName, "XMLFile");
			ExchangeFile.Skip();
		Else
			ImportExchangeRules(ExchangeFile, "XMLReader");
		EndIf;				
	Else
		ExchangeFile.Close();
		ExchangeFile = New XMLReader();
		Try
			
			If NOT IsBlankString(ExchangeFileData) Then
				ExchangeFile.SetString(ExchangeFileData);
			Else
				ExchangeFile.OpenFile(DataImportFileName);
			EndIf;
			
		Except
			
			WriteToExecutionProtocol(5);
			Return;
			
		EndTry;
		
		ExchangeFile.Read();
		
	EndIf; 
	
	mExchangeRulesReadOnImport = True;

	If ReadHeaderOnly Then
		
		ExchangeFile.Close();
		Return;
		
	EndIf;
   
EndProcedure

Function RefreshAllExportRuleParentMarks(ExportRuleTreeRows, MustSetMarks = True)
	
	If ExportRuleTreeRows.Rows.Count() = 0 Then
		
		If MustSetMarks Then
			SetParentMarks(ExportRuleTreeRows, "Enable");	
		EndIf;
		
		Return True;
		
	Else
		
		MarksRequired = True;
		
		For Each RuleTreeRow In ExportRuleTreeRows.Rows Do
			
			SetupResult = RefreshAllExportRuleParentMarks(RuleTreeRow, MarksRequired);
			If MarksRequired = True Then
				MarksRequired = False;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndFunction

Procedure FillPropertiesForSearch(DataStructure, PCR)
	
	For Each FieldsString In PCR Do
		
		If FieldsString.IsFolder Then
						
			If FieldsString.DestinationKind = "TabularSection" 
				OR StrFind(FieldsString.DestinationKind, "RecordSet") > 0 Then
				
				DestinationStructureName = FieldsString.Destination + ?(FieldsString.DestinationKind = "TabularSection", "TabularSection", "RecordSet");
				
				InternalStructure = DataStructure[DestinationStructureName];
				
				If InternalStructure = Undefined Then
					InternalStructure = New Map();
				EndIf;
				
				DataStructure[DestinationStructureName] = InternalStructure;
				
			Else
				
				InternalStructure = DataStructure;	
				
			EndIf;
			
			FillPropertiesForSearch(InternalStructure, FieldsString.GroupRules);
									
		Else
			
			If IsBlankString(FieldsString.DestinationType)	Then
				
				Continue;
				
			EndIf;
			
			DataStructure[FieldsString.Destination] = FieldsString.DestinationType;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DeleteExcessiveItemsFromMap(DataStructure)
	
	For Each Item In DataStructure Do
		
		If TypeOf(Item.Value) = deMapType Then
			
			DeleteExcessiveItemsFromMap(Item.Value);
			
			If Item.Value.Count() = 0 Then
				DataStructure.Delete(Item.Key);
			EndIf;
			
		EndIf;		
		
	EndDo;		
	
EndProcedure

Procedure FillInformationByDestinationDataTypes(DataStructure, Rules)
	
	For Each Row In Rules Do
		
		If IsBlankString(Row.Destination) Then
			Continue;
		EndIf;
		
		StructureData = DataStructure[Row.Destination];
		If StructureData = Undefined Then
			
			StructureData = New Map();
			DataStructure[Row.Destination] = StructureData;
			
		EndIf;
		
		// Passing through search fields and PCR and writing data types.
		FillPropertiesForSearch(StructureData, Row.SearchProperties);
				
		// Properties
		FillPropertiesForSearch(StructureData, Row.Properties);
		
	EndDo;
	
	DeleteExcessiveItemsFromMap(DataStructure);	
	
EndProcedure

Procedure CreateStringWithPropertyTypes(XMLWriter, PropertyTypes)
	
	If TypeOf(PropertyTypes.Value) = deMapType Then
		
		If PropertyTypes.Value.Count() = 0 Then
			Return;
		EndIf;
		
		XMLWriter.WriteStartElement(PropertyTypes.Key);
		
		For Each Item In PropertyTypes.Value Do
			CreateStringWithPropertyTypes(XMLWriter, Item);
		EndDo;
		
		XMLWriter.WriteEndElement();
		
	Else		
		
		deWriteElement(XMLWriter, PropertyTypes.Key, PropertyTypes.Value);
		
	EndIf;
	
EndProcedure

Function CreateTypesStringForDestination(DataStructure)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteStartElement("DataTypeInformation");	
	
	For Each Row In DataStructure Do
		
		XMLWriter.WriteStartElement("DataType");
		SetAttribute(XMLWriter, "Name", Row.Key);
		
		For Each SubordinationRow In Row.Value Do
			
			CreateStringWithPropertyTypes(XMLWriter, SubordinationRow);	
			
		EndDo;
		
		XMLWriter.WriteEndElement();
		
	EndDo;	
	
	XMLWriter.WriteEndElement();
	
	ResultString = XMLWriter.Close();
	Return ResultString;
	
EndFunction

Procedure ImportSingleTypeData(ExchangeRules, TypeMap, LocalItemName)
	
	NodeName = LocalItemName;
	
	ExchangeRules.Read();
	
	If (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
		
		ExchangeRules.Read();
		Return;
		
	ElsIf ExchangeRules.NodeType = deXMLNodeType_StartElement Then
			
		// this is a new item
		NewMap = New Map;
		TypeMap.Insert(NodeName, NewMap);
		
		ImportSingleTypeData(ExchangeRules, NewMap, ExchangeRules.LocalName);			
		ExchangeRules.Read();
		
	Else
		TypeMap.Insert(NodeName, Type(ExchangeRules.Value));
		ExchangeRules.Read();
	EndIf;	
	
	ImportTypeMapForSingleType(ExchangeRules, TypeMap);
	
EndProcedure

Procedure ImportTypeMapForSingleType(ExchangeRules, TypeMap)
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
			
		    Break;
			
		EndIf;
		
		// Reading the element start
		ExchangeRules.Read();
		
		If ExchangeRules.NodeType = deXMLNodeType_StartElement Then
			
			// this is a new item
			NewMap = New Map;
			TypeMap.Insert(NodeName, NewMap);
			
			ImportSingleTypeData(ExchangeRules, NewMap, ExchangeRules.LocalName);			
			
		Else
			TypeMap.Insert(NodeName, Type(ExchangeRules.Value));
			ExchangeRules.Read();
		EndIf;	
		
	EndDo;	
	
EndProcedure

Procedure ImportDataTypeInformation()
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "DataType" Then
			
			TypeName = deAttribute(ExchangeFile, deStringType, "Name");
			
			TypeMap = New Map;
			mDataTypeMapForImport.Insert(Type(TypeName), TypeMap);

			ImportTypeMapForSingleType(ExchangeFile, TypeMap);	
			
		ElsIf (NodeName = "DataTypeInformation") AND (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;	
	
EndProcedure

Procedure ImportDataExchangeParameterValues()
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ApplicationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	Name = deAttribute(ExchangeFile, deStringType, "Name");
		
	PropertyType = GetPropertyTypeByAdditionalData(Undefined, Name);
	
	Value = ReadProperty(PropertyType);
	
	Parameters.Insert(Name, Value);	
	
	AfterParameterImportAlgorithm = "";
	If EventsAfterParameterImport.Property(Name, AfterParameterImportAlgorithm)
		AND Not IsBlankString(AfterParameterImportAlgorithm) Then
		
		If HandlersDebugModeFlag Then
			
			Raise NStr("ru = 'Отладка обработчика ""После загрузки параметра"" не поддерживается.'; en = 'Debugging of handler ""After parameter import"" is not supported.'; pl = 'Debugowanie programu obsługi ""Po imporcie parametru"" nie jest obsługiwane.';es_ES = 'Depuración del manipulador ""Después de la importación del parámetro"" no está admitida.';es_CO = 'Depuración del manipulador ""Después de la importación del parámetro"" no está admitida.';tr = '""Parametre içe aktarımından sonrası"" işleyicinin hata ayıklama desteklenmiyor.';it = 'Debug di gestore ""Dopo il parametro di importazione"" non è supportato.';de = 'Das Debugging des Handlers ""Nach dem Parameterimport"" wird nicht unterstützt.'");
			
		Else
			
			Execute(AfterParameterImportAlgorithm);
			
		EndIf;
		
	EndIf;
		
EndProcedure

Function GetHandlerValueFromText(ExchangeRules)
	
	HandlerText = deElementValue(ExchangeRules, deStringType);
	
	If StrFind(HandlerText, Chars.LF) = 0 Then
		Return HandlerText;
	EndIf;
	
	HandlerText = StrReplace(HandlerText, Char(10), Chars.LF);
	
	Return HandlerText;
	
EndFunction

// Imports exchange rules according to the format.
//
// Parameters:
//  Source - object where the exchange rules are imported from.
//  SourceType    - a string indicating the source type: "XMLFile", "ReadingXML", "String".
// 
Procedure ImportExchangeRules(Source="", SourceType="XMLFile") Export
	
	InitManagersAndMessages();
	
	HasBeforeExportObjectGlobalHandler    = False;
	HasAfterExportObjectGlobalHandler     = False;
	
	HasBeforeConvertObjectGlobalHandler = False;

	HasBeforeImportObjectGlobalHandler    = False;
	HasAfterImportObjectGlobalHandler     = False;
	
	CreateConversionStructure();
	
	mPropertyConversionRuleTable = New ValueTable;
	InitPropertyConversionRuleTable(mPropertyConversionRuleTable);
	SupplementServiceTablesWithColumns();
	
	// Perhaps, embedded exchange rules are selected (one of templates.
	
	ExchangeRuleTempFileName = "";
	If IsBlankString(Source) Then
		
		Source = ExchangeRuleFileName;
		If mExchangeRuleTemplateList.FindByValue(Source) <> Undefined Then
			For each Template In Metadata().Templates Do
				If Template.Synonym = Source Then
					Source = Template.Name;
					Break;
				EndIf; 
			EndDo; 
			ExchangeRuleTemplate              = GetTemplate(Source);
			ExchangeRuleTempFileName = GetTempFileName("xml");
			ExchangeRuleTemplate.Write(ExchangeRuleTempFileName);
			Source = ExchangeRuleTempFileName;
		EndIf;
		
	EndIf;

	
	If SourceType="XMLFile" Then
		
		If IsBlankString(Source) Then
			WriteToExecutionProtocol(12);
			Return; 
		EndIf;
		
		File = New File(Source);
		If Not File.Exist() Then
			WriteToExecutionProtocol(3);
			Return; 
		EndIf;
		
		RuleFilePacked = (File.Extension = ".zip");
		
		If RuleFilePacked Then
			
			// Unpacking the rule file
			Source = UnpackZipFile(Source);
			
		EndIf;
		
		ExchangeRules = New XMLReader();
		ExchangeRules.OpenFile(Source);
		ExchangeRules.Read();
		
	ElsIf SourceType="String" Then
		
		ExchangeRules = New XMLReader();
		ExchangeRules.SetString(Source);
		ExchangeRules.Read();
		
	ElsIf SourceType="XMLReader" Then
		
		ExchangeRules = Source;
		
	EndIf; 
	

	If Not ((ExchangeRules.LocalName = "ExchangeRules") AND (ExchangeRules.NodeType = deXMLNodeType_StartElement)) Then
		WriteToExecutionProtocol(6);
		Return;
	EndIf;


	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.Indent = True;
	XMLWriter.WriteStartElement("ExchangeRules");
	

	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		// Conversion attributes
		If NodeName = "FormatVersion" Then
			Value = deElementValue(ExchangeRules, deStringType);
			Conversion.Insert("FormatVersion", Value);
			deWriteElement(XMLWriter, NodeName, Value);
		ElsIf NodeName = "ID" Then
			Value = deElementValue(ExchangeRules, deStringType);
			Conversion.Insert("ID",                   Value);
			deWriteElement(XMLWriter, NodeName, Value);
		ElsIf NodeName = "Description" Then
			Value = deElementValue(ExchangeRules, deStringType);
			Conversion.Insert("Description",         Value);
			deWriteElement(XMLWriter, NodeName, Value);
		ElsIf NodeName = "CreationDateTime" Then
			Value = deElementValue(ExchangeRules, deDateType);
			Conversion.Insert("CreationDateTime",    Value);
			deWriteElement(XMLWriter, NodeName, Value);
			ExchangeRulesVersion = Conversion.CreationDateTime;
		ElsIf NodeName = "Source" Then
			Value = deElementValue(ExchangeRules, deStringType);
			Conversion.Insert("Source",             Value);
			deWriteElement(XMLWriter, NodeName, Value);
		ElsIf NodeName = "Destination" Then
			
			DestinationPlatformVersion = ExchangeRules.GetAttribute ("PlatformVersion");
			DestinationPlatform = GetPlatformByDestinationPlatformVersion(DestinationPlatformVersion);
			
			Value = deElementValue(ExchangeRules, deStringType);
			Conversion.Insert("Destination",             Value);
			deWriteElement(XMLWriter, NodeName, Value);
			
		ElsIf NodeName = "DeleteMappedObjectsFromDestinationOnDeleteFromSource" Then
			deSkip(ExchangeRules);
		
		ElsIf NodeName = "Comment" Then
			deSkip(ExchangeRules);
			
		ElsIf NodeName = "MainExchangePlan" Then
			deSkip(ExchangeRules);

		ElsIf NodeName = "Parameters" Then
			ImportParameters(ExchangeRules, XMLWriter)

		// Conversion events
		
		ElsIf NodeName = "" Then
			
		ElsIf NodeName = "AfterImportExchangeRules" Then
			If ExchangeMode = "Load" Then
				ExchangeRules.Skip();
			Else
				Conversion.Insert("AfterImportExchangeRules", GetHandlerValueFromText(ExchangeRules));
			EndIf;
		ElsIf NodeName = "BeforeExportData" Then
			Conversion.Insert("BeforeExportData", GetHandlerValueFromText(ExchangeRules));
			
		ElsIf NodeName = "AfterExportData" Then
			Conversion.Insert("AfterExportData",  GetHandlerValueFromText(ExchangeRules));

		ElsIf NodeName = "BeforeExportObject" Then
			Conversion.Insert("BeforeExportObject", GetHandlerValueFromText(ExchangeRules));
			HasBeforeExportObjectGlobalHandler = Not IsBlankString(Conversion.BeforeExportObject);

		ElsIf NodeName = "AfterExportObject" Then
			Conversion.Insert("AfterExportObject", GetHandlerValueFromText(ExchangeRules));
			HasAfterExportObjectGlobalHandler = Not IsBlankString(Conversion.AfterExportObject);

		ElsIf NodeName = "BeforeImportObject" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Load" Then
				
				Conversion.Insert("BeforeImportObject", Value);
				HasBeforeImportObjectGlobalHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "AfterImportObject" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Load" Then
				
				Conversion.Insert("AfterImportObject", Value);
				HasAfterImportObjectGlobalHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "BeforeConvertObject" Then
			Conversion.Insert("BeforeConvertObject", GetHandlerValueFromText(ExchangeRules));
			HasBeforeConvertObjectGlobalHandler = Not IsBlankString(Conversion.BeforeConvertObject);
			
		ElsIf NodeName = "BeforeImportData" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Load" Then
				
				Conversion.BeforeImportData = Value;
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "AfterImportData" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Load" Then
				
				Conversion.AfterImportData = Value;
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "AfterImportParameters" Then
			Conversion.Insert("AfterImportParameters", GetHandlerValueFromText(ExchangeRules));
			
		ElsIf NodeName = "BeforeSendDeletionInfo" Then
			Conversion.Insert("BeforeSendDeletionInfo",  deElementValue(ExchangeRules, deStringType));
			
		ElsIf NodeName = "BeforeGetChangedObjects" Then
			Conversion.Insert("BeforeGetChangedObjects", deElementValue(ExchangeRules, deStringType));
			
		ElsIf NodeName = "OnGetDeletionInfo" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Load" Then
				
				Conversion.Insert("OnGetDeletionInfo", Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "AfterGetExchangeNodesInformation" Then
			
			Value = GetHandlerValueFromText(ExchangeRules);
			
			If ExchangeMode = "Load" Then
				
				Conversion.Insert("AfterGetExchangeNodesInformation", Value);
				
			Else
				
				deWriteElement(XMLWriter, NodeName, Value);
				
			EndIf;

		// Rules
		
		ElsIf NodeName = "DataExportRules" Then
		
 			If ExchangeMode = "Load" Then
				deSkip(ExchangeRules);
			Else
				ImportExportRules(ExchangeRules);
 			EndIf; 
			
		ElsIf NodeName = "ObjectConversionRules" Then
			ImportConversionRules(ExchangeRules, XMLWriter);
			
		ElsIf NodeName = "DataClearingRules" Then
			ImportClearingRules(ExchangeRules, XMLWriter)
			
		ElsIf NodeName = "ObjectsRegistrationRules" Then
			deSkip(ExchangeRules); // Object registration rules are imported with another data processor.
			
		// Algorithms, Queries, DataProcessors.
		
		ElsIf NodeName = "Algorithms" Then
			ImportAlgorithms(ExchangeRules, XMLWriter);
			
		ElsIf NodeName = "Queries" Then
			ImportQueries(ExchangeRules, XMLWriter);

		ElsIf NodeName = "DataProcessors" Then
			ImportDataProcessors(ExchangeRules, XMLWriter);
			
		// Exit
		ElsIf (NodeName = "ExchangeRules") AND (ExchangeRules.NodeType = deXMLNodeType_EndElement) Then
		
			If ExchangeMode <> "Load" Then
				ExchangeRules.Close();
			EndIf;
			Break;

			
		// Format error
		Else
		    RecordStructure = New Structure("NodeName", NodeName);
			WriteToExecutionProtocol(7, RecordStructure);
			Return;
		EndIf;
	EndDo;


	XMLWriter.WriteEndElement();
	mXMLRules = XMLWriter.Close();
	
	For Each ExportRulesString In ExportRuleTable.Rows Do
		RefreshAllExportRuleParentMarks(ExportRulesString, True);
	EndDo;
	
	// Deleting the temporary rule file.
	If Not IsBlankString(ExchangeRuleTempFileName) Then
		Try
 			DeleteFiles(ExchangeRuleTempFileName);
		Except 
			WriteLogEvent(NStr("ru = 'Универсальный обмен данными в формате XML'; en = 'Universal data exchange in XML format'; pl = 'Uniwersalna wymiana danymi w formacie XML';es_ES = 'Intercambio de datos universal en el formato XML';es_CO = 'Intercambio de datos universal en el formato XML';tr = 'XML formatında üniversal veri değişimi';it = 'Scambio di dati universale in formato XML';de = 'Universeller Datenaustausch im XML-Format'", DefaultLanguageCode()),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
	EndIf;
	
	If SourceType="XMLFile"
		AND RuleFilePacked Then
		
		Try
			DeleteFiles(Source);
		Except 
			WriteLogEvent(NStr("ru = 'Универсальный обмен данными в формате XML'; en = 'Universal data exchange in XML format'; pl = 'Uniwersalna wymiana danymi w formacie XML';es_ES = 'Intercambio de datos universal en el formato XML';es_CO = 'Intercambio de datos universal en el formato XML';tr = 'XML formatında üniversal veri değişimi';it = 'Scambio di dati universale in formato XML';de = 'Universeller Datenaustausch im XML-Format'", DefaultLanguageCode()),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndIf;
	
	// Information on destination data types is required for quick data import.
	DataStructure = New Map();
	FillInformationByDestinationDataTypes(DataStructure, ConversionRulesTable);
	
	mTypesForDestinationRow = CreateTypesStringForDestination(DataStructure);
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ApplicationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	// Event call is required after importing the exchange rules.
	AfterExchangeRuleImportEventText = "";
	If Conversion.Property("AfterImportExchangeRules", AfterExchangeRuleImportEventText)
		AND Not IsBlankString(AfterExchangeRuleImportEventText) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Raise NStr("ru = 'Отладка обработчика ""После загрузки правил обмена"" не поддерживается.'; en = '""After exchange rule import"" handler debugging is not supported.'; pl = 'Debugowanie programu obsługi ""Po zaimportowaniu reguł wymiany"" nie jest obsługiwane.';es_ES = 'Depuración del manipulador ""Después de la importación de las reglas de intercambio"" no está admitida.';es_CO = 'Depuración del manipulador ""Después de la importación de las reglas de intercambio"" no está admitida.';tr = '""Alışveriş kuralları içe aktarıldıktan sonra"" işleyicinin hata ayıklaması desteklenmiyor.';it = 'Il debug di elaboratore ""Dopo il download delle regole di scambio"" non è supportato.';de = 'Das Debuggen des Handlers ""Nach dem Austausch von Regeln"" wird nicht unterstützt.'");
				
			Else
				
				Execute(AfterExchangeRuleImportEventText);
				
			EndIf;
			
		Except
			
			Text = NStr("ru = 'Обработчик: ""AfterExchangeRuleImport"": %1'; en = 'AfterExchangeRuleImport handler: %1'; pl = 'Obsługa AfterExchangeRuleImport: %1';es_ES = 'Manipulador: ""AfterExchangeRulesImport"": %1';es_CO = 'Manipulador: ""AfterExchangeRulesImport"": %1';tr = 'Işleyici: ""AfterExchangeRuleImport"": %1';it = 'AfterExchangeRuleImport gestore: %1';de = 'Handler AfterExchangeRuleImport: %1'");
			Text = SubstituteParametersToString(Text, BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(NStr("ru = 'Универсальный обмен данными в формате XML'; en = 'Universal data exchange in XML format'; pl = 'Uniwersalna wymiana danymi w formacie XML';es_ES = 'Intercambio de datos universal en el formato XML';es_CO = 'Intercambio de datos universal en el formato XML';tr = 'XML formatında üniversal veri değişimi';it = 'Scambio di dati universale in formato XML';de = 'Universeller Datenaustausch im XML-Format'", DefaultLanguageCode()),
				EventLogLevel.Error,,, Text);
				
			MessageToUser(Text);
			
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure ProcessNewItemReadEnd(LastImportObject)
	
	mImportedObjectCounter = 1 + mImportedObjectCounter;
				
	If mImportedObjectCounter % ProcessedObjectsCountToUpdateStatus = 0 Then
		
		If LastImportObject <> Undefined Then
			
			ImportObjectString = ", Object: " + String(TypeOf(LastImportObject)) + "  " + String(LastImportObject);
								
		Else
			
			ImportObjectString = "";
			
		EndIf;
		
	EndIf;
	
	If RememberImportedObjects
		AND mImportedObjectCounter % 100 = 0 Then
				
		If ImportedObjects.Count() > ImportedObjectToStoreCount Then
			ImportedObjects.Clear();
		EndIf;
				
	EndIf;
	
	If mImportedObjectCounter % 100 = 0
		AND mNotWrittenObjectGlobalStack.Count() > 100 Then
		
		ExecuteWriteNotWrittenObjects();
		
	EndIf;
	
	If UseTransactions
		AND ObjectCountPerTransaction > 0 
		AND mImportedObjectCounter % ObjectCountPerTransaction = 0 Then
		
		CommitTransaction();
		BeginTransaction();
		
	EndIf;	

EndProcedure

// Sequentially reads files of exchange message and writes data to the infobase.
//
// Parameters:
//  ErrorInfoResultString - String - an error info result string.
// 
Procedure ReadData(ErrorInfoResultString = "") Export
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ApplicationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	Try
	
		While ExchangeFile.Read() Do
			
			NodeName = ExchangeFile.LocalName;
			
			If NodeName = "Object" Then
				
				LastImportObject = ReadObject();
				
				ProcessNewItemReadEnd(LastImportObject);
				
			ElsIf NodeName = "ParameterValue" Then	
				
				ImportDataExchangeParameterValues();
				
			ElsIf NodeName = "AfterParameterExportAlgorithm" Then	
				
				Cancel = False;
				CancelReason = "";
				
				AlgorithmText = "";
				Conversion.Property("AfterImportParameters", AlgorithmText);
				
				// On import in the safe mode the algorithm text is received when reading rules.
				// Otherwise you need to receive it from the exchange file.
				If IsBlankString(AlgorithmText) Then
					AlgorithmText = deElementValue(ExchangeFile, deStringType);
				Else
					ExchangeFile.Skip();
				EndIf;
				
				If Not IsBlankString(AlgorithmText) Then
				
					Try
						
						If HandlersDebugModeFlag Then
							
							Raise NStr("ru = 'Отладка обработчика ""После загрузки параметров"" не поддерживается.'; en = 'Debugging of handler ""After parameters import"" is not supported.'; pl = 'Debugowanie programu obsługi ""Po imporcie parametrów"" nie jest obsługiwane.';es_ES = 'Depuración del manipulador ""Después de la importación de los parámetros"" no está admitida.';es_CO = 'Depuración del manipulador ""Después de la importación de los parámetros"" no está admitida.';tr = '""Parametre içe aktarımından sonrası"" işleyicinin hata ayıklama desteklenmiyor.';it = 'Debug di gestore ""Dopo che i parametri di importazione"" non è supportato.';de = 'Das Debugging des Handlers ""Nach dem Import der Parameter"" wird nicht unterstützt.'");
							
						Else
							
							Execute(AlgorithmText);
							
						EndIf;
						
						If Cancel = True Then
							
							If Not IsBlankString(CancelReason) Then
								ExceptionString = SubstituteParametersToString(NStr("ru = 'Загрузка данных отменена по причине: %1'; en = 'Data import is canceled for the following reason: %1'; pl = 'Wczytywanie danych jest skasowane z powodu: %1';es_ES = 'Importación de datos se ha cancelado como: %1';es_CO = 'Importación de datos se ha cancelado como: %1';tr = 'Veri içe aktarımı aşağıdaki nedenle iptal edildi: %1';it = 'L''importazione dati è cancellata per il seguente motivo: %1';de = 'Der Datenimport wurde abgebrochen als: %1'"), CancelReason);
								Raise ExceptionString;
							Else
								Raise NStr("ru = 'Загрузка данных отменена'; en = 'Data import has been canceled.'; pl = 'Import danych został anulowany';es_ES = 'Importación de datos se ha cancelado';es_CO = 'Importación de datos se ha cancelado';tr = 'Verinin içe aktarımı iptal edildi';it = 'L''importazione dati è stata cancellata.';de = 'Der Datenimport wurde abgebrochen'");
							EndIf;
							
						EndIf;
						
					Except
												
						WP = GetProtocolRecordStructure(75, ErrorDescription());
						WP.Handler     = "AfterImportParameters";
						ErrorMessageString = WriteToExecutionProtocol(75, WP, True);
						
						If Not DebugModeFlag Then
							Raise ErrorMessageString;
						EndIf;
						
					EndTry;
					
				EndIf;				
				
			ElsIf NodeName = "Algorithm" Then
				
				AlgorithmText = deElementValue(ExchangeFile, deStringType);
				
				If Not IsBlankString(AlgorithmText) Then
				
					Try
						
						If HandlersDebugModeFlag Then
							
							Raise NStr("ru = 'Отладка глобального алгоритма не поддерживается.'; en = 'Global algorithm debugging is not supported.'; pl = 'Globalne debugowanie algorytmu nie jest obsługiwane.';es_ES = 'Depuración de algoritmos global no está admitida.';es_CO = 'Depuración de algoritmos global no está admitida.';tr = 'Global algoritma hata ayıklama desteklenmiyor.';it = 'L''algoritmo globale di debug non è supportato.';de = 'Das Debugging globaler Algorithmen wird nicht unterstützt.'");
							
						Else
							
							Execute(AlgorithmText);
							
						EndIf;
						
					Except
						
						WP = GetProtocolRecordStructure(39, ErrorDescription());
						WP.Handler     = "ExchangeFileAlgorithm";
						ErrorMessageString = WriteToExecutionProtocol(39, WP, True);
						
						If Not DebugModeFlag Then
							Raise ErrorMessageString;
						EndIf;
						
					EndTry;
					
				EndIf;
				
			ElsIf NodeName = "ExchangeRules" Then
				
				mExchangeRulesReadOnImport = True;
				
				If ConversionRulesTable.Count() = 0 Then
					ImportExchangeRules(ExchangeFile, "XMLReader");
				Else
					deSkip(ExchangeFile);
				EndIf;
				
			ElsIf NodeName = "DataTypeInformation" Then
				
				ImportDataTypeInformation();
				
			ElsIf (NodeName = "ExchangeFile") AND (ExchangeFile.NodeType = deXMLNodeType_EndElement) Then
				
			Else
				RecordStructure = New Structure("NodeName", NodeName);
				WriteToExecutionProtocol(9, RecordStructure);
			EndIf;
			
		EndDo;
		
	Except
		
		ErrorRow = SubstituteParametersToString(NStr("ru = 'Ошибка при загрузке данных: %1'; en = 'Error importing data: %1'; pl = 'Wystąpił błąd podczas importu danych: %1';es_ES = 'Ha ocurrido un error al importar los datos: %1';es_CO = 'Ha ocurrido un error al importar los datos: %1';tr = 'Veri içe aktarılırken bir hata oluştu: %1';it = 'Errore durante l''importazione dati: %1';de = 'Beim Importieren von Daten ist ein Fehler aufgetreten: %1'"), ErrorDescription());
		
		ErrorInfoResultString = WriteToExecutionProtocol(ErrorRow, Undefined, True, , , True);
		
		FinishKeepExchangeProtocol();
		ExchangeFile.Close();
		Return;
		
	EndTry;
	
EndProcedure

// Performs the following actions before reading data from the file:   - initializes variables;   - 
// imports exchange rules from the data file;   - begins a transaction for writing data to the 
// infobase;   - executes required event handlers.
// 
//
// Parameters:
//  DataString - an import file name or XML string containing data to import.
// 
//  Returns:
//  True if the data can be imported from file, otherwise False.
//
Function ExecuteActionsBeforeReadData(DataString = "") Export
	
	DataProcessingMode = mDataProcessingModes.Load;

	mExtendedSearchParameterMap       = New Map;
	mConversionRuleMap         = New Map;
	
	Rules.Clear();
	
	InitializeCommentsOnDataExportAndImport();
	
	InitializeKeepExchangeProtocol();
	
	ImportPossible = True;
	
	If IsBlankString(DataString) Then
	
		If IsBlankString(ExchangeFileName) Then
			WriteToExecutionProtocol(15);
			ImportPossible = False;
		EndIf;
	
	EndIf;
	
	// Initializing the external data processor with export handlers.
	InitEventHandlerExternalDataProcessor(ImportPossible, ThisObject);
	
	If Not ImportPossible Then
		Return False;
	EndIf;
	
	MessageString = SubstituteParametersToString(NStr("ru = 'Начало загрузки: %1'; en = 'Import started at: %1'; pl = 'Rozpocznij import: %1';es_ES = 'Inicio de la importación: %1';es_CO = 'Inicio de la importación: %1';tr = 'İçe aktarım başladı: %1';it = 'Importazione avviata alle: %1';de = 'Import Start: %1'"), CurrentSessionDate());
	WriteToExecutionProtocol(MessageString, , False, , , True);
	
	If DebugModeFlag Then
		UseTransactions = False;
	EndIf;
	
	If ProcessedObjectsCountToUpdateStatus = 0 Then
		
		ProcessedObjectsCountToUpdateStatus = 100;
		
	EndIf;
	
	mDataTypeMapForImport = New Map;
	mNotWrittenObjectGlobalStack = New Map;
	
	mImportedObjectCounter = 0;
	ErrorFlag                  = False;
	ImportedObjects          = New Map;
	ImportedGlobalObjects = New Map;

	InitManagersAndMessages();
	
	OpenImportFile(,DataString);
	
	If ErrorFlag Then 
		FinishKeepExchangeProtocol();
		Return False; 
	EndIf;

	// Defining handler interfaces.
	If HandlersDebugModeFlag Then
		
		SupplementRulesWithHandlerInterfaces(Conversion, ConversionRulesTable, ExportRuleTable, CleanupRulesTable);
		
	EndIf;
	
	// BeforeDataImport handler
	Cancel = False;
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ApplicationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	If Not IsBlankString(Conversion.BeforeImportData) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "BeforeImportData"));
				
			Else
				
				Execute(Conversion.BeforeImportData);
				
			EndIf;
			
		Except
			ErrorMessageString = WriteErrorInfoConversionHandlers(22, ErrorDescription(), NStr("ru = 'BeforeDataImport (конвертация)'; en = 'BeforeDataImport (conversion)'; pl = 'BeforeDataImport (Konwertowanie)';es_ES = 'BeforeDataImport (Conversión)';es_CO = 'BeforeDataImport (Conversión)';tr = 'BeforeDataImport (Dönüştürme)';it = 'BeforeDataImport (conversione)';de = 'BeforeDataImport (Konvertierung)'"));
			Cancel = True;
		EndTry;
		
		If Cancel Then // Canceling data import
			FinishKeepExchangeProtocol();
			ExchangeFile.Close();
			EventHandlerExternalDataProcessorDestructor();
			Return False;
		EndIf;
		
	EndIf;

	// Clearing infobase by rules.
	ProcessClearingRules(CleanupRulesTable.Rows);
	
	Return True;
	
EndFunction

// Performs the following actions after the data import iteration:
// - commits the transaction (if necessary)
// - closes the exchange message file;
// - executing the AfterDataImport handler conversion;
// - completing exchange logging (if necessary).
//
// Parameters:
//  No.
// 
Procedure ExecuteActionsAfterDataReadingCompleted() Export
	
	If SafeMode Then
		SetSafeMode(True);
		For Each SeparatorName In ApplicationSeparators Do
			SetDataSeparationSafeMode(SeparatorName, True);
		EndDo;
	EndIf;
	
	ExchangeFile.Close();
	
	// Handler AfterDataImport
	If Not IsBlankString(Conversion.AfterImportData) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "AfterImportData"));
				
			Else
				
				Execute(Conversion.AfterImportData);
				
			EndIf;
			
		Except
			ErrorMessageString = WriteErrorInfoConversionHandlers(23, ErrorDescription(), NStr("ru = 'AfterDataImport (конвертация)'; en = 'AfterDataImport (conversion)'; pl = 'AfterDataImport (konwertowanie)';es_ES = 'AfterDataImport (conversión)';es_CO = 'AfterDataImport (conversión)';tr = 'AfterDataImport (dönüştürme)';it = 'AfterDataImport (conversione)';de = 'AfterDataImport (Konvertierung)'"));
		EndTry;
		
	EndIf;
	
	EventHandlerExternalDataProcessorDestructor();
	
	WriteToExecutionProtocol(SubstituteParametersToString(
		NStr("ru = 'Окончание загрузки: %1'; en = 'Import finished at: %1'; pl = 'Koniec importu: %1';es_ES = 'Fin de la importación: %1';es_CO = 'Fin de la importación: %1';tr = 'Içe aktarımın sonu: %1';it = 'Importazione finita alle: %1';de = 'Import Ende: %1'"), CurrentSessionDate()), , False, , , True);
	WriteToExecutionProtocol(SubstituteParametersToString(
		NStr("ru = 'Загружено объектов: %1'; en = '%1 objects imported'; pl = 'Zaimportowane obiekty: %1';es_ES = 'Objetos importados: %1';es_CO = 'Objetos importados: %1';tr = 'İçe aktarılan nesneler: %1';it = '%1 oggetti importati';de = 'Importierte Objekte: %1'"), mImportedObjectCounter), , False, , , True);
	
	FinishKeepExchangeProtocol();
	
	If IsInteractiveMode Then
		MessageToUser(NStr("ru = 'Загрузка данных завершена.'; en = 'Data import completed.'; pl = 'Pobieranie danych zakończone.';es_ES = 'Importación de datos se ha finalizado.';es_CO = 'Importación de datos se ha finalizado.';tr = 'Veri içe aktarımı tamamlandı.';it = 'Importazione dati completata.';de = 'Der Datenimport ist abgeschlossen.'"));
	EndIf;
	
EndProcedure

// Imports data according to the set modes (exchange rules).
//
// Parameters:
//  No.
//
Procedure ExecuteImport() Export
	
	ExecutionPossible = ExecuteActionsBeforeReadData();
	
	If Not ExecutionPossible Then
		Return;
	EndIf;
	
	If UseTransactions Then
		BeginTransaction();
	EndIf;
	
	Try
		ReadData();
		// Deferred recording of what was not recorded in the beginning.
		ExecuteWriteNotWrittenObjects();
		If UseTransactions Then
			CommitTransaction();
		EndIf;
	Except
		If UseTransactions Then
			RollbackTransaction();
		EndIf;
	EndTry;
	
	ExecuteActionsAfterDataReadingCompleted();
	
EndProcedure

Procedure CompressResultingExchangeFile()
	
	Try
		
		SourceExchangeFileName = ExchangeFileName;
		If ArchiveFile Then
			ExchangeFileName = StrReplace(ExchangeFileName, ".xml", ".zip");
		EndIf;
		
		Archiver = New ZipFileWriter(ExchangeFileName, ExchangeFileCompressionPassword, NStr("ru = 'Файл обмена данными'; en = 'Data exchange file'; pl = 'Plik wymiany danych';es_ES = 'Archivo de intercambio de datos';es_CO = 'Archivo de intercambio de datos';tr = 'Veri alışveriş dosyası';it = 'File di scambio dati';de = 'Datenaustauschdatei'"));
		Archiver.Add(SourceExchangeFileName);
		Archiver.Write();
		
		DeleteFiles(SourceExchangeFileName);
		
	Except
		WriteLogEvent(NStr("ru = 'Универсальный обмен данными в формате XML'; en = 'Universal data exchange in XML format'; pl = 'Uniwersalna wymiana danymi w formacie XML';es_ES = 'Intercambio de datos universal en el formato XML';es_CO = 'Intercambio de datos universal en el formato XML';tr = 'XML formatında üniversal veri değişimi';it = 'Scambio di dati universale in formato XML';de = 'Universeller Datenaustausch im XML-Format'", DefaultLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

Function UnpackZipFile(FileNameForUnpacking)
	
	DirectoryToUnpack = GetTempFileName();
	CreateDirectory(DirectoryToUnpack);
	
	UnpackedFileName = "";
	
	Try
		
		Archiver = New ZipFileReader(FileNameForUnpacking, ExchangeFileUnpackPassword);
		
		If Archiver.Items.Count() > 0 Then
			
			Archiver.Extract(Archiver.Items[0], DirectoryToUnpack, ZIPRestoreFilePathsMode.DontRestore);
			UnpackedFileName = GetExchangeFileName(DirectoryToUnpack, Archiver.Items[0].Name);
			
		Else
			
			UnpackedFileName = "";
			
		EndIf;
		
		Archiver.Close();
	
	Except
		
		WP = GetProtocolRecordStructure(2, ErrorDescription());
		WriteToExecutionProtocol(2, WP, True);
		
		Return "";
							
	EndTry;
	
	Return UnpackedFileName;
		
EndFunction

Function SendExchangeStartedInformationToDestination(CurrentRowForWrite)
	
	If NOT DirectReadingInDestinationIB Then
		Return True;
	EndIf;
	
	CurrentRowForWrite = CurrentRowForWrite + Chars.LF + mXMLRules + Chars.LF + "</ExchangeFile>" + Chars.LF;
	
	ExecutionPossible = mDataImportDataProcessor.ExecuteActionsBeforeReadData(CurrentRowForWrite);
	
	Return ExecutionPossible;	
	
EndFunction

Function ExecuteInformationTransferOnCompleteDataTransfer()
	
	If NOT DirectReadingInDestinationIB Then
		Return True;
	EndIf;
	
	mDataImportDataProcessor.ExecuteActionsAfterDataReadingCompleted();
	
EndFunction

Procedure SendAdditionalParametersToDestination()
	
	For Each Parameter In ParameterSetupTable Do
		
		If Parameter.PassParameterOnExport = True Then
			
			SendOneParameterToDestination(Parameter.Name, Parameter.Value, Parameter.ConversionRule);
					
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure SendTypesInformationToDestination()
	
	If Not IsBlankString(mTypesForDestinationRow) Then
		WriteToFile(mTypesForDestinationRow);
	EndIf;
		
EndProcedure

// Exports data according to the set modes (exchange rules).
//
// Parameters:
//  No.
//
Procedure ExecuteExport() Export
	
	DataProcessingMode = mDataProcessingModes.DataExported;
	
	InitializeKeepExchangeProtocol();
	
	InitializeCommentsOnDataExportAndImport();
	
	ExportPossible = True;
	CurrentNestingLevelExportByRule = 0;
	
	mDataExportCallStack = New ValueTable;
	mDataExportCallStack.Columns.Add("Ref");
	mDataExportCallStack.Indexes.Add("Ref");
	
	If mExchangeRulesReadOnImport = True Then
		
		WriteToExecutionProtocol(74);
		ExportPossible = False;	
		
	EndIf;
	
	If IsBlankString(ExchangeRuleFileName) Then
		WriteToExecutionProtocol(12);
		ExportPossible = False;
	EndIf;
	
	If NOT DirectReadingInDestinationIB Then
		
		If IsBlankString(ExchangeFileName) Then
			WriteToExecutionProtocol(10);
			ExportPossible = False;
		EndIf;
		
	Else
		
		mDataImportDataProcessor = EstablishConnectionWithDestinationIB(); 
		
		ExportPossible = mDataImportDataProcessor <> Undefined;
		
	EndIf;
	
	// Initializing the external data processor with export handlers.
	InitEventHandlerExternalDataProcessor(ExportPossible, ThisObject);
	
	If Not ExportPossible Then
		mDataImportDataProcessor = Undefined;
		Return;
	EndIf;
	
	WriteToExecutionProtocol(SubstituteParametersToString(
		NStr("ru = 'Начало выгрузки: %1'; en = 'Export started at: %1'; pl = 'Importuj obiekt: %1';es_ES = 'Inicio de la exportación: %1';es_CO = 'Inicio de la exportación: %1';tr = 'Dışa aktarma başladı: %1';it = 'Esportazione avviata alle: %1';de = 'Export Start: %1'"), CurrentSessionDate()), , False, , , True);
		
	InitManagersAndMessages();
	
	mExportedObjectCounter = 0;
	mSnCounter 				= 0;
	ErrorFlag                  = False;

	// Importing exchange rules
	If Conversion.Count() = 9 Then
		
		ImportExchangeRules();
		If ErrorFlag Then
			FinishKeepExchangeProtocol();
			mDataImportDataProcessor = Undefined;
			Return;
		EndIf;
		
	Else
		
		For each Rule In ConversionRulesTable Do
			Rule.Exported.Clear();
			Rule.OnlyRefsExported.Clear();
		EndDo;
		
	EndIf;

	// Assigning parameters that are set in the dialog.
	SetParametersFromDialog();

	// Opening the exchange file
	CurrentRowForWrite = OpenExportFile() + Chars.LF;
	
	If ErrorFlag Then
		ExchangeFile = Undefined;
		FinishKeepExchangeProtocol();
		mDataImportDataProcessor = Undefined;
		Return; 
	EndIf;
	
	// Defining handler interfaces.
	If HandlersDebugModeFlag Then
		
		SupplementRulesWithHandlerInterfaces(Conversion, ConversionRulesTable, ExportRuleTable, CleanupRulesTable);
		
	EndIf;
	
	If UseTransactions Then
		BeginTransaction();
	EndIf;
	
	Cancel = False;
	
	Try
	
		// Writing the exchange rules to the file.
		ExchangeFile.WriteLine(mXMLRules);
		
		Cancel = Not SendExchangeStartedInformationToDestination(CurrentRowForWrite);
		
		If Not Cancel Then
			
			If SafeMode Then
				SetSafeMode(True);
				For Each SeparatorName In ApplicationSeparators Do
					SetDataSeparationSafeMode(SeparatorName, True);
				EndDo;
			EndIf;
			
			// BeforeDataExport handler
			Try
				
				If HandlersDebugModeFlag Then
					
					If Not IsBlankString(Conversion.BeforeExportData) Then
						
						Execute(GetHandlerCallString(Conversion, "BeforeExportData"));
						
					EndIf;
					
				Else
					
					Execute(Conversion.BeforeExportData);
					
				EndIf;
				
			Except
				WriteErrorInfoConversionHandlers(62, ErrorDescription(), NStr("ru = 'BeforeDataExport (конвертация)'; en = 'BeforeDataExport (conversion)'; pl = 'BeforeDataExport (konwertowanie)';es_ES = 'BeforeDataExport (conversión)';es_CO = 'BeforeDataExport (conversión)';tr = 'BeforeDataExport (dönüştürme)';it = 'BeforeDataExport (conversione)';de = 'BeforeDataExport (Konvertierung)'"));
				Cancel = True;
			EndTry;
			
			If Not Cancel Then
				
				If ExecuteDataExchangeInOptimizedFormat Then
					SendTypesInformationToDestination();
				EndIf;
				
				// Sending parameters to the destination.
				SendAdditionalParametersToDestination();
				
				EventTextAfterParameterImport = "";
				If Conversion.Property("AfterImportParameters", EventTextAfterParameterImport)
					AND Not IsBlankString(EventTextAfterParameterImport) Then
					
					WritingEvent = New XMLWriter;
					WritingEvent.SetString();
					deWriteElement(WritingEvent, "AfterParameterExportAlgorithm", EventTextAfterParameterImport);
					WriteToFile(WritingEvent);
					
				EndIf;
				
				NodeAndExportRuleMap = New Map();
				StructureForChangeRecordDeletion = New Map();
				
				ProcessExportRules(ExportRuleTable.Rows, NodeAndExportRuleMap);
				
				SuccessfullyExportedByExchangePlans = ProcessExportForExchangePlans(NodeAndExportRuleMap, StructureForChangeRecordDeletion);
				
				If SuccessfullyExportedByExchangePlans Then
				
					ProcessExchangeNodeRecordChangeEditing(StructureForChangeRecordDeletion);
				
				EndIf;
				
				// AfterDataExport handler
				Try
					
					If HandlersDebugModeFlag Then
						
						If Not IsBlankString(Conversion.AfterExportData) Then
							
							Execute(GetHandlerCallString(Conversion, "AfterExportData"));
							
						EndIf;
						
					Else
						
						Execute(Conversion.AfterExportData);
						
					EndIf;

				Except
					WriteErrorInfoConversionHandlers(63, ErrorDescription(), NStr("ru = 'AfterDataExport (конвертация)'; en = 'AfterDataExport (conversion)'; pl = 'AfterDataExport (konwertowanie)';es_ES = 'AfterDataExport (conversión)';es_CO = 'AfterDataExport (conversión)';tr = 'AfterDataExport (dönüştürme)';it = 'AfterDataExport (conversione)';de = 'AfterDataExport (Konvertierung)'"));
				EndTry;
				
				ExecuteWriteNotWrittenObjects();
				
				If TransactionActive() Then
					CommitTransaction();
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If Cancel Then
			
			If TransactionActive() Then
				RollbackTransaction();
			EndIf;
			
			ExecuteInformationTransferOnCompleteDataTransfer();
			
			FinishKeepExchangeProtocol();
			mDataImportDataProcessor = Undefined;
			ExchangeFile = Undefined;
			
			EventHandlerExternalDataProcessorDestructor();
			
		EndIf;
		
	Except
		
		If TransactionActive() Then
			RollbackTransaction();
		EndIf;
		
		Cancel = True;
		ErrorRow = ErrorDescription();
		
		WriteToExecutionProtocol(SubstituteParametersToString(
			NStr("ru = 'Ошибка при выгрузке данных: %1'; en = 'Error exporting data: %1'; pl = 'Wystąpił błąd podczas eksportowania danych: %1';es_ES = 'Un error ha ocurrido al exportar los datos: %1';es_CO = 'Un error ha ocurrido al exportar los datos: %1';tr = 'Veri dışa aktarılırken bir hata oluştu: %1';it = 'Errore durante l''upload dei dati: %1';de = 'Beim Exportieren von Daten ist ein Fehler aufgetreten: %1'"), ErrorRow), Undefined, True, , , True);
		
		ExecuteInformationTransferOnCompleteDataTransfer();
		
		FinishKeepExchangeProtocol();
		CloseFile();
		mDataImportDataProcessor = Undefined;
				
	EndTry;
	
	If Cancel Then
		Return;
	EndIf;
	
	// Closing the exchange file
	CloseFile();
	
	If ArchiveFile Then
		CompressResultingExchangeFile();
	EndIf;
	
	ExecuteInformationTransferOnCompleteDataTransfer();
	
	WriteToExecutionProtocol(SubstituteParametersToString(
		NStr("ru = 'Окончание выгрузки: %1'; en = 'Export finished at: %1'; pl = 'Koniec eksportu: %1';es_ES = 'Fin de la exportación: %1';es_CO = 'Fin de la exportación: %1';tr = 'Dışa aktarımın sonu: %1';it = 'Termine upload: %1';de = 'Export Ende: %1'"), CurrentSessionDate()), , False, , ,True);
	WriteToExecutionProtocol(SubstituteParametersToString(
		NStr("ru = 'Выгружено объектов: %1'; en = '%1 objects exported'; pl = 'Eksportowano obiektów: %1';es_ES = 'Objetos exportados: %1';es_CO = 'Objetos exportados: %1';tr = 'Dışa aktarılan nesneler: %1';it = '%1 oggetti esportati';de = 'Exportierte Objekte: %1'"), mExportedObjectCounter), , False, , , True);
	
	FinishKeepExchangeProtocol();
	
	mDataImportDataProcessor = Undefined;
	
	EventHandlerExternalDataProcessorDestructor();
	
	If IsInteractiveMode Then
		MessageToUser(NStr("ru = 'Выгрузка данных завершена.'; en = 'Data has been exported.'; pl = 'Dane są eksportowane.';es_ES = 'Datos se han exportado.';es_CO = 'Datos se han exportado.';tr = 'Veri dışa aktarıldı.';it = 'I dati sono stati esportati.';de = 'Daten werden exportiert.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region SetAttributesValuesAndDataProcessorModalVariables

// The procedure of setting the ErrorFlag global variable value.
//
// Parameters:
//  Value - Boolean. It is the new value of the ErrorFlag variable.
//  
Procedure SetErrorFlag(Value)
	
	ErrorFlag = Value;
	
	If ErrorFlag Then
		
		EventHandlerExternalDataProcessorDestructor(DebugModeFlag);
		
	EndIf;
	
EndProcedure

// Returns the current value of data processor version.
//
// Parameters:
//  No.
// 
// Returns:
//  Current value of the data processor version.
//
Function ObjectVersionAsString() Export
	
	Return "2.1.8";
	
EndFunction

#EndRegion

#Region InitializingExchangeRulesTables

Procedure AddMissingColumns(Columns, Name, Types = Undefined)
	
	If Columns.Find(Name) <> Undefined Then
		Return;
	EndIf;
	
	Columns.Add(Name, Types);	
	
EndProcedure

// Initializes table columns of object conversion rules.
//
// Parameters:
//  No.
// 
Procedure InitConversionRuleTable()

	Columns = ConversionRulesTable.Columns;
	
	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Order");

	AddMissingColumns(Columns, "SynchronizeByID");
	AddMissingColumns(Columns, "DoNotCreateIfNotFound", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "DoNotExportPropertyObjectsByRefs", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "SearchBySearchFieldsIfNotFoundByID", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "OnMoveObjectByRefSetGIUDOnly", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "UseQuickSearchOnImport", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "GenerateNewNumberOrCodeIfNotSet", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "TinyObjectCount", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "RefExportReferenceCount", deTypeDetails("Number"));
	AddMissingColumns(Columns, "IBItemsCount", deTypeDetails("Number"));
	
	AddMissingColumns(Columns, "ExportMethod");

	AddMissingColumns(Columns, "Source");
	AddMissingColumns(Columns, "Destination");
	
	AddMissingColumns(Columns, "SourceType",  deTypeDetails("String"));

	AddMissingColumns(Columns, "BeforeExport");
	AddMissingColumns(Columns, "OnExport");
	AddMissingColumns(Columns, "AfterExport");
	AddMissingColumns(Columns, "AfterExportToFile");
	
	AddMissingColumns(Columns, "HasBeforeExportHandler",	    deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "HasOnExportHandler",		deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "HasAfterExportHandler",		deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "HasAfterExportToFileHandler",	deTypeDetails("Boolean"));

	AddMissingColumns(Columns, "BeforeImport");
	AddMissingColumns(Columns, "OnImport");
	AddMissingColumns(Columns, "AfterImport");
	
	AddMissingColumns(Columns, "SearchFieldSequence");
	AddMissingColumns(Columns, "SearchInTabularSections");
	
	AddMissingColumns(Columns, "HasBeforeImportHandler", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "HasOnImportHandler",    deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "HasAfterImportHandler",  deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "HasSearchFieldSequenceHandler",  deTypeDetails("Boolean"));

	AddMissingColumns(Columns, "SearchProperties",	deTypeDetails("ValueTable"));
	AddMissingColumns(Columns, "Properties",		deTypeDetails("ValueTable"));
	
	AddMissingColumns(Columns, "Values",		deTypeDetails("Map"));

	AddMissingColumns(Columns, "Exported",							deTypeDetails("Map"));
	AddMissingColumns(Columns, "OnlyRefsExported",				deTypeDetails("Map"));
	AddMissingColumns(Columns, "ExportSourcePresentation",		deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "DoNotReplace",					deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "RememberExported",       deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "AllObjectsExported",         deTypeDetails("Boolean"));
	
EndProcedure

// Initializes table columns of data export rules.
//
// Parameters:
//  No
// 
Procedure InitExportRuleTable()

	Columns = ExportRuleTable.Columns;

	AddMissingColumns(Columns, "Enable",		deTypeDetails("Number"));
	AddMissingColumns(Columns, "IsFolder",		deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Order");

	AddMissingColumns(Columns, "DataFilterMethod");
	AddMissingColumns(Columns, "SelectionObject");
	
	AddMissingColumns(Columns, "ConversionRule");

	AddMissingColumns(Columns, "BeforeProcess");
	AddMissingColumns(Columns, "AfterProcess");

	AddMissingColumns(Columns, "BeforeExport");
	AddMissingColumns(Columns, "AfterExport");
	
	// Columns for filtering using the query builder.
	AddMissingColumns(Columns, "UseFilter", deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "BuilderSettings");
	AddMissingColumns(Columns, "ObjectForQueryName");
	AddMissingColumns(Columns, "ObjectNameForRegisterQuery");
	
	AddMissingColumns(Columns, "SelectExportDataInSingleQuery", deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "ExchangeNodeRef");

EndProcedure

// Initializes table columns of data clearing rules.
//
// Parameters:
//  No.
// 
Procedure CleaningRuleTableInitialization()

	Columns = CleanupRulesTable.Columns;

	AddMissingColumns(Columns, "Enable",		deTypeDetails("Boolean"));
	AddMissingColumns(Columns, "IsFolder",		deTypeDetails("Boolean"));
	
	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Order",	deTypeDetails("Number"));

	AddMissingColumns(Columns, "DataFilterMethod");
	AddMissingColumns(Columns, "SelectionObject");
	
	AddMissingColumns(Columns, "DeleteForPeriod");
	AddMissingColumns(Columns, "Directly",	deTypeDetails("Boolean"));

	AddMissingColumns(Columns, "BeforeProcess");
	AddMissingColumns(Columns, "AfterProcess");
	AddMissingColumns(Columns, "BeforeDelete");
	
EndProcedure

// Initializes table columns of parameter setup table.
//
// Parameters:
//  No.
// 
Procedure InitializationParameterSetupTable()

	Columns = ParameterSetupTable.Columns;

	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Value");
	AddMissingColumns(Columns, "PassParameterOnExport");
	AddMissingColumns(Columns, "ConversionRule");

EndProcedure

#EndRegion

#Region InitAttributesAndModuleVariables

Procedure InitializeCommentsOnDataExportAndImport()
	
	CommentOnDataExport = "";
	CommentOnDataImport = "";
	
EndProcedure

// Initializes the deMessages variable that contains mapping of message codes and their description.
//
// Parameters:
//  No.
// 
Procedure InitMessages()

	deMessages = New Map;
	
	deMessages.Insert(2,  NStr("ru = 'Ошибка распаковки файла обмена. Файл заблокирован'; en = 'An error occurred when unpacking an exchange file. The file is locked'; pl = 'Wystąpił błąd podczas rozpakowywania pliku wymiany. Plik jest zablokowany';es_ES = 'Ha ocurrido un error al desembalar un archivo de intercambio. El archivo está bloqueado';es_CO = 'Ha ocurrido un error al desembalar un archivo de intercambio. El archivo está bloqueado';tr = 'Bir değişim dosyasını paketinden çıkarılırken bir hata oluştu. Dosya kilitli.';it = 'Errore durante la decompressione del file di scambio. Il file è bloccato';de = 'Beim Entpacken einer Austausch-Datei ist ein Fehler aufgetreten. Die Datei ist gesperrt'"));
	deMessages.Insert(3,  NStr("ru = 'Указанный файл правил обмена не существует'; en = 'The specified exchange rule file does not exist'; pl = 'Określony plik reguł wymiany nie istnieje.';es_ES = 'El archivo de las reglas de intercambio especificado no existe';es_CO = 'El archivo de las reglas de intercambio especificado no existe';tr = 'Belirtilen değişim kuralları dosyası mevcut değil.';it = 'Il file di regole di scambio specificato non esiste.';de = 'Die angegebene Austausch-Regeldatei existiert nicht'"));
	deMessages.Insert(4,  NStr("ru = 'Ошибка при создании COM-объекта Msxml2.DOMDocument'; en = 'Error creating Msxml2.DOMDocument COM object.'; pl = 'Podczas tworzenia COM obiektu Msxml2.DOMDocument wystąpił błąd';es_ES = 'Ha ocurrido un error al crear el objeto COM Msxml2.DOMDocumento';es_CO = 'Ha ocurrido un error al crear el objeto COM Msxml2.DOMDocumento';tr = 'Msxml2.DOMDocument COM nesnesi oluştururken bir hata oluştu';it = 'Errore durante la creazione dell''oggetto COM Msxml2.DOMDocument.';de = 'Beim Erstellen des COM-Objekts Msxml2.DOMDocument ist ein Fehler aufgetreten'"));
	deMessages.Insert(5,  NStr("ru = 'Ошибка открытия файла обмена'; en = 'Error opening exchange file'; pl = 'Podczas otwarcia pliku wymiany wystąpił błąd';es_ES = 'Ha ocurrido un error al abrir el archivo de intercambio';es_CO = 'Ha ocurrido un error al abrir el archivo de intercambio';tr = 'Değişim dosyası açılırken bir hata oluştu';it = 'Error opening exchange file';de = 'Beim Öffnen der Austausch-Datei ist ein Fehler aufgetreten'"));
	deMessages.Insert(6,  NStr("ru = 'Ошибка при загрузке правил обмена'; en = 'Error importing exchange rules'; pl = 'Podczas importu reguł wymiany wystąpił błąd';es_ES = 'Ha ocurrido un error al importar las reglas de intercambio';es_CO = 'Ha ocurrido un error al importar las reglas de intercambio';tr = 'Değişim kuralları içe aktarılırken bir hata oluştu';it = 'Errore durante il download delle regole di scambio';de = 'Beim Importieren von Austausch-Regeln ist ein Fehler aufgetreten'"));
	deMessages.Insert(7,  NStr("ru = 'Ошибка формата правил обмена'; en = 'Exchange rule format error'; pl = 'Błąd formatu reguł wymiany';es_ES = 'Error en el formato de la regla de intercambio';es_CO = 'Error en el formato de la regla de intercambio';tr = 'Değişim kuralı biçiminde hata';it = 'Errore nel formato delle regole di scambio';de = 'Fehler beim Format der Austauschregeln'"));
	deMessages.Insert(8,  NStr("ru = 'Некорректно указано имя файла для выгрузки данных'; en = 'File name for data export is specified incorrectly'; pl = 'Niepoprawnie jest wskazana nazwa pliku do pobierania danych';es_ES = 'Nombre del archivo está indicado incorrectamente para subir los datos';es_CO = 'Nombre del archivo está indicado incorrectamente para subir los datos';tr = 'Veri dışa aktarma için belirtilen dosya adı yanlıştır';it = 'Il nome file per l''esportazione dati è specificato in modo non corretto';de = 'Falscher Dateiname für das Hochladen von Daten'"));
	deMessages.Insert(9,  NStr("ru = 'Ошибка формата файла обмена'; en = 'Exchange file format error'; pl = 'Błąd formatu pliku wymiany';es_ES = 'Error en el formato del archivo de intercambio';es_CO = 'Error en el formato del archivo de intercambio';tr = 'Değişim dosyası biçiminde hata';it = 'Errore formato file di scambio';de = 'Fehler beim Austausch des Dateiformats'"));
	deMessages.Insert(10, NStr("ru = 'Не указано имя файла для выгрузки данных (Имя файла данных)'; en = 'Data export file name is not specified.'; pl = 'Nie określono nazwy pliku do eksportu danych (Nazwa pliku danych)';es_ES = 'Nombre del archivo para la exportación de datos no está especificado (Nombre del archivo de datos)';es_CO = 'Nombre del archivo para la exportación de datos no está especificado (Nombre del archivo de datos)';tr = 'Veri dışa aktarma için dosya adı belirtilmemiş (Veri dosyasının adı)';it = 'Il nome del file di esportazione dati non è specificato.';de = 'Dateiname für Datenexport ist nicht angegeben (Dateiname)'"));
	deMessages.Insert(11, NStr("ru = 'Ссылка на несуществующий объект метаданных в правилах обмена'; en = 'Exchange rules contain a reference to a nonexistent metadata object'; pl = 'Odwołanie do nieistniejącego obiektu metadanych w regułach wymiany';es_ES = 'Enlace al objeto de metadatos inexistente en las reglas de intercambio';es_CO = 'Enlace al objeto de metadatos inexistente en las reglas de intercambio';tr = 'Değişim kurallarında varolan bir meta veri nesnesine bağlanma';it = 'Il link ad un oggetto di metadati inesistente nelle regole di scambio';de = 'Verknüpfen Sie ein nicht vorhandenes Metadatenobjekt in den Austauschregeln'"));
	deMessages.Insert(12, NStr("ru = 'Не указано имя файла с правилами обмена (Имя файла правил)'; en = 'Exchange rule file name is not specified.'; pl = 'Nie określono nazwy pliku z regułami wymiany.';es_ES = 'Nombre del archivo con las reglas de intercambio no está especificado (Nombre del archivo de la regla)';es_CO = 'Nombre del archivo con las reglas de intercambio no está especificado (Nombre del archivo de la regla)';tr = 'Değişim kuralları ile dosya adı belirtilmemiş (Kural dosyasının adı)';it = 'Non è specificato il nome del file con regole di scambio (Nome file delle regole).';de = 'Dateiname mit Austauschregeln ist nicht angegeben (Regeldateiname)'"));
	
	deMessages.Insert(13, NStr("ru = 'Ошибка получения значения свойства объекта (по имени свойства источника)'; en = 'Error retrieving object property value (by source property name).'; pl = 'Podczas odzyskiwania wartości właściwości obiektu (według nazwy właściwości źródła) wystąpił błąd';es_ES = 'Ha ocurrido un error al recibir un valor de la propiedad del objeto (por el nombre de la propiedad de la fuente)';es_CO = 'Ha ocurrido un error al recibir un valor de la propiedad del objeto (por el nombre de la propiedad de la fuente)';tr = 'Nesne özelliğinin bir değeri alınırken bir hata oluştu (kaynak özelliği adıyla)';it = 'Errore nell''acquisizione del valore di proprietà dell''oggetto (per nome della proprietà di fonte).';de = 'Beim Empfangen eines Werts der Objekteigenschaft (anhand des Namens der Quelleigenschaft) ist ein Fehler aufgetreten'"));
	deMessages.Insert(14, NStr("ru = 'Ошибка получения значения свойства объекта (по имени свойства приемника)'; en = 'Error retrieving object property value (by destination property name).'; pl = 'Podczas odzyskiwania wartości właściwości obiektu (według nazwy właściwości celu) wystąpił błąd';es_ES = 'Ha ocurrido un error al recibir el valor de la propiedad del objeto (por el nombre de la propiedad de objetivo)';es_CO = 'Ha ocurrido un error al recibir el valor de la propiedad del objeto (por el nombre de la propiedad de objetivo)';tr = 'Nesne özelliği değerini alınırken bir hata oluştu (hedef özellik adına göre)';it = 'Errore nell''acquisizione del valore di proprietà dell''oggetto (per nome della proprietà di ricevente).';de = 'Fehler beim Abrufen des Objekt-Eigenschaftswerts (nach Ziel-Eigenschaftsname).'"));
	
	deMessages.Insert(15, NStr("ru = 'Не указано имя файла для загрузки данных (Имя файла для загрузки)'; en = 'Import file name is not specified.'; pl = 'Nie określono nazwy pliku do importu danych.';es_ES = 'Nombre del archivo para importación de datos no está especificado (Nombre del archivo para importar)';es_CO = 'Nombre del archivo para importación de datos no está especificado (Nombre del archivo para importar)';tr = 'Veri dışa aktarma için dosya adı belirtilmemiş (İçe aktarılacak dosyasının adı)';it = 'Il nome file di importazione non è specificato.';de = 'Dateiname für den Datenimport ist nicht angegeben (Dateiname für den Import)'"));
	
	deMessages.Insert(16, NStr("ru = 'Ошибка получения значения свойства подчиненного объекта (по имени свойства источника)'; en = 'Error retrieving subordinate object property value (by source property name).'; pl = 'Podczas otrzymywania wartości właściwości obiektu podporządkowanego (według nazwy właściwości źródła) wystąpił błąd.';es_ES = 'Ha ocurrido un error al recibir el valor de la propiedad del subobjeto (por el nombre de la propiedad de la fuente)';es_CO = 'Ha ocurrido un error al recibir el valor de la propiedad del subobjeto (por el nombre de la propiedad de la fuente)';tr = 'Alt nesne özelliğinin değeri alınırken bir hata oluştu (kaynak özellik adına göre)';it = 'Errore nell''acquisizione del valore di proprietà dell''oggetto subordinato (per nome della proprietà di fonte).';de = 'Beim Empfangen des Werts der Unterobjekteigenschaft (nach Name der Quelleigenschaft) ist ein Fehler aufgetreten'"));
	deMessages.Insert(17, NStr("ru = 'Ошибка получения значения свойства подчиненного объекта (по имени свойства приемника)'; en = 'Error retrieving subordinate object property value (by destination property name).'; pl = 'Podczas otrzymywania wartości właściwości obiektu podporządkowanego (według nazwy właściwości celu) wystąpił błąd.';es_ES = 'Ha ocurrido un error al recibir el valor de la propiedad del subobjeto (por el nombre de la propiedad de objetivo)';es_CO = 'Ha ocurrido un error al recibir el valor de la propiedad del subobjeto (por el nombre de la propiedad de objetivo)';tr = 'Alt nesne özelliğinin değeri alınırken bir hata oluştu (kaynak özellik adına göre)';it = 'Errore nell''acquisizione del valore di proprietà dell''oggetto subordinato (per nome della proprietà di ricevente).';de = 'Fehler beim Abrufen des Wertes der untergeordneten Objekteigenschaften (nach Name der Zieleigenschaft).'"));
	
	deMessages.Insert(19, NStr("ru = 'Ошибка в обработчике события BeforeImportObject'; en = 'BeforeImportObject event handler error'; pl = 'Błąd przetwarzania wydarzenia BeforeImportObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeObjectImport';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeObjectImport';tr = 'BeforeImportObject olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento BeforeImportObject';de = 'Ein Fehler ist aufgetreten in Ereignis-Handler BeforeImportObject'"));
	deMessages.Insert(20, NStr("ru = 'Ошибка в обработчике события OnImportObject'; en = 'OnImportObject event handler error'; pl = 'Błąd przetwarzania wydarzenia OnImportObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos OnObjectImport';es_CO = 'Ha ocurrido un error en el manipulador de eventos OnObjectImport';tr = 'OnImportObject veri işleyicisinde bir hata oluştu';it = 'Errore gestore evento OnImportObject';de = 'Ein Fehler ist aufgetreten in Ereignis-Handler OnImportObject'"));
	deMessages.Insert(21, NStr("ru = 'Ошибка в обработчике события AfterImportObject'; en = 'AfterImportObject event handler error'; pl = 'Błąd przetwarzania wydarzenia AfterImportObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterObjectImport';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterObjectImport';tr = 'AfterImportObject olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento AfterImportObject';de = 'Ein Fehler ist aufgetreten in Ereignis-Handler AfterImportObject'"));
	deMessages.Insert(22, NStr("ru = 'Ошибка в обработчике события BeforeDataImport (конвертация)'; en = 'BeforeDataImport event handler error (data conversion).'; pl = 'Błąd przetwarzania wydarzenia BeforeDataImport (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeDataImport (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeDataImport (conversión)';tr = 'BeforeDataImport olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento BeforeDataImport (conversione dati).';de = 'Ein Fehler ist aufgetreten in Ereignis-Handler BeforeDataImport (Umwandlung)'"));
	deMessages.Insert(23, NStr("ru = 'Ошибка в обработчике события AfterDataImport (конвертация)'; en = 'AfterDataImport event handler error (data conversion).'; pl = 'Błąd przetwarzania wydarzenia AfterDataImport (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterDataImport (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterDataImport (conversión)';tr = 'AfterDataImport olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento AfterDataImport (conversione dati).';de = 'Ein Fehler ist aufgetreten in Ereignis-Handler AfterDataImport (Umwandlung)'"));
	deMessages.Insert(24, NStr("ru = 'Ошибка при удалении объекта'; en = 'Error deleting object'; pl = 'Podczas usuwania obiektu wystąpił błąd';es_ES = 'Ha ocurrido un error al eliminar un objeto';es_CO = 'Ha ocurrido un error al eliminar un objeto';tr = 'Nesne silinirken bir hata oluştu';it = 'Errore durante l''eliminazione dell''oggetto';de = 'Beim Entfernen eines Objekts ist ein Fehler aufgetreten'"));
	deMessages.Insert(25, NStr("ru = 'Ошибка при записи документа'; en = 'Error writing document'; pl = 'Podczas zapisu dokumentu wystąpił błąd';es_ES = 'Ha ocurrido un error al grabar el documento';es_CO = 'Ha ocurrido un error al grabar el documento';tr = 'Belge yazılırken bir hata oluştu';it = 'Errore durante la registrazione del documento';de = 'Beim Schreiben des Dokuments ist ein Fehler aufgetreten'"));
	deMessages.Insert(26, NStr("ru = 'Ошибка записи объекта'; en = 'Error writing object'; pl = 'Podczas zapisu obiektu wystąpił błąd';es_ES = 'Ha ocurrido un error al grabar el objeto';es_CO = 'Ha ocurrido un error al grabar el objeto';tr = 'Nesne yazılırken bir hata oluştu';it = 'Errore durante la scrittura dell''''oggetto';de = 'Beim Schreiben des Objekts ist ein Fehler aufgetreten'"));
	deMessages.Insert(27, NStr("ru = 'Ошибка в обработчике события BeforeProcessClearingRule'; en = 'BeforeProcessClearingRule event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeProcessClearingRule';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeProcessClearingRule';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeProcessClearingRule';tr = 'BeforeProcessClearingRule olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento BeforeProcessClearingRule';de = 'Im Ereignis-Handler BeforeProcessClearingRule ist ein Fehler aufgetreten'"));
	deMessages.Insert(28, NStr("ru = 'Ошибка в обработчике события AfterProcessClearingRule'; en = 'AfterProcessClearingRule event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterProcessClearingRule';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterClearingRuleProcessing';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterClearingRuleProcessing';tr = 'AfterProcessClearingRule olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento AfterProcessClearingRule';de = 'Ein Fehler ist im Ereignis-Handler AfterProcessClearingRule aufgetreten.'"));
	deMessages.Insert(29, NStr("ru = 'Ошибка в обработчике события BeforeDeleteObject'; en = 'BeforeDeleteObject event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeDeleteObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeDeleteObject';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeDeleteObject';tr = 'BeforeDeleteObject olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento BeforeDeleteObject';de = 'Im Ereignis-Handler BeforeDeleteObject ist ein Fehler aufgetreten'"));
	
	deMessages.Insert(31, NStr("ru = 'Ошибка в обработчике события BeforeProcessExportRule'; en = 'BeforeProcessExportRule event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeProcessExportRule';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeProcessExportRule';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeProcessExportRule';tr = 'BeforeProcessExportRule olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento BeforeProcessExportRule';de = 'Im Ereignis-Handler BeforeProcessExportRule ist ein Fehler aufgetreten'"));
	deMessages.Insert(32, NStr("ru = 'Ошибка в обработчике события AfterProcessExportRule'; en = 'AfterProcessExportRule event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterProcessExportRule';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterDumpRuleProcessing';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterDumpRuleProcessing';tr = 'AfterProcessExportRule olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento AfterProcessExportRule';de = 'Im Ereignis-Handler AfterProcessExportRule ist ein Fehler aufgetreten'"));
	deMessages.Insert(33, NStr("ru = 'Ошибка в обработчике события BeforeExportObject'; en = 'BeforeExportObject event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeExportObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeObjectExport';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeObjectExport';tr = 'BeforeExportObject olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento BeforeExportObject';de = 'Im Ereignis-Handler BeforeExportObject ist ein Fehler aufgetreten'"));
	deMessages.Insert(34, NStr("ru = 'Ошибка в обработчике события AfterExportObject'; en = 'AfterExportObject event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterExportObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterObjectExport';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterObjectExport';tr = 'AfterExportObject olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento AfterExportObject';de = 'Im Ereignis-Handler AfterExportObject ist ein Fehler aufgetreten'"));
	
	deMessages.Insert(39, NStr("ru = 'Ошибка при выполнении алгоритма, содержащегося в файле обмена'; en = 'Error executing algorithm from exchange file.'; pl = 'Błąd podczas wykonywania algorytmu z pliku wymiany';es_ES = 'Ha ocurrido un error al ejecutar el algoritmo desde el archivo de intercambio';es_CO = 'Ha ocurrido un error al ejecutar el algoritmo desde el archivo de intercambio';tr = 'Algoritma alışveriş dosyasından yürütülürken bir hata oluştu';it = 'Errore durante l''esecuzione dell''algoritmo contenuto nel file di scambio.';de = 'Beim Ausführen des Algorithmus aus der Austausch-Datei ist ein Fehler aufgetreten'"));
	
	deMessages.Insert(41, NStr("ru = 'Ошибка в обработчике события BeforeExportObject'; en = 'BeforeExportObject event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeExportObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeObjectExport';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeObjectExport';tr = 'BeforeExportObject olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento BeforeExportObject';de = 'Im Ereignis-Handler BeforeExportObject ist ein Fehler aufgetreten'"));
	deMessages.Insert(42, NStr("ru = 'Ошибка в обработчике события OnExportObject'; en = 'OnExportObject event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia OnExportObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos OnObjectExport';es_CO = 'Ha ocurrido un error en el manipulador de eventos OnObjectExport';tr = 'OnExportObject olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento OnExportObject';de = 'Im Ereignis-Handler OnExportObject ist ein Fehler aufgetreten'"));
	deMessages.Insert(43, NStr("ru = 'Ошибка в обработчике события AfterExportObject'; en = 'AfterExportObject event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterExportObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterObjectExport';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterObjectExport';tr = 'AfterExportObject olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento AfterExportObject';de = 'Im Ereignis-Handler AfterExportObject ist ein Fehler aufgetreten'"));
	
	deMessages.Insert(45, NStr("ru = 'Не найдено правило конвертации объектов'; en = 'No conversion rule is found'; pl = 'Nie znaleziono reguły konwertowania obiektów';es_ES = 'Regla de conversión de objetos no encontrada';es_CO = 'Regla de conversión de objetos no encontrada';tr = 'Nesne dönüştürme kuralı bulunamadı';it = 'Nessuna regola di conversione dell''oggetto trovata';de = 'Die Objektkonvertierungsregel wurde nicht gefunden'"));
	
	deMessages.Insert(48, NStr("ru = 'Ошибка в обработчике события BeforeProcessExport группы свойств'; en = 'BeforeProcessExport property group event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeProcessExport grupy właściwości';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeExportProcessor del grupo de propiedades';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeExportProcessor del grupo de propiedades';tr = 'Özellik grubunun BeforeProcessExport olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento gruppo proprietà BeforeProcessExport';de = 'Im Ereignis-Handler BeforeProcessExport der Eigenschaftsgruppe ist ein Fehler aufgetreten'"));
	deMessages.Insert(49, NStr("ru = 'Ошибка в обработчике события AfterProcessExport группы свойств'; en = 'AfterProcessExport property group event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterProcessExport grupy właściwości';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterExportProcessor del grupo de propiedades';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterExportProcessor del grupo de propiedades';tr = 'Özellik grubunun AfterProcessExport olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento gruppo proprietà AfterProcessExport';de = 'Im Ereignis-Handler AfterProcessExport der Eigenschaftsgruppe ist ein Fehler aufgetreten'"));
	deMessages.Insert(50, NStr("ru = 'Ошибка в обработчике события BeforeExport (объекта коллекции)'; en = 'BeforeExport event handler error (collection object).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeExport (obiektu kolekcji)';es_ES = 'Error en el manipulador de eventos BeforeExport (del objeto de colección)';es_CO = 'Error en el manipulador de eventos BeforeExport (del objeto de colección)';tr = 'BeforeExport olay işleyicisindeki hata (koleksiyon nesnesinin)';it = 'Errore gestore evento BeforeExport (oggetto raccolta).';de = 'Fehler im Ereignis-Handler BeforeExport (Der Sammlungsobjekt)'"));
	deMessages.Insert(51, NStr("ru = 'Ошибка в обработчике события OnExport (объекта коллекции)'; en = 'OnExport event handler error (collection object).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia OnExport (obiektu kolekcji)';es_ES = 'Error en el manipulador de eventos OnExport (del objeto de colección)';es_CO = 'Error en el manipulador de eventos OnExport (del objeto de colección)';tr = 'OnExport olay işleyicisindeki hata (koleksiyon nesnesinin)';it = 'Errore gestore evento OnExport (oggetto raccolta).';de = 'Fehler im Ereignis-Handler BeimExport (Der Sammlungsobjekt)'"));
	deMessages.Insert(52, NStr("ru = 'Ошибка в обработчике события AfterExport (объекта коллекции)'; en = 'AfterExport event handler error (collection object).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterExport (obiektu kolekcji)';es_ES = 'Error en el manipulador de eventos AfterExport (del objeto de colección)';es_CO = 'Error en el manipulador de eventos AfterExport (del objeto de colección)';tr = 'AfterExport olay işleyicisindeki hata (koleksiyon nesnesinin)';it = 'Errore gestore evento AfterExport (oggetto raccolta).';de = 'Fehler im Ereignis-Handler NachDemExport (Der Sammlungsobjekt)'"));
	deMessages.Insert(53, NStr("ru = 'Ошибка в глобальном обработчике события BeforeImportObject (конвертация)'; en = 'BeforeImportObject global event handler error (data conversion).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeImportObject (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos global BeforeObjectImporting (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos global BeforeObjectImporting (conversión)';tr = 'BeforeImportObject global olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento globale BeforeImportObject (conversione dati).';de = 'Im globalen Ereignis-Handler ist ein Fehler aufgetreten VorDemImportierenVonObjekten (Konvertierung)'"));
	deMessages.Insert(54, NStr("ru = 'Ошибка в глобальном обработчике события AfterImportObject (конвертация)'; en = 'AfterImportObject global event handler error (data conversion).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterImportObject (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos global AfterObjectImport (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos global AfterObjectImport (conversión)';tr = 'AfterImportObject global olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento globale AfterImportObject (conversione dati).';de = 'Im globalen Ereignis-Handler ist ein Fehler aufgetreten NachDemImportierenVonObjekten (Konvertierung)'"));
	deMessages.Insert(55, NStr("ru = 'Ошибка в обработчике события BeforeExport (свойства)'; en = 'BeforeExport event handler error (property).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeExport (właściwości)';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeExport (propiedades)';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeExport (propiedades)';tr = 'BeforeExport olay işleyicisinde bir hata oluştu (özellikler)';it = 'Errore gestore evento BeforeExport (proprietà).';de = 'Im Ereignis-Handler ist ein Fehler aufgetreten VorExport (Eigenschaften)'"));
	deMessages.Insert(56, NStr("ru = 'Ошибка в обработчике события OnExport (свойства)'; en = 'OnExport event handler error (property).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia OnExport (właściwości)';es_ES = 'Ha ocurrido un error en el manipulador de eventos OnExport (propiedades)';es_CO = 'Ha ocurrido un error en el manipulador de eventos OnExport (propiedades)';tr = 'OnExport olay işleyicisinde bir hata oluştu (özellikler)';it = 'Errore gestore evento OnExport (proprietà).';de = 'Im Ereignis-Handler ist ein Fehler aufgetreten BeimExport (Eigenschaften)'"));
	deMessages.Insert(57, NStr("ru = 'Ошибка в обработчике события AfterExport (свойства)'; en = 'AfterExport event handler error (property).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterExport (właściwości)';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterExport (propiedades)';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterExport (propiedades)';tr = 'AfterExport olay işleyicisinde bir hata oluştu (özellikler)';it = 'Errore gestore evento AfterExport (proprietà).';de = 'Im Ereignis-Handler ist ein Fehler aufgetreten NachExport (Eigenschaften)'"));
	
	deMessages.Insert(62, NStr("ru = 'Ошибка в обработчике события BeforeDataExport (конвертация)'; en = 'BeforeDataExport event handler error (data conversion).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeDataExport (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeDataExport (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeDataExport (conversión)';tr = 'BeforeDataExport olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento BeforeDataExport (conversione dati).';de = 'Im Ereignis-Handler ist ein Fehler aufgetreten VorDatenExport (Konvertierung)'"));
	deMessages.Insert(63, NStr("ru = 'Ошибка в обработчике события AfterDataExport (конвертация)'; en = 'AfterDataExport event handler error (data conversion).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterDataExport (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterDataExport (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterDataExport (conversión)';tr = 'AfterDataExport olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento AfterDataExport (conversione dati).';de = 'Im Ereignis-Handler ist ein Fehler aufgetreten NachDatenExport (Konvertierung)'"));
	deMessages.Insert(64, NStr("ru = 'Ошибка в глобальном обработчике события BeforeObjectConversion (конвертация)'; en = 'BeforeObjectConversion global event handler error (data conversion).'; pl = 'Wystąpił błąd podczas globalnego przetwarzania wydarzenia BeforeObjectConversion (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos global BeforeObjectConversion (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos global BeforeObjectConversion (conversión)';tr = 'BeforeObjectConversion global olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento globale BeforeObjectConversion (conversione dati).';de = 'Im globalen Ereignis-Handler ist ein Fehler aufgetreten VorDerObjektkonvertierung (Konvertierung)'"));
	deMessages.Insert(65, NStr("ru = 'Ошибка в глобальном обработчике события BeforeExportObject (конвертация)'; en = 'BeforeExportObject global event handler error (data conversion).'; pl = 'Wystąpił błąd podczas globalnego przetwarzania wydarzenia BeforeExportObject (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos global BeforeObjectExport (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos global BeforeObjectExport (conversión)';tr = 'BeforeExportObject global olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento globale BeforeExportObject (conversione dati).';de = 'Im globalen Ereignis-Handler ist ein Fehler aufgetreten VorObjektExport (Konvertierung)'"));
	deMessages.Insert(66, NStr("ru = 'Ошибка получения коллекции подчиненных объектов из входящих данных'; en = 'Error retrieving subordinate object collection from incoming data'; pl = 'Podczas otrzymywania kolekcji obiektów podporządkowanych z danych wchodzących wystąpił błąd';es_ES = 'Ha ocurrido un error al recibir una colección de objetos subordinados desde los datos entrantes';es_CO = 'Ha ocurrido un error al recibir una colección de objetos subordinados desde los datos entrantes';tr = 'Gelen verilerden bir alt nesne koleksiyonu alınırken bir hata oluştu';it = 'Errore di acquisizione della raccolta di oggetti subordinati dai dati in arrivo';de = 'Beim Empfang einer untergeordneten Objektsammlung aus den eingehenden Daten ist ein Fehler aufgetreten'"));
	deMessages.Insert(67, NStr("ru = 'Ошибка получения свойства подчиненного объекта из входящих данных'; en = 'Error retrieving subordinate object properties from incoming data'; pl = 'Podczas odzyskiwania właściwości obiektu podporządkowanego z danych wchodzących wystąpił błąd';es_ES = 'Ha ocurrido un error al recibir las propiedades del objeto subordinado desde los datos entrantes';es_CO = 'Ha ocurrido un error al recibir las propiedades del objeto subordinado desde los datos entrantes';tr = 'Alt nesne özelliklerini gelen verilerden alırken bir hata oluştu';it = 'Errore di acquisizione della proprietà dell''oggetto subordinato dai dati in arrivo';de = 'Beim Empfang der untergeordneten Objekteigenschaften aus den eingehenden Daten ist ein Fehler aufgetreten'"));
	deMessages.Insert(68, NStr("ru = 'Ошибка получения свойства объекта из входящих данных'; en = 'Error retrieving object properties from incoming data'; pl = 'Podczas odzyskiwania właściwości obiektu z danych wchodzących wystąpił błąd';es_ES = 'Ha ocurrido un error al recibir las propiedades del objeto desde los datos entrantes';es_CO = 'Ha ocurrido un error al recibir las propiedades del objeto desde los datos entrantes';tr = 'Nesne özelliklerini gelen verilerden alırken bir hata oluştu';it = 'Errore recuperando le propriteà oggetto dai dati in ingresso';de = 'Beim Empfang der Objekteigenschaften aus den eingehenden Daten ist ein Fehler aufgetreten'"));
	
	deMessages.Insert(69, NStr("ru = 'Ошибка в глобальном обработчике события AfterExportObject конвертация)'; en = 'AfterExportObject global event handler error (data conversion).'; pl = 'Wystąpił błąd podczas globalnego przetwarzania wydarzenia AfterExportObject (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos global AfterObjectExpor (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos global AfterObjectExpor (conversión)';tr = 'AfterExportObject global olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento globale AfterExportObject (conversione dati).';de = 'Im globalen Ereignis-Handler ist ein Fehler aufgetreten NachObjektExport (Konvertierung)'"));
	
	deMessages.Insert(71, NStr("ru = 'Не найдено соответствие для значения Источника'; en = 'The map of the Source value is not found'; pl = 'Nie znaleziono odpowiednika dla znaczenia Źródła';es_ES = 'Correspondencia con el valor de la Fuente no encontrada';es_CO = 'Correspondencia con el valor de la Fuente no encontrada';tr = 'Kaynak değerinin eşleşmesi bulunamadı';it = 'La mappa del valore Sorgente non è stato trovato';de = 'Übereinstimmung für den Quellwert wurde nicht gefunden'"));
	
	deMessages.Insert(72, NStr("ru = 'Ошибка при выгрузке данных для узла плана обмена'; en = 'Error exporting data for exchange plan node'; pl = 'Błąd podczas eksportu danych dla węzła planu wymiany';es_ES = 'Ha ocurrido un error al exportar los datos para el nodo del plan de intercambio';es_CO = 'Ha ocurrido un error al exportar los datos para el nodo del plan de intercambio';tr = 'Değişim planı ünitesi için veri dışa aktarılırken bir hata oluştu';it = 'Errore durante l''upload dei dati per il nodo del piano di scambio';de = 'Beim Exportieren von Daten für den Austauschplanknoten ist ein Fehler aufgetreten'"));
	
	deMessages.Insert(73, NStr("ru = 'Ошибка в обработчике события SearchFieldSequence'; en = 'SearchFieldSequence event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia SearchFieldSequence';es_ES = 'Ha ocurrido un error en el manipulador de eventos SearchFieldsSequence';es_CO = 'Ha ocurrido un error en el manipulador de eventos SearchFieldsSequence';tr = 'SearchFieldSequence olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento SearchFieldSequence';de = 'Im Ereignis-Handler SuchfelderSequenz ist ein Fehler aufgetreten'"));
	
	deMessages.Insert(74, NStr("ru = 'Необходимо перезагрузить правила обмена для выгрузки данных'; en = 'Exchange rules for data export must be reread'; pl = 'Należy uruchomić ponownie reguły wymiany dla wyładunku danych';es_ES = 'Importar de nuevo las reglas de intercambio de la exportación de datos';es_CO = 'Importar de nuevo las reglas de intercambio de la exportación de datos';tr = 'Veri içe aktarımı için yeniden alışveriş kuralları';it = 'È necessario effettuare nuovamente il download delle regole di scambio per upload dei dati';de = 'Importieren Sie die Austauschregeln für den Datenexport erneut'"));
	
	deMessages.Insert(75, NStr("ru = 'Ошибка при выполнении алгоритма после загрузки значений параметров'; en = 'Error executing algorithm after parameter value import'; pl = 'Podczas wykonania algorytmu po imporcie wartości parametrów wystąpił błąd';es_ES = 'Ha ocurrido un error al ejecutar el algoritmo después de la importación de los valores del parámetro';es_CO = 'Ha ocurrido un error al ejecutar el algoritmo después de la importación de los valores del parámetro';tr = 'Parametre değerlerini içe aktardıktan sonra algoritmayı çalıştırırken bir hata oluştu.';it = 'Errore durante l''esecuzione di algoritmo dopo il download di valori dei parametri';de = 'Beim Ausführen des Algorithmus nach dem Import der Parameterwerte ist ein Fehler aufgetreten'"));
	
	deMessages.Insert(76, NStr("ru = 'Ошибка в обработчике события AfterExportObjectToFile'; en = 'AfterExportObjectToFile event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterExportObjectToFile';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterObjectExportToFile';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterObjectExportToFile';tr = 'AfterExportObjectToFile olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento AfterExportObjectToFile';de = 'Im Ereignis-Handler NachDemObjektExportInDatei ist ein Fehler aufgetreten'"));
	
	deMessages.Insert(77, NStr("ru = 'Не указан файл внешней обработки с подключаемыми процедурами обработчиков событий'; en = 'The external data processor file with pluggable event handler procedures is not specified'; pl = 'Plik zewnętrznego przetwarzania danych z połączonymi procedurami obsługi wydarzeń nie został określony';es_ES = 'Archivo del procesador de datos externo con los procedimientos conectados de los manipuladores de eventos no está especificado';es_CO = 'Archivo del procesador de datos externo con los procedimientos conectados de los manipuladores de eventos no está especificado';tr = 'Olay işleyicilerinin bağlı prosedürleri ile harici veri işlemcisinin dosyası belirtilmemiş';it = 'Non è specificato il file di elaborazione esterna con le procedure di elaboratori eventi allacciabili';de = 'Datei des externen Datenprozessors mit verbundenen Prozeduren von Ereignis-Handlern ist nicht angegeben'"));
	
	deMessages.Insert(78, NStr("ru = 'Ошибка создания внешней обработки из файла с процедурами обработчиков событий'; en = 'Error creating external data processor from file with event handler procedures'; pl = 'Wystąpił błąd podczas tworzenia zewnętrznego przetwarzania danych z pliku za pomocą procedur obsługi wydarzeń';es_ES = 'Ha ocurrido un error al crear un procesador de datos externo desde un archivo con los procedimientos del manipulador de eventos';es_CO = 'Ha ocurrido un error al crear un procesador de datos externo desde un archivo con los procedimientos del manipulador de eventos';tr = 'Olay işleyici prosedürleri olan bir dosyadan harici veri işlemci oluştururken bir hata oluştu';it = 'Errore durante la creazione di un''elaborazione esterna dal file con le procedure di elaboratori eventi';de = 'Beim Erstellen eines externen Datenprozessors aus einer Datei mit Ereignis-Handler-Prozeduren ist ein Fehler aufgetreten'"));
	
	deMessages.Insert(79, NStr("ru = 'Код алгоритмов не может быть интегрирован в обработчик из-за обнаруженного рекурсивного вызова алгоритмов. 
	                         |Если в процессе отладки нет необходимости отлаживать код алгоритмов, то укажите режим ""не отлаживать алгоритмы""
	                         |Если необходимо выполнять отладку алгоритмов с рекурсивным вызовом, то укажите режим  ""алгоритмы отлаживать как процедуры"" 
	                         |и повторите выгрузку.'; 
	                         |en = 'Algorithm code cannot be integrated into the handler due to detected recursive algorithm call.
	                         |If algorithm code debugging is not required in the debug process, specify the ""without algorithm debugging"" mode.
	                         |If it is required to debug algorithms with recursive call, specify the ""debug algorithms as procedures"" mode 
	                         |and try again.'; 
	                         |pl = 'Kod algorytmów nie może być integrowany do procedury przetwarzania z powodu wykrytego wywołania rekurencyjnego algorytmów. 
	                         |Jeżeli w procesie debugowania nie ma konieczności debugowania kodu algorytmów, to wskaż tryb ""не отлаживать алгоритмы""
	                         |Jeżeli należy wykonać debugowanie z algorytmów z wywołaniem rekurencyjnym, to wskaż tryb ""алгоритмы отлаживать как процедуры"" 
	                         |i powtórz eksportowanie.';
	                         |es_ES = 'El código de algoritmos no puede integrarse al procesador a causa de las llamadas recursivas de algoritmos encontradas. 
	                         |Si en el proceso de depuración no hay necesidad de depurar el código de algoritmos, especifique el modo ""no depurar los algoritmos""
	                         |Si se requiere depurar los algoritmos con una llamada recursiva, entonces especifique el modo ""depurar los algoritmos como procedimientos"" y 
	                         |vuelva a importar.';
	                         |es_CO = 'El código de algoritmos no puede integrarse al procesador a causa de las llamadas recursivas de algoritmos encontradas. 
	                         |Si en el proceso de depuración no hay necesidad de depurar el código de algoritmos, especifique el modo ""no depurar los algoritmos""
	                         |Si se requiere depurar los algoritmos con una llamada recursiva, entonces especifique el modo ""depurar los algoritmos como procedimientos"" y 
	                         |vuelva a importar.';
	                         |tr = 'Algoritmalar kodu, bulunan yinelemeli algoritmalar çağrısı nedeniyle işleyiciye entegre edilemez. 
	                         |Eğer hata ayıklama sürecinde algoritms hata ayıklama gerekmez, 
	                         |""hata ayıklama algoritmalar"" modunu belirtin 
	                         |Eğer bir yinelemeli çağrı ile algoritma hata ayıklama gerekiyorsa, ""prosedürler gibi hata ayıklama algoritmaları"" modunu belirtin ve içe aktarma işlemini tekrarlayın.';
	                         |it = 'Il codice degli algoritmi non può essere integrato nel elaboratore a causa della chiamata ricorsiva di algoritmi rilevata. 
	                         |Se durante il processo di debug non è necessario eseguire il debug del codice degli algoritmi, specificare la modalità ""non eseguire il debug degli algoritmi""
	                         |Se è necessario eseguire il debug degli algoritmi con una chiamata ricorsiva, specificare la modalità ""eseguire il debug degli algoritmi come delle procedure"" 
	                         |e ripetere l''upload.';
	                         |de = 'Der Algorithmuscode kann aufgrund des erkannten rekursiven Aufrufs von Algorithmen nicht in einen Handler integriert werden.
	                         |Wenn während des Debugging-Vorgangs kein Debugging des Algorithmuscodes erforderlich ist, geben Sie den Modus ""Algorithmen nicht debuggen"" an.
	                         |Wenn Sie die Algorithmen mit einem rekursiven Aufruf debuggen müssen, geben Sie den Modus ""Algorithmen als Prozeduren debuggen"" an
	                         |und wiederholen Sie das Hochladen.'"));
	
	deMessages.Insert(80, NStr("ru = 'Обмен данными можно проводить только под полными правами'; en = 'You must have the full rights to execute the data exchange'; pl = 'Wymiana danych może być wykonana tylko wtedy, gdy masz pełne prawa';es_ES = 'Intercambio de datos puede ejecutarse solo si usted tienen plenos derechos';es_CO = 'Intercambio de datos puede ejecutarse solo si usted tienen plenos derechos';tr = 'Veri alışverişi sadece tam haklarınız varsa yapılabilir';it = 'Lo scambio dei dati può essere effettuato solo con i pieni diritti';de = 'Der Datenaustausch kann nur ausgeführt werden, wenn Sie volle Rechte haben'"));
	
	deMessages.Insert(1000, NStr("ru = 'Ошибка при создании временного файла выгрузки данных'; en = 'Error creating temporary data export file'; pl = 'Wystąpił błąd podczas tworzenia tymczasowego pliku eksportu danych';es_ES = 'Ha ocurrido un error al crear un archivo temporal de la exportación de datos';es_CO = 'Ha ocurrido un error al crear un archivo temporal de la exportación de datos';tr = 'Geçici bir veri aktarımı dosyası oluşturulurken bir hata oluştu';it = 'Errore durante la creazione del file temporaneo di upload dei dati';de = 'Beim Erstellen einer temporären Datei mit Datenexport ist ein Fehler aufgetreten'"));

EndProcedure

Procedure SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadateObject, TypeName, Manager, TypeNamePrefix, SearchByPredefinedItemsPossible = False)
	
	Name              = MetadateObject.Name;
	RefTypeString = TypeNamePrefix + "." + Name;
	SearchString     = "SELECT Ref FROM " + TypeName + "." + Name + " WHERE ";
	RefType        = Type(RefTypeString);
	Structure = ManagerParametersStructure(Name, TypeName, RefTypeString, Manager, MetadateObject);
	Structure.Insert("SearchByPredefinedItemsPossible", SearchByPredefinedItemsPossible);
	Structure.Insert("SearchString", SearchString);
	Managers.Insert(RefType, Structure);
	
	
	StructureForExchangePlan = ExchangePlanParametersStructure(Name, RefType, True, False);
	ManagersForExchangePlans.Insert(MetadateObject, StructureForExchangePlan);
	
EndProcedure

Procedure SupplementManagerArrayWithRegisterType(Managers, MetadateObject, TypeName, Manager, TypeNamePrefixRecord, SelectionTypeNamePrefix)
	
	Periodic = Undefined;
	
	Name					= MetadateObject.Name;
	RefTypeString	= TypeNamePrefixRecord + "." + Name;
	RefType			= Type(RefTypeString);
	Structure = ManagerParametersStructure(Name, TypeName, RefTypeString, Manager, MetadateObject);
	
	If TypeName = "InformationRegister" Then
		
		Periodic = (MetadateObject.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical);
		SubordinatedToRecorder = (MetadateObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate);
		
		Structure.Insert("Periodic", Periodic);
		Structure.Insert("SubordinateToRecorder", SubordinatedToRecorder);
		
	EndIf;	
	
	Managers.Insert(RefType, Structure);
		

	StructureForExchangePlan = ExchangePlanParametersStructure(Name, RefType, False, True);

	ManagersForExchangePlans.Insert(MetadateObject, StructureForExchangePlan);
	
	
	RefTypeString	= SelectionTypeNamePrefix + "." + Name;
	RefType			= Type(RefTypeString);
	Structure = ManagerParametersStructure(Name, TypeName, RefTypeString, Manager, MetadateObject);

	If Periodic <> Undefined Then
		
		Structure.Insert("Periodic", Periodic);
		Structure.Insert("SubordinateToRecorder", SubordinatedToRecorder);	
		
	EndIf;
	
	Managers.Insert(RefType, Structure);	
		
EndProcedure

// Initializes the Managers variable that contains mapping of object types and their properties.
//
// Parameters:
//  No.
// 
Procedure ManagerInitialization()

	Managers = New Map;
	
	ManagersForExchangePlans = New Map;
    	
	// REFERENCES
	
	For each MetadateObject In Metadata.Catalogs Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadateObject, "Catalog", Catalogs[MetadateObject.Name], "CatalogRef", True);
					
	EndDo;

	For each MetadateObject In Metadata.Documents Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadateObject, "Document", Documents[MetadateObject.Name], "DocumentRef");
				
	EndDo;

	For each MetadateObject In Metadata.ChartsOfCharacteristicTypes Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadateObject, "ChartOfCharacteristicTypes", ChartsOfCharacteristicTypes[MetadateObject.Name], "ChartOfCharacteristicTypesRef", True);
				
	EndDo;
	
	For each MetadateObject In Metadata.ChartsOfAccounts Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadateObject, "ChartOfAccounts", ChartsOfAccounts[MetadateObject.Name], "ChartOfAccountsRef", True);
						
	EndDo;
	
	For each MetadateObject In Metadata.ChartsOfCalculationTypes Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadateObject, "ChartOfCalculationTypes", ChartsOfCalculationTypes[MetadateObject.Name], "ChartOfCalculationTypesRef", True);
				
	EndDo;
	
	For each MetadateObject In Metadata.ExchangePlans Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadateObject, "ExchangePlan", ExchangePlans[MetadateObject.Name], "ExchangePlanRef");
				
	EndDo;
	
	For each MetadateObject In Metadata.Tasks Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadateObject, "Task", Tasks[MetadateObject.Name], "TaskRef");
				
	EndDo;
	
	For each MetadateObject In Metadata.BusinessProcesses Do
		
		SupplementManagerArrayWithReferenceType(Managers, ManagersForExchangePlans, MetadateObject, "BusinessProcess", BusinessProcesses[MetadateObject.Name], "BusinessProcessRef");
		
		TypeName = "BusinessProcessRoutePoint";
		// Route point references
		Name              = MetadateObject.Name;
		Manager         = BusinessProcesses[Name].RoutePoints;
		SearchString     = "";
		RefTypeString = "BusinessProcessRoutePointRef." + Name;
		RefType        = Type(RefTypeString);
		Structure = ManagerParametersStructure(Name, TypeName, RefTypeString, Manager, MetadateObject);
		Structure.Insert("EmptyRef", Undefined);
		Structure.Insert("SearchString", SearchString);
		Managers.Insert(RefType, Structure);
				
	EndDo;
	
	// REGISTERS

	For each MetadateObject In Metadata.InformationRegisters Do
		
		SupplementManagerArrayWithRegisterType(Managers, MetadateObject, "InformationRegister", InformationRegisters[MetadateObject.Name], "InformationRegisterRecord", "InformationRegisterSelection");
						
	EndDo;

	For each MetadateObject In Metadata.AccountingRegisters Do
		
		SupplementManagerArrayWithRegisterType(Managers, MetadateObject, "AccountingRegister", AccountingRegisters[MetadateObject.Name], "AccountingRegisterRecord", "AccountingRegisterSelection");
				
	EndDo;
	
	For each MetadateObject In Metadata.AccumulationRegisters Do
		
		SupplementManagerArrayWithRegisterType(Managers, MetadateObject, "AccumulationRegister", AccumulationRegisters[MetadateObject.Name], "AccumulationRegisterRecord", "AccumulationRegisterSelection");
						
	EndDo;
	
	For each MetadateObject In Metadata.CalculationRegisters Do
		
		SupplementManagerArrayWithRegisterType(Managers, MetadateObject, "CalculationRegister", CalculationRegisters[MetadateObject.Name], "CalculationRegisterRecord", "CalculationRegisterSelection");
						
	EndDo;
	
	TypeName = "Enum";
	
	For each MetadateObject In Metadata.Enums Do
		
		Name              = MetadateObject.Name;
		Manager         = Enums[Name];
		RefTypeString = "EnumRef." + Name;
		RefType        = Type(RefTypeString);
		Structure = ManagerParametersStructure(Name, TypeName, RefTypeString, Manager, MetadateObject);
		Structure.Insert("EmptyRef", Enums[Name].EmptyRef());

		Managers.Insert(RefType, Structure);
		
	EndDo;	
	
	// Constants
	TypeName             = "Constants";
	MetadateObject            = Metadata.Constants;
	Name					= "Constants";
	Manager			= Constants;
	RefTypeString	= "ConstantsSet";
	RefType			= Type(RefTypeString);
	Structure = ManagerParametersStructure(Name, TypeName, RefTypeString, Manager, MetadateObject);
	Managers.Insert(RefType, Structure);
	
EndProcedure

// Initializes object managers and all messages of the data exchange protocol.
//
// Parameters:
//  No.
// 
Procedure InitManagersAndMessages() Export
	
	If Managers = Undefined Then
		ManagerInitialization();
	EndIf; 

	If deMessages = Undefined Then
		InitMessages();
	EndIf;
	
EndProcedure

Procedure CreateConversionStructure()
	
	Conversion  = New Structure("BeforeExportData, AfterExportData, BeforeExportObject, AfterExportObject, BeforeConvertObject, BeforeImportObject, AfterImportObject, BeforeImportData, AfterImportData");
	
EndProcedure

// Initializes data processor attributes and modular variables.
//
// Parameters:
//  No.
// 
Procedure InitAttributesAndModuleVariables()

	ProcessedObjectsCountToUpdateStatus = 100;
	
	RememberImportedObjects     = True;
	ImportedObjectToStoreCount = 5000;
	
	ParametersInitialized        = False;
	
	WriteToXMLAdvancedMonitoring = False;
	DirectReadingInDestinationIB = False;
	DontOutputInfoMessagesToUser = False;
	
	Managers    = Undefined;
	deMessages  = Undefined;
	
	ErrorFlag   = False;
	
	CreateConversionStructure();
	
	Rules      = New Structure;
	Algorithms    = New Structure;
	AdditionalDataProcessors = New Structure;
	Queries      = New Structure;

	Parameters    = New Structure;
	EventsAfterParameterImport = New Structure;
	
	AdditionalDataProcessorParameters = New Structure;
	
	// Types
	deStringType                  = Type("String");
	deBooleanType                  = Type("Boolean");
	deNumberType                   = Type("Number");
	deDateType                    = Type("Date");
	deValueStorageType       = Type("ValueStorage");
	deUUIDType = Type("UUID");
	deBinaryDataType          = Type("BinaryData");
	deAccumulationRecordTypeType   = Type("AccumulationRecordType");
	deObjectDeletionType         = Type("ObjectDeletion");
	deAccountTypeType			     = Type("AccountType");
	deTypeType                     = Type("Type");
	deMapType            = Type("Map");

	BlankDateValue		   = Date('00010101');
	
	mXMLRules  = Undefined;
	
	// XML node types
	
	deXMLNodeType_EndElement  = XMLNodeType.EndElement;
	deXMLNodeType_StartElement = XMLNodeType.StartElement;
	deXMLNodeType_Text          = XMLNodeType.Text;


	mExchangeRuleTemplateList  = New ValueList;

	For each Template In Metadata().Templates Do
		mExchangeRuleTemplateList.Add(Template.Synonym);
	EndDo; 
	    	
	mDataProtocolFile = Undefined;
	
	InfobaseToConnectType = True;
	InfobaseToConnectWindowsAuthentication = False;
	InfobaseToConnectPlatformVersion = "V8";
	OpenExchangeProtocolsAfterExecutingOperations = False;
	ImportDataInExchangeMode = True;
	WriteToInfobaseOnlyChangedObjects = True;
	WriteRegistersAsRecordSets = True;
	OptimizedObjectsWriting = True;
	ExportAllowedObjectsOnly = True;
	ImportReferencedObjectsWithoutDeletionMark = True;	
	UseFilterByDateForAllObjects = True;
	
	mEmptyTypeValueMap = New Map;
	mTypeDescriptionMap = New Map;
	
	mExchangeRulesReadOnImport = False;

	ReadEventHandlersFromExchangeRulesFile = True;
	
	mDataProcessingModes = New Structure;
	mDataProcessingModes.Insert("DataExported",                   0);
	mDataProcessingModes.Insert("Load",                   1);
	mDataProcessingModes.Insert("ExchangeRuleImport",       2);
	mDataProcessingModes.Insert("EventHandlerExport", 3);
	
	DataProcessingMode = mDataProcessingModes.DataExported;
	
	mAlgorithmDebugModes = New Structure;
	mAlgorithmDebugModes.Insert("DontUse",   0);
	mAlgorithmDebugModes.Insert("ProceduralCall", 1);
	mAlgorithmDebugModes.Insert("CodeIntegration",   2);
	
	AlgorithmDebugMode = mAlgorithmDebugModes.DontUse;
	
	// Standard subsystem modules.
	Try
		// Calling CalculateInSafeMode is not required as a string literal is being passed for calculation.
		ModulePeriodClosingDates = Eval("PeriodClosingDates");
	Except
		ModulePeriodClosingDates = Undefined;
	EndTry;
	
	ApplicationSeparators = New Array;
	For Each CommonAttribute In Metadata.CommonAttributes Do
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			ApplicationSeparators.Add(CommonAttribute.Name);
		EndIf;
	EndDo;
	ApplicationSeparators = New FixedArray(ApplicationSeparators);
	
EndProcedure

Function DetermineIfEnoughInfobaseConnectionParameters(ConnectionStructure, StringForConnection = "", ErrorMessageString = "")
	
	ErrorsExist = False;
	
	If ConnectionStructure.FileMode  Then
		
		If IsBlankString(ConnectionStructure.IBDirectory) Then
			
			ErrorMessageString = NStr("ru='Не задан каталог информационной базы-приемника'; en = 'The destination infobase directory is not specified.'; pl = 'Katalog docelowej baz informacyjnych nie jest określony';es_ES = 'Directorio de la infobase de destino no está especificado.';es_CO = 'Directorio de la infobase de destino no está especificado.';tr = 'Hedef veritabanı dizini belirtilmemiş';it = 'La directory dell''infobase di destinazione non è specificata.';de = 'Das Zielverzeichnis der Informationsbasis ist nicht angegeben.'");
			
			MessageToUser(ErrorMessageString);
			
			ErrorsExist = True;
			
		EndIf;
		
		StringForConnection = "File=""" + ConnectionStructure.IBDirectory + """";
	Else
		
		If IsBlankString(ConnectionStructure.ServerName) Then
			
			ErrorMessageString = NStr("ru='Не задано имя сервера 1С:Предприятия информационной базы-приемника'; en = 'The destination infobase platform server name is not specified.'; pl = 'Nazwa 1C:Enterprise serwer docelowej bazy informacyjnej nie została określona';es_ES = 'No se especifica el nombre del servidor de la plataforma de la infobase de destino.';es_CO = 'No se especifica el nombre del servidor de la plataforma de la infobase de destino.';tr = 'Hedef infobase (bilgi tabanı) platform sunucusu adı belirtilmedi.';it = 'Il nome del server 1C:Enterprise del database informatico-ricevitore non è specificato.';de = 'Der Name des Servers für den Ziel-Infobase-Plattform-Server wird nicht angegeben.'");
			
			MessageToUser(ErrorMessageString);
			
			ErrorsExist = True;
			
		EndIf;
		
		If IsBlankString(ConnectionStructure.IBNameAtServer) Then
			
			ErrorMessageString = NStr("ru='Не задано имя информационной базы-приемника на сервере 1С:Предприятия'; en = 'The destination infobase name on the platform server is not specified.'; pl = 'Nazwa docelowej bazy informacyjnej nie jest określona na 1C:Enterprise serwer';es_ES = 'No se especifica el nombre de la infobase de destino en el servidor de la plataforma.';es_CO = 'No se especifica el nombre de la infobase de destino en el servidor de la plataforma.';tr = 'Platform sunucusundaki hedef bilgi tabanı adı belirtilmedi.';it = 'Il nome dell''infobase di destinazione sul server della piattaforma non è specificato.';de = 'Der Name der Ziel-Infobase auf dem Plattform-Server wird nicht angegeben.'");
			
			MessageToUser(ErrorMessageString);
			
			ErrorsExist = True;
			
		EndIf;		
		
		StringForConnection = "Srvr = """ + ConnectionStructure.ServerName + """; Ref = """ + ConnectionStructure.IBNameAtServer + """";		
		
	EndIf;
	
	Return NOT ErrorsExist;	
	
EndFunction

Function ConnectToInfobase(ConnectionStructure, ErrorMessageString = "")
	
	Var StringForConnection;
	
	EnoughParameters = DetermineIfEnoughInfobaseConnectionParameters(ConnectionStructure, StringForConnection, ErrorMessageString);
	
	If Not EnoughParameters Then
		Return Undefined;
	EndIf;
	
	If Not ConnectionStructure.WindowsAuthentication Then
		If NOT IsBlankString(ConnectionStructure.User) Then
			StringForConnection = StringForConnection + ";Usr = """ + ConnectionStructure.User + """";
		EndIf;
		If NOT IsBlankString(ConnectionStructure.Password) Then
			StringForConnection = StringForConnection + ";Pwd = """ + ConnectionStructure.Password + """";
		EndIf;
	EndIf;
	
	// "V82" or "V83"
	ConnectionObject = ConnectionStructure.PlatformVersion;
	
	StringForConnection = StringForConnection + ";";
	
	Try
		
		ConnectionObject = ConnectionObject +".COMConnector";
		CurrentCOMConnection = New COMObject(ConnectionObject);
		CurCOMObject = CurrentCOMConnection.Connect(StringForConnection);
		
	Except
		
		ErrorMessageString = NStr("ru = 'При попытке соединения с COM-сервером произошла следующая ошибка:
			|%1'; 
			|en = 'When trying to connect to the COM server, the following error occurred:
			|%1'; 
			|pl = 'Podczas próby połączenia z serwerem COM wystąpił następujący błąd:
			|%1';
			|es_ES = 'Al probar de conectar con el servidor COM se ha producido el siguiente error:
			|%1';
			|es_CO = 'Al probar de conectar con el servidor COM se ha producido el siguiente error:
			|%1';
			|tr = 'COM sunucusuna 
			|bağlanmaya çalışırken aşağıdaki hata oluştu:%1';
			|it = 'Durante il tentativo di connessione al server COM si è verificato il seguente errore:
			|%1';
			|de = 'Der folgende Fehler trat auf, wenn versucht wurde, eine Verbindung zum COM-Server herzustellen:
			|%1'");
		ErrorMessageString = SubstituteParametersToString(ErrorMessageString, ErrorDescription());
		
		MessageToUser(ErrorMessageString);
		
		Return Undefined;
		
	EndTry;
	
	Return CurCOMObject;
	
EndFunction

// Returns the string part that follows the last specified character.
Function GetStringAfterCharacter(Val InitialString, Val SearchChar)
	
	CharPosition = StrLen(InitialString);
	While CharPosition >= 1 Do
		
		If Mid(InitialString, CharPosition, 1) = SearchChar Then
						
			Return Mid(InitialString, CharPosition + 1); 
			
		EndIf;
		
		CharPosition = CharPosition - 1;	
	EndDo;

	Return "";
  	
EndFunction

// Returns the file extension.
//
// Parameters:
//  FileName     - a string containing file name with or without the directory name.
//
// Returns:
//   String - the file extension.
//
Function GetFileNameExtension(Val FileName) Export
	
	Extension = GetStringAfterCharacter(FileName, ".");
	Return Extension;
	
EndFunction

Function GetProtocolNameForCOMConnectionSecondInfobase()
	
	If Not IsBlankString(ImportExchangeLogFileName) Then
			
		Return ImportExchangeLogFileName;	
		
	ElsIf Not IsBlankString(ExchangeProtocolFileName) Then
		
		ProtocolFileExtension = GetFileNameExtension(ExchangeProtocolFileName);
		
		If Not IsBlankString(ProtocolFileExtension) Then
							
			ExportProtocolFileName = StrReplace(ExchangeProtocolFileName, "." + ProtocolFileExtension, "");
			
		EndIf;
		
		ExportProtocolFileName = ExportProtocolFileName + "_Import";
		
		If Not IsBlankString(ProtocolFileExtension) Then
			
			ExportProtocolFileName = ExportProtocolFileName + "." + ProtocolFileExtension;	
			
		EndIf;
		
		Return ExportProtocolFileName;
		
	EndIf;
	
	Return "";
	
EndFunction

// Establishing the connection to the destination infobase by the specified parameters.
// Returns the initialized UniversalDataExchangeXML destination infobase data processor, which is 
// used for importing data into the destination infobase.
//
// Parameters:
//  No.
// 
//  Returns:
//  DataProcessorObject - UniversalDataExchangeXML - processing receiver base to import data there.
//
Function EstablishConnectionWithDestinationIB() Export
	
	ConnectionResult = Undefined;
	
	ConnectionStructure = New Structure();
	ConnectionStructure.Insert("FileMode", InfobaseToConnectType);
	ConnectionStructure.Insert("WindowsAuthentication", InfobaseToConnectWindowsAuthentication);
	ConnectionStructure.Insert("IBDirectory", InfobaseToConnectDirectory);
	ConnectionStructure.Insert("ServerName", InfobaseToConnectServerName);
	ConnectionStructure.Insert("IBNameAtServer", InfobaseToConnectNameOnServer);
	ConnectionStructure.Insert("User", InfobaseToConnectUser);
	ConnectionStructure.Insert("Password", InfobaseToConnectPassword);
	ConnectionStructure.Insert("PlatformVersion", InfobaseToConnectPlatformVersion);
	
	ConnectionObject = ConnectToInfobase(ConnectionStructure);
	
	If ConnectionObject = Undefined Then
		Return Undefined;
	EndIf;
	
	Try
		ConnectionResult = ConnectionObject.DataProcessors.UniversalDataExchangeXML.Create();
	Except
		
		Text = NStr("ru='При попытке создания обработки UniversalDataExchangeXML произошла ошибка: %1'; en = 'Creating the UniversalDataExchangeXML data processor failed with the following error: %1'; pl = 'Podczas próby utworzenia modułu obsługi UniversalDataExchangeXML wystąpił błąd: %1';es_ES = 'Intentando crear el manipulador UniversalXMLDataExchange, ha ocurrido un error: %1';es_CO = 'Intentando crear el manipulador UniversalXMLDataExchange, ha ocurrido un error: %1';tr = 'UniversalDataExchangeXML işleyicisi oluşturulmaya çalışırken, bir hata oluştu: %1';it = 'La creazione dell''elaboratore dati UniversalDataExchangeXML non è riuscita con il seguente errore: %1';de = 'Beim Versuch, den Anwender UniversalXMLDatenAustausch zu erstellen, ist ein Fehler aufgetreten: %1'");
		Text = SubstituteParametersToString(Text, BriefErrorDescription(ErrorInfo()));
		MessageToUser(Text);
		ConnectionResult = Undefined;
	EndTry;
	
	If ConnectionResult <> Undefined Then
		
		ConnectionResult.UseTransactions = UseTransactions;	
		ConnectionResult.ObjectCountPerTransaction = ObjectCountPerTransaction;
		
		ConnectionResult.DebugModeFlag = DebugModeFlag;
		
		ConnectionResult.ExchangeProtocolFileName = GetProtocolNameForCOMConnectionSecondInfobase();
								
		ConnectionResult.AppendDataToExchangeLog = AppendDataToExchangeLog;
		ConnectionResult.OutputInfoMessagesToProtocol = OutputInfoMessagesToProtocol;
		
		ConnectionResult.ExchangeMode = "Load";
		
	EndIf;
	
	Return ConnectionResult;
	
EndFunction

// Deletes objects of the specified type according to the data clearing rules (deletes physically or 
// marks for deletion.
//
// Parameters:
//  TypeNameToRemove - String - a string type name.
// 
Procedure DeleteObjectsOfType(TypeNameToRemove) Export
	
	DataToDeleteType = Type(TypeNameToRemove);
	
	Manager = Managers[DataToDeleteType];
	TypeName  = Manager.TypeName;
	Name      = Manager.Name;	
	Properties	= Managers[DataToDeleteType];
	
	Rule = New Structure("Name,Directly,BeforeDelete", "ObjectDeletion", True, "");
					
	Selection = GetSelectionForDataClearingExport(Properties, TypeName, True, True, False);
	
	While Selection.Next() Do
		
		If TypeName =  "InformationRegister" Then
			
			RecordManager = Properties.Manager.CreateRecordManager(); 
			FillPropertyValues(RecordManager, Selection);
								
			SelectionObjectDeletion(RecordManager, Rule, Properties, Undefined);
				
		Else
				
			SelectionObjectDeletion(Selection.Ref.GetObject(), Rule, Properties, Undefined);
				
		EndIf;
			
	EndDo;	
	
EndProcedure

Procedure SupplementServiceTablesWithColumns()
	
	InitConversionRuleTable();
	InitExportRuleTable();
	CleaningRuleTableInitialization();
	InitializationParameterSetupTable();	
	
EndProcedure

Function GetNewUniqueTempFileName(OldTempFileName, Extension = "txt")
	
	DeleteTempFiles(OldTempFileName);
	
	Return GetTempFileName(Extension);
	
EndFunction 

Procedure InitHandlerNamesStructure()
	
	// Conversion handlers.
	ConversionHandlerNames = New Structure;
	ConversionHandlerNames.Insert("BeforeExportData");
	ConversionHandlerNames.Insert("AfterExportData");
	ConversionHandlerNames.Insert("BeforeExportObject");
	ConversionHandlerNames.Insert("AfterExportObject");
	ConversionHandlerNames.Insert("BeforeConvertObject");
	ConversionHandlerNames.Insert("BeforeSendDeletionInfo");
	ConversionHandlerNames.Insert("BeforeGetChangedObjects");
	
	ConversionHandlerNames.Insert("BeforeImportObject");
	ConversionHandlerNames.Insert("AfterImportObject");
	ConversionHandlerNames.Insert("BeforeImportData");
	ConversionHandlerNames.Insert("AfterImportData");
	ConversionHandlerNames.Insert("OnGetDeletionInfo");
	ConversionHandlerNames.Insert("AfterGetExchangeNodesInformation");
	
	ConversionHandlerNames.Insert("AfterImportExchangeRules");
	ConversionHandlerNames.Insert("AfterImportParameters");
	
	// OCR handlers.
	OCRHandlersNames = New Structure;
	OCRHandlersNames.Insert("BeforeExport");
	OCRHandlersNames.Insert("OnExport");
	OCRHandlersNames.Insert("AfterExport");
	OCRHandlersNames.Insert("AfterExportToFile");
	
	OCRHandlersNames.Insert("BeforeImport");
	OCRHandlersNames.Insert("OnImport");
	OCRHandlersNames.Insert("AfterImport");
	
	OCRHandlersNames.Insert("SearchFieldSequence");
	
	// PCR handlers.
	PCRHandlersNames = New Structure;
	PCRHandlersNames.Insert("BeforeExport");
	PCRHandlersNames.Insert("OnExport");
	PCRHandlersNames.Insert("AfterExport");

	// PGCR handlers.
	PGCRHandlersNames = New Structure;
	PGCRHandlersNames.Insert("BeforeExport");
	PGCRHandlersNames.Insert("OnExport");
	PGCRHandlersNames.Insert("AfterExport");
	
	PGCRHandlersNames.Insert("BeforeProcessExport");
	PGCRHandlersNames.Insert("AfterProcessExport");
	
	// DER handlers.
	DERHandlerNames = New Structure;
	DERHandlerNames.Insert("BeforeProcess");
	DERHandlerNames.Insert("AfterProcess");
	DERHandlerNames.Insert("BeforeExport");
	DERHandlerNames.Insert("AfterExport");
	
	// DPR handlers.
	DPRHandlersNames = New Structure;
	DPRHandlersNames.Insert("BeforeProcess");
	DPRHandlersNames.Insert("AfterProcess");
	DPRHandlersNames.Insert("BeforeDelete");
	
	// Global structure with handler names.
	HandlerNames = New Structure;
	HandlerNames.Insert("Conversion", ConversionHandlerNames); 
	HandlerNames.Insert("OCR",         OCRHandlersNames); 
	HandlerNames.Insert("PCR",         PCRHandlersNames); 
	HandlerNames.Insert("PGCR",        PGCRHandlersNames); 
	HandlerNames.Insert("DER",         DERHandlerNames); 
	HandlerNames.Insert("DPR",         DPRHandlersNames); 
	
EndProcedure  

// Displays a message to user.
//
// Parameters:
//	MessageToUserText - String - a displayed message text.
//
Procedure MessageToUser(MessageToUserText) Export
	
	Message = New UserMessage;
	Message.Text = MessageToUserText;
	Message.Message();
	
EndProcedure

// Substitutes parameters in a string. The maximum number of parameters is 9.
// Parameters in the string have the following format: %<parameter number>. The parameter numbering starts from 1.
//
// Parameters:
//  SubstitutionString  - String - a string pattern that contains parameters (occurrences of %"ParameterName");
//  Parameter<n>        - String - parameter for substitution.
//
// Returns:
//  String   - text string with parameters inserted.
//
// Example:
//  SubstituteParametersToString(NStr("en='%1 went to%2'", "John", "Zoo") = "John went to the Zoo".
//
Function SubstituteParametersToString(Val SubstitutionString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined)
	
	SubstitutionString = StrReplace(SubstitutionString, "%1", Parameter1);
	SubstitutionString = StrReplace(SubstitutionString, "%2", Parameter2);
	SubstitutionString = StrReplace(SubstitutionString, "%3", Parameter3);
	
	Return SubstitutionString;
	
EndFunction

Function IsExternalDataProcessor()
	
	Return ?(StrFind(EventHandlerExternalDataProcessorFileName, ".") <> 0, True, False);
	
EndFunction

Function PredefinedItemName(Ref)
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.Text =
	"SELECT
	| PredefinedDataName AS PredefinedDataName
	|FROM
	|	" + Ref.Metadata().FullName() + " AS SpecifiedTableAlias
	|WHERE
	|	SpecifiedTableAlias.Ref = &Ref
	|";
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection.PredefinedDataName;
	
EndFunction

// Checks whether the value is a reference type value.
//
// Parameters:
//  Value - Arbitrary - a value to check.
//
// Returns:
//  Boolean - True if the value is a reference type value.
//
Function RefTypeValue(Value)
	
	Type = TypeOf(Value);
	
	Return Type <> Type("Undefined") 
		AND (Catalogs.AllRefsType().ContainsType(Type)
		OR Documents.AllRefsType().ContainsType(Type)
		OR Enums.AllRefsType().ContainsType(Type)
		OR ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type)
		OR ChartsOfAccounts.AllRefsType().ContainsType(Type)
		OR ChartsOfCalculationTypes.AllRefsType().ContainsType(Type)
		OR BusinessProcesses.AllRefsType().ContainsType(Type)
		OR BusinessProcesses.RoutePointsAllRefsType().ContainsType(Type)
		OR Tasks.AllRefsType().ContainsType(Type)
		OR ExchangePlans.AllRefsType().ContainsType(Type));
	
EndFunction

// Returns the code of the default configuration language, for example, "en".
Function DefaultLanguageCode() Export
	Return Metadata.DefaultLanguage.LanguageCode;
EndFunction

Function ManagerParametersStructure(Name, TypeName, RefTypeString, Manager, MetadateObject)
	Structure = New Structure();
	Structure.Insert("Name", Name);
	Structure.Insert("TypeName", TypeName);
	Structure.Insert("RefTypeString", RefTypeString);
	Structure.Insert("Manager", Manager);
	Structure.Insert("MetadateObject", MetadateObject);
	Structure.Insert("SearchByPredefinedItemsPossible", False);
	Structure.Insert("OCR");
	Return Structure;
EndFunction

Function ExchangePlanParametersStructure(Name, RefType, IsReferenceType, IsRegister)
	Structure = New Structure();
	Structure.Insert("Name",Name);
	Structure.Insert("RefType",RefType);
	Structure.Insert("IsReferenceType",IsReferenceType);
	Structure.Insert("IsRegister",IsRegister);
	Return Structure;
EndFunction

#EndRegion

#EndRegion

#Region Initializing

InitAttributesAndModuleVariables();
SupplementServiceTablesWithColumns();
InitHandlerNamesStructure();

#EndRegion

#EndIf
