#Region Public

// Sets a subscription source prefix according to a company prefix.
// A subscription source should contain the required header attribute Company with the CatalogRef.
// Company type.
//
// Parameters:
//  Source - Arbitrary - a subscription event source.
//             Any object from the set [Catalog, Document, Chart of characteristic types, Business process, or Task].
//  StandardProcessing - Boolean - a standard subscription processing flag.
//  Prefix - String - a prefix of an object to be changed.
//
Procedure SetCompanyPrefix(Source, StandardProcessing, Prefix) Export
	
	SetPrefix(Source, Prefix, False, True);
	
EndProcedure

// Sets a subscription source prefix according to an infobase prefix.
// Source attributes are not restricted.
//
// Parameters:
//  Source - Arbitrary - a subscription event source.
//             Any object from the set [Catalog, Document, Chart of characteristic types, Business process, or Task].
//  StandardProcessing - Boolean - a standard subscription processing flag.
//  Prefix - String - a prefix of an object to be changed.
//
Procedure SetInfobasePrefix(Source, StandardProcessing, Prefix) Export
	
	SetPrefix(Source, Prefix, True, False);
	
EndProcedure

// Sets a subscription source prefix according to an infobase prefix and a company prefix.
// A subscription source should contain the required header attribute Company with the CatalogRef.
// Company type.
//
// Parameters:
//  Source - Arbitrary - a subscription event source.
//             Any object from the set [Catalog, Document, Chart of characteristic types, Business process, or Task].
//  StandardProcessing - Boolean - a standard subscription processing flag.
//  Prefix - String - a prefix of an object to be changed.
//
Procedure SetInfobaseAndCompanyPrefix(Source, StandardProcessing, Prefix) Export
	
	SetPrefix(Source, Prefix, True, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For catalogs

// Checks whether the Company attribute of the catalog item is modified.
// If the Company attribute is changed, the Item code is reset to zero.
// It is required to assign a new code to the item.
//
// Parameters:
//  Source - CatalogObject - a subscription event source.
//  Cancel - Boolean - a cancellation flag.
// 
Procedure CheckCatalogCodeByCompany(Source, Cancel) Export
	
	CheckObjectCodeByCompany(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For business processes

// Checks whether the business process Date is modified.
// If the date is not included in the previous period, the business process number is reset to zero.
// It is required to assign a new number to the business process.
//
// Parameters:
//  Source - BusinessProcessObject - a subscription event source.
//  Cancel - Boolean - a cancellation flag.
// 
Procedure CheckBusinessProcessNumberByDate(Source, Cancel) Export
	
	CheckObjectNumberByDate(Source);
	
EndProcedure

// Checks whether the business process Date and the Company are changed.
// If the date is not included in the previous period or the Company attribute is changed, the business process number is reset to zero.
// It is required to assign a new number to the business process.
//
// Parameters:
//  Source - BusinessProcessObject - a subscription event source.
//  Cancel - Boolean - a cancellation flag.
// 
Procedure CheckBusinessProcessNumberByDateAndCompany(Source, Cancel) Export
	
	CheckObjectNumberByDateAndCompany(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For documents

// Checks whether the document Date is modified.
// If the date is not included in the previous period, the document number is reset to zero.
// It is required to assign a new number to the document.
//
// Parameters:
//  Source - DocumentObject - a subscription event source.
//  Cancel - Boolean - a cancellation flag.
//  WriteMode - DocumentWriteMode - the current document write mode is passed in this parameter.
//  PostingMode - DocumentPostingMode - the current posting mode is passed in this parameter.
//
Procedure CheckDocumentNumberByDate(Source, Cancel, WriteMode, PostingMode) Export
	
	CheckObjectNumberByDate(Source);
	
EndProcedure

// Checks whether the document Date and the Company are changed.
// If the date is not included in the previous period or the Company attribute is changed, the document number is reset to zero.
// It is required to assign a new number to the document.
//
// Parameters:
//  Source - DocumentObject - a subscription event source.
//  Cancel - Boolean - a cancellation flag.
//  WriteMode - DocumentWriteMode - the current document write mode is passed in this parameter.
//  PostingMode - DocumentPostingMode - the current posting mode is passed in this parameter.
// 
Procedure CheckDocumentNumberByDateAndCompany(Source, Cancel, WriteMode, PostingMode) Export
	
	CheckObjectNumberByDateAndCompany(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Getting a prefix

// Returns a prefix of the current infobase.
//
// Parameters:
//    InfobasePrefix - String - a return value. Contains an infobase prefix.
//
Procedure OnDetermineInfobasePrefix(InfobasePrefix) Export
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		InfobasePrefix = ModuleDataExchangeServer.InfobasePrefix();
	Else
		InfobasePrefix = "";
	EndIf;
	
EndProcedure

// Returns a company prefix.
//
// Parameters:
//  Company - CatalogRef.Companies - a company for which a prefix is to be got.
//  CompanyPrefix - String - a company prefix.
//
Procedure OnDetermineCompanyPrefix(Val Company, CompanyPrefix) Export
	
	If Metadata.DefinedTypes.Company.Type.ContainsType(Type("String")) Then
		CompanyPrefix = "";
		Return;
	EndIf;
		
	FunctionalOptionName = "CompanyPrefixes";
	FunctionalOptionParameterName = "Company";
	
	CompanyPrefix = GetFunctionalOption(FunctionalOptionName, 
		New Structure(FunctionalOptionParameterName, Company));
	
EndProcedure

#EndRegion

#Region Private

Procedure SetPrefix(Source, Prefix, SetInfobasePrefix, SetCompanyPrefix)
	
	InfobasePrefix = "";
	CompanyPrefix        = "";
	
	If SetInfobasePrefix Then
		
		OnDetermineInfobasePrefix(InfobasePrefix);
		
		SupplementStringWithZerosOnLeft(InfobasePrefix, 2);
	EndIf;
	
	If SetCompanyPrefix Then
		
		If CompanyAttributeAvailable(Source) Then
			
			OnDetermineCompanyPrefix(
				Source[CompanyAttributeName(Source.Metadata())], CompanyPrefix);
			// If a blank reference to a company is specified.
			If CompanyPrefix = False Then
				
				CompanyPrefix = "";
				
			EndIf;
			
		EndIf;
		
		SupplementStringWithZerosOnLeft(CompanyPrefix, 2);
	EndIf;
	
	PrefixTemplate = "[COMP][IB]-[Prefix]";
	PrefixTemplate = StrReplace(PrefixTemplate, "[COMP]", CompanyPrefix);
	PrefixTemplate = StrReplace(PrefixTemplate, "[IB]", InfobasePrefix);
	PrefixTemplate = StrReplace(PrefixTemplate, "[Prefix]", Prefix);
	
	Prefix = PrefixTemplate;
	
EndProcedure

Procedure SupplementStringWithZerosOnLeft(Row, StringLength)
	
	Row = StringFunctionsClientServer.SupplementString(Row, StringLength, "0", "Left");
	
EndProcedure

Procedure CheckObjectNumberByDate(Object)
	
	If Object.DataExchange.Load Then
		Return;
	ElsIf Object.IsNew() Then
		Return;
	EndIf;
	
	ObjectMetadata = Object.Metadata();
	
	QueryText = "
	|SELECT
	|	ObjectHeader.Date AS Date
	|FROM
	|	" + ObjectMetadata.FullName() + " AS ObjectHeader
	|WHERE
	|	ObjectHeader.Ref = &Ref
	|";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Object.Ref);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	If Not ObjectsPrefixesInternal.ObjectDatesOfSamePeriod(Selection.Date, Object.Date, Object.Ref) Then
		Object.Number = "";
	EndIf;
	
EndProcedure

Procedure CheckObjectNumberByDateAndCompany(Object)
	
	If Object.DataExchange.Load Then
		Return;
	ElsIf Object.IsNew() Then
		Return;
	EndIf;
	
	If ObjectsPrefixesInternal.ObjectDateOrCompanyChanged(Object.Ref, Object.Date,
		Object[CompanyAttributeName(Object.Metadata())]) Then
		
		Object.Number = "";
		
	EndIf;
	
EndProcedure

Procedure CheckObjectCodeByCompany(Object)
	
	If Object.DataExchange.Load Then
		Return;
	ElsIf Object.IsNew() Then
		Return;
	ElsIf Not CompanyAttributeAvailable(Object) Then
		Return;
	EndIf;
	
	If ObjectsPrefixesInternal.ObjectCompanyChanged(Object.Ref,	
		Object[CompanyAttributeName(Object.Metadata())]) Then
		
		Object.Code = "";
		
	EndIf;
	
EndProcedure

Function CompanyAttributeAvailable(Object)
	
	// Function return value.
	Result = True;
	
	ObjectMetadata = Object.Metadata();
	
	If   (Common.IsCatalog(ObjectMetadata)
		OR Common.IsChartOfCharacteristicTypes(ObjectMetadata))
		AND ObjectMetadata.Hierarchical Then
		
		CompanyAttributeName = CompanyAttributeName(ObjectMetadata);
		
		CompanyAttribute = ObjectMetadata.Attributes.Find(CompanyAttributeName);
		
		If CompanyAttribute = Undefined Then
			
			If Common.IsStandardAttribute(ObjectMetadata.StandardAttributes, CompanyAttributeName) Then
				
				// The standard attribute is always available both for the item and for the group.
				Return True;
				
			EndIf;
			
			MessageString = NStr("ru = 'Для объекта метаданных %1 не определен реквизит с именем %2.'; en = 'The attribute with the %2 name is not defined for the %1 metadata object.'; pl = 'Dla obiektu metadanych %1 nie określono atrybutu o nazwie ""%2"".';es_ES = 'Atributo con el nombre ""%2"" no está definido para el objeto de metadatos %1.';es_CO = 'Atributo con el nombre ""%2"" no está definido para el objeto de metadatos %1.';tr = '%2 adlı metadata nesnesi için %1öznitelik tanımlanmadı.';it = 'L''attributo con il nome %2 è non definito per l''oggetto metadati %1.';de = 'Das Attribut mit dem Namen ""%2"" ist nicht für das Metadatenobjekt definiert %1.'");
			MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ObjectMetadata.FullName(), CompanyAttributeName);
			Raise MessageString;
		EndIf;
			
		If CompanyAttribute.Use = Metadata.ObjectProperties.AttributeUse.ForFolder AND Not Object.IsFolder Then
			
			Result = False;
			
		ElsIf CompanyAttribute.Use = Metadata.ObjectProperties.AttributeUse.ForItem AND Object.IsFolder Then
			
			Result = False;
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// For internal use.
Function CompanyAttributeName(Object) Export
	
	If TypeOf(Object) = Type("MetadataObject") Then
		FullName = Object.FullName();
	Else
		FullName = Object;
	EndIf;
	
	Attribute = ObjectsPrefixesCached.PrefixGeneratingAttributes().Get(FullName);
	
	If Attribute <> Undefined Then
		Return Attribute;
	EndIf;
	
	Return "Company";
	
EndFunction

#EndRegion
